// File: lib/bee_counter/bee_activity_correlation_screen.dart
import 'package:flutter/material.dart';
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/bee_counter/bee_count_database.dart';
import 'package:farmer_app/bee_counter/weatherdata.dart';
import 'package:farmer_app/bee_counter/bee_activity_visualization.dart';
import 'package:farmer_app/Services/weather_service.dart';
import 'package:farmer_app/bee_counter/integrated_hive_monitoring.dart';

/// Screen to show correlations between bee activity and various metrics
class BeeActivityCorrelationScreen extends StatefulWidget {
  final String hiveId;

  const BeeActivityCorrelationScreen({
    Key? key,
    required this.hiveId,
  }) : super(key: key);

  @override
  _BeeActivityCorrelationScreenState createState() =>
      _BeeActivityCorrelationScreenState();
}

class _BeeActivityCorrelationScreenState
    extends State<BeeActivityCorrelationScreen> {
  bool _isLoading = true;
  List<BeeCount> _beeCounts = [];
  Map<DateTime, WeatherData> _weatherData = {};
  List<HiveData> _hiveData = [];
  int _selectedTimeRange = 30; // Default to 30 days

  // Correlation coefficients
  Map<String, double> _correlations = {
    'Temperature': 0.0,
    'Humidity': 0.0,
    'Wind Speed': 0.0,
    'Time of Day': 0.0,
    'Hive Weight': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Convert weather data from WeatherService to the format needed by our visualization
  Future<Map<DateTime, WeatherData>> _convertWeatherData(
      Map<DateTime, dynamic> data) async {
    final Map<DateTime, WeatherData> result = {};

    data.forEach((date, weatherInfo) {
      if (weatherInfo is Map<String, dynamic> &&
          !weatherInfo.containsKey('error')) {
        try {
          result[date] = WeatherData(
            timestamp: date,
            temperature: weatherInfo['temperature']?.toDouble() ?? 20.0,
            humidity: weatherInfo['humidity']?.toDouble() ?? 50.0,
            windSpeed: weatherInfo['windSpeed']?.toDouble() ?? 0.0,
            rainfall: weatherInfo['precipitation']?.toDouble() ?? 0.0,
            solarRadiation:
                0.0, // Default value as this might not be in the weather data
          );
        } catch (e) {
          print('Error converting weather data for $date: $e');
        }
      }
    });

    return result;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Calculate date range
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: _selectedTimeRange));

      // Load bee counts
      final beeCounts =
          await BeeCountDatabase.instance.getBeeCountsForDateRange(
        widget.hiveId,
        startDate,
        endDate,
      ); // Load weather data
      final rawWeatherData = await WeatherService.getWeatherDataForDateRange(
        startDate,
        endDate,
      );
      final weatherData = await _convertWeatherData(rawWeatherData);

      // Generate sample hive data based on bee counts
      // In a real app, this would come from your hive database
      final hiveData = _generateSampleHiveData(
          beeCounts); // Calculate correlations between bee activity and other metrics
      final calculatedCorrelations =
          _calculateCorrelations(beeCounts, weatherData, hiveData);

      setState(() {
        _beeCounts = beeCounts;
        _weatherData = weatherData;
        _hiveData = hiveData;
        _correlations = calculatedCorrelations;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, double> _calculateCorrelations(
    List<BeeCount> beeCounts,
    Map<DateTime, WeatherData> weatherData,
    List<HiveData> hiveData,
  ) {
    final correlations = <String, double>{
      'Temperature': 0.0,
      'Humidity': 0.0,
      'Wind Speed': 0.0,
      'Time of Day': 0.0,
      'Hive Weight': 0.0,
    };

    if (beeCounts.isEmpty || weatherData.isEmpty) {
      return correlations;
    }

    // Prepare data for correlation calculations
    final List<_DataPoint> dataPoints = [];

    for (final count in beeCounts) {
      // Find the closest weather data point
      WeatherData? nearestWeather;
      Duration smallestDiff = const Duration(days: 1);

      for (final entry in weatherData.entries) {
        final diff = (entry.key.difference(count.timestamp)).abs();
        if (diff < smallestDiff) {
          smallestDiff = diff;
          nearestWeather = entry.value;
        }
      }

      // Find the closest hive data point
      HiveData? nearestHiveData;
      smallestDiff = const Duration(days: 1);
      for (final data in hiveData) {
        try {
          final timestamp = DateTime.parse(data.lastChecked);
          final diff = (timestamp.difference(count.timestamp)).abs();
          if (diff < smallestDiff) {
            smallestDiff = diff;
            nearestHiveData = data;
          }
        } catch (e) {
          print('Error parsing date: $e');
        }
      }

      // Only add if we have all the data
      if (nearestWeather != null && nearestHiveData != null) {
        dataPoints.add(
          _DataPoint(
            activity: count.beesEntering + count.beesExiting,
            temperature: nearestWeather.temperature,
            humidity: nearestWeather.humidity,
            windSpeed: nearestWeather.windSpeed,
            timeOfDay: count.timestamp.hour.toDouble(),
            weight: nearestHiveData.weight ?? 0.0,
          ),
        );
      }
    }

    if (dataPoints.isEmpty) {
      return correlations;
    }

    // Calculate correlation coefficients
    correlations['Temperature'] = _calculatePearsonCorrelation(
      dataPoints.map((p) => p.temperature).toList(),
      dataPoints.map((p) => p.activity.toDouble()).toList(),
    );

    correlations['Humidity'] = _calculatePearsonCorrelation(
      dataPoints.map((p) => p.humidity).toList(),
      dataPoints.map((p) => p.activity.toDouble()).toList(),
    );

    correlations['Wind Speed'] = _calculatePearsonCorrelation(
      dataPoints.map((p) => p.windSpeed).toList(),
      dataPoints.map((p) => p.activity.toDouble()).toList(),
    );

    // For time of day, we use a circular correlation approach
    // by converting hour to sin(hour * 2π/24)
    correlations['Time of Day'] = _calculatePearsonCorrelation(
      dataPoints.map((p) => _normalizeTimeOfDay(p.timeOfDay)).toList(),
      dataPoints.map((p) => p.activity.toDouble()).toList(),
    );

    correlations['Hive Weight'] = _calculatePearsonCorrelation(
      dataPoints.map((p) => p.weight).toList(),
      dataPoints.map((p) => p.activity.toDouble()).toList(),
    );

    return correlations;
  }

  // Helper function to normalize time of day (converts hours to a continuous cycle)
  double _normalizeTimeOfDay(double hour) {
    return (hour / 24) * 2 * 3.14159; // Convert to radians on a 24-hour cycle
  }

  // Calculate Pearson correlation coefficient
  double _calculatePearsonCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.isEmpty) return 0.0;

    final n = x.length;

    // Calculate means
    final xMean = x.reduce((a, b) => a + b) / n;
    final yMean = y.reduce((a, b) => a + b) / n;

    // Calculate sums of squares
    double numerator = 0.0;
    double xSumSquares = 0.0;
    double ySumSquares = 0.0;

    for (int i = 0; i < n; i++) {
      final xDiff = x[i] - xMean;
      final yDiff = y[i] - yMean;

      numerator += xDiff * yDiff;
      xSumSquares += xDiff * xDiff;
      ySumSquares += yDiff * yDiff;
    }

    // Avoid division by zero
    if (xSumSquares == 0.0 || ySumSquares == 0.0) return 0.0;

    return numerator / (sqrt(xSumSquares) * sqrt(ySumSquares));
  }

  // Helper function for square root (to avoid importing dart:math)
  double sqrt(double value) {
    double x = value;
    double y = 1.0;
    double e = 0.000001; // Precision
    while (x - y > e) {
      x = (x + y) / 2;
      y = value / x;
    }
    return x;
  }

  // Generate sample hive data based on bee counts
  List<HiveData> _generateSampleHiveData(List<BeeCount> beeCounts) {
    // Group bee counts by day
    final Map<DateTime, List<BeeCount>> countsByDay = {};

    for (final count in beeCounts) {
      final day = DateTime(
        count.timestamp.year,
        count.timestamp.month,
        count.timestamp.day,
      );

      if (!countsByDay.containsKey(day)) {
        countsByDay[day] = [];
      }

      countsByDay[day]!.add(count);
    }

    // Create one hive data point per day
    final hiveData = <HiveData>[];
    double baseWeight = 50.0; // Start with 50kg

    // Sort days
    final sortedDays = countsByDay.keys.toList()..sort();

    for (final day in sortedDays) {
      // Calculate daily activity
      final dayCounts = countsByDay[day]!;
      int totalIn = 0;
      int totalOut = 0;

      for (final count in dayCounts) {
        totalIn += count.beesEntering;
        totalOut += count.beesExiting;
      }

      // Adjust weight based on net bee entries (more entries generally means more nectar/honey)
      // This is just for demonstration - in a real app, you'd use actual hive weight measurements
      final netChange = totalIn - totalOut;
      baseWeight += (netChange > 0) ? 0.05 : -0.02; // Small daily change

      // Ensure weight doesn't go too low
      baseWeight = baseWeight < 30.0 ? 30.0 : baseWeight;

      hiveData.add(
        HiveData(
          id: widget.hiveId,
          name: 'Hive ${widget.hiveId}',
          status: 'Active',
          healthStatus: 'Healthy',
          lastChecked: day.toIso8601String(),
          autoProcessingEnabled: true,
          weight: baseWeight,
          temperature: 35.0,
          honeyLevel: (baseWeight - 30.0) /
              50.0 *
              100.0, // Estimate honey level based on weight
          isConnected: true,
          isColonized: true,
        ),
      );
    }

    return hiveData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bee Activity Correlations'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_beeCounts.isEmpty) {
      return Center(
        child: Text(
          'No bee activity data available for this hive.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeRangeSelector(),
          const SizedBox(height: 16),

          // Section: Bee Activity Timeline
          _buildSection(
            title: 'Bee Activity Timeline',
            description: 'Shows the pattern of bee entries and exits over time',
            content: BeeActivityVisualization.buildActivityTimelineChart(
              beeCounts: _beeCounts,
              context: context,
            ),
          ),

          // Section: Time of Day Analysis
          _buildSection(
            title: 'Time of Day Analysis',
            description: 'Shows how bee activity varies throughout the day',
            content: BeeActivityVisualization.buildTimeOfDayActivityChart(
              beeCounts: _beeCounts,
              context: context,
            ),
          ),

          // Section: Temperature Correlation
          _buildSection(
            title: 'Temperature Correlation',
            description: 'Shows how bee activity correlates with temperature',
            content: BeeActivityVisualization.buildTemperatureCorrelationChart(
              beeCounts: _beeCounts,
              weatherData: _weatherData,
              context: context,
            ),
          ),

          // Section: Humidity Correlation
          _buildSection(
            title: 'Humidity Correlation',
            description:
                'Shows how bee activity correlates with humidity levels',
            content: BeeActivityVisualization.buildHumidityCorrelationChart(
              beeCounts: _beeCounts,
              weatherData: _weatherData,
              context: context,
            ),
          ),

          // Section: Weight/Honey Correlation
          _buildSection(
            title: 'Hive Weight Correlation',
            description:
                'Shows the relationship between bee activity and hive weight over time',
            content: BeeActivityVisualization.buildWeightCorrelationChart(
              beeCounts: _beeCounts,
              hiveData: _hiveData,
              context: context,
            ),
          ),

          // Data insights
          const SizedBox(height: 20),
          BeeActivityVisualization.buildCorrelationInsights(
            correlations: _correlations,
            context: context,
          ),
          
          // Enhanced Analytics Button
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IntegratedHiveMonitoring(
                      hiveId: widget.hiveId,
                      token: '', // Add token if available
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.insights),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              label: const Text('View Enhanced Hive Monitoring'),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              'The enhanced monitoring dashboard provides a comprehensive view with improved correlation analytics and visualization.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Range',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeRangeButton(7, '7 Days'),
                _buildTimeRangeButton(14, '14 Days'),
                _buildTimeRangeButton(30, '30 Days'),
                _buildTimeRangeButton(90, '90 Days'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeButton(int days, String label) {
    final isSelected = _selectedTimeRange == days;

    return SizedBox(
      width: 80,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedTimeRange = days;
          });
          _loadData();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Theme.of(context).primaryColor : null,
          foregroundColor: isSelected ? Colors.white : null,
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required Widget content,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }
}

/// Helper class for data correlation calculations
class _DataPoint {
  final int activity;
  final double temperature;
  final double humidity;
  final double windSpeed;
  final double timeOfDay;
  final double weight;

  _DataPoint({
    required this.activity,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.timeOfDay,
    required this.weight,
  });
}
