// FILE: lib/bee_counter/bee_dashboard_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/bee_counter/bee_count_database.dart';
import 'package:farmer_app/bee_counter/weather-service.dart';
import 'package:farmer_app/bee_counter/foraging_efficiency_metric.dart' as efficiency;
import 'package:farmer_app/bee_counter/weatherdata.dart';
import 'package:farmer_app/bee_counter/foraging_report_generator.dart' as report_gen;

class BeeDashboardScreen extends StatefulWidget {
  final String hiveId;

  const BeeDashboardScreen({Key? key, required this.hiveId}) : super(key: key);

  @override
  _BeeDashboardScreenState createState() => _BeeDashboardScreenState();
}

class _BeeDashboardScreenState extends State<BeeDashboardScreen> {
  List<BeeCount> _recentCounts = [];
  Map<String, dynamic> _quickStats = {};
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  bool _generatingReport = false;
  int _selectedTimeRange = 30; // Default to 30 days

  // Report generator - use correct class name with alias
  final report_gen.ForagingReportGenerator _reportGenerator =
      report_gen.ForagingReportGenerator(
        hiveId: '', // This will be set in generateReport
        startDate: DateTime.now(),
        endDate: DateTime.now(),
      );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Calculate date range based on selected time range
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: _selectedTimeRange));

      // Load bee counts for date range
      final counts = await BeeCountDatabase.instance.getBeeCountsForDateRange(
        widget.hiveId,
        startDate,
        endDate,
      );

      // Calculate quick stats
      final stats = await _calculateQuickStats(counts);

      setState(() {
        _recentCounts = counts;
        _quickStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _calculateQuickStats(
    List<BeeCount> counts,
  ) async {
    final Map<String, dynamic> stats = {};

    if (counts.isEmpty) {
      return {
        'totalBeesIn': 0,
        'totalBeesOut': 0,
        'netChange': 0,
        'avgDailyActivity': 0,
        'peakDay': null,
        'peakDayActivity': 0,
        'recentTrend': 'neutral',
      };
    }

    // Calculate total values
    int totalBeesIn = 0;
    int totalBeesOut = 0;

    for (final count in counts) {
      totalBeesIn += count.beesEntering;
      totalBeesOut += count.beesExiting;
    }

    // Group by day for daily stats
    final Map<DateTime, List<BeeCount>> dailyCounts = {};
    for (final count in counts) {
      final day = DateTime(
        count.timestamp.year,
        count.timestamp.month,
        count.timestamp.day,
      );

      if (!dailyCounts.containsKey(day)) {
        dailyCounts[day] = [];
      }

      dailyCounts[day]!.add(count);
    }

    // Calculate daily activity totals
    final Map<DateTime, int> dailyActivity = {};
    DateTime? peakDay;
    int peakDayActivity = 0;

    dailyCounts.forEach((day, dayCounts) {
      int dayTotal = 0;
      for (final count in dayCounts) {
        dayTotal += count.beesEntering + count.beesExiting;
      }

      dailyActivity[day] = dayTotal;

      if (dayTotal > peakDayActivity) {
        peakDayActivity = dayTotal;
        peakDay = day;
      }
    });

    // Calculate average daily activity
    final avgDailyActivity =
        dailyActivity.isEmpty
            ? 0.0
            : dailyActivity.values.reduce((a, b) => a + b) /
                dailyActivity.length;

    // Determine recent trend (last 7 days vs previous 7 days)
    String recentTrend = 'neutral';
    if (dailyActivity.length >= 14) {
      final sortedDays =
          dailyActivity.keys.toList()..sort((a, b) => a.compareTo(b));

      final lastSevenDays = sortedDays.sublist(sortedDays.length - 7);
      final previousSevenDays = sortedDays.sublist(
        sortedDays.length - 14,
        sortedDays.length - 7,
      );

      int lastSevenTotal = 0;
      int previousSevenTotal = 0;

      for (final day in lastSevenDays) {
        lastSevenTotal += dailyActivity[day]!;
      }

      for (final day in previousSevenDays) {
        previousSevenTotal += dailyActivity[day]!;
      }

      final lastSevenAvg = lastSevenTotal / 7;
      final previousSevenAvg = previousSevenTotal / 7;

      // Determine trend based on 10% change threshold
      final percentChange =
          (lastSevenAvg - previousSevenAvg) / previousSevenAvg * 100;

      if (percentChange >= 10) {
        recentTrend = 'increasing';
      } else if (percentChange <= -10) {
        recentTrend = 'decreasing';
      } else {
        recentTrend = 'stable';
      }
    }

    // Build stats object
    stats['totalBeesIn'] = totalBeesIn;
    stats['totalBeesOut'] = totalBeesOut;
    stats['netChange'] = totalBeesIn - totalBeesOut;
    stats['avgDailyActivity'] = avgDailyActivity.round();
    stats['peakDay'] = peakDay;
    stats['peakDayActivity'] = peakDayActivity;
    stats['recentTrend'] = recentTrend;
    stats['dailyActivity'] = dailyActivity;

    return stats;
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(Duration(days: _selectedTimeRange)),
        end: DateTime.now(),
      ),
    );

    if (picked != null) {
      final daysDifference = picked.end.difference(picked.start).inDays + 1;

      setState(() {
        _selectedTimeRange = daysDifference;
      });

      _loadData();
    }
  }

  Future<void> _generateReport() async {
    setState(() {
      _generatingReport = true;
    });

    try {
      // Create date range
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: _selectedTimeRange));

      // Load all required data
      final beeCounts = await BeeCountDatabase.instance
          .getBeeCountsForDateRange(widget.hiveId, startDate, endDate);

      // Get weather data for the period
      final weatherService = WeatherService();
      final weatherData = await weatherService.getWeatherDataForDateRange(
        startDate,
        endDate,
      );

      // Generate analysis
      final analysisData = await _runAnalysis(beeCounts, weatherData);

      // Get efficiency metrics
      final efficiencyMetrics = await _calculateEfficiencyMetrics(
        beeCounts,
        weatherData,
      );

      // Generate advisories
      final advisories = _generateAdvisories(analysisData, efficiencyMetrics);

      // Generate report
      final reportFile = await _reportGenerator.generateReport();

      // View the report
      await _reportGenerator.viewReport(context, reportFile);
    } catch (e) {
      print('Error generating report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _generatingReport = false;
      });
    }
  }

  Future<Map<String, dynamic>> _runAnalysis(
    List<BeeCount> counts,
    Map<DateTime, WeatherData> weather,
  ) async {
    // This is a simplified version of the analysis - in a real app,
    // this would call into the BeeAnalysisScreen's analysis methods
    // or use a dedicated AnalysisService

    final analysis = <String, dynamic>{};

    // Add date range
    analysis['startDate'] = DateTime.now().subtract(
      Duration(days: _selectedTimeRange),
    );
    analysis['endDate'] = DateTime.now();

    // Group counts by time period (morning, noon, evening)
    final periodCounts = await BeeCountDatabase.instance
        .getAverageCountsByTimePeriod(
          widget.hiveId,
          analysis['startDate'],
          analysis['endDate'],
        );

    // Get daily averages
    final dailyAverages = await BeeCountDatabase.instance.getDailyAverageCounts(
      widget.hiveId,
      analysis['startDate'],
      analysis['endDate'],
    );

    // Simplified correlation calculation
    // In a real app, this would be more sophisticated
    double temperatureCorrelation = 0.3; // Example value
    double humidityCorrelation = -0.2; // Example value
    double windCorrelation = -0.4; // Example value

    // Simplified optimal conditions
    // In a real app, this would be calculated from the data
    analysis['optimalConditions'] = {
      'temperature': 25.0,
      'humidity': 65.0,
      'wind': 2.5,
    };

    // Determine peak activity time
    String peakActivityPeriod = 'morning';
    double maxActivity = 0;

    periodCounts.forEach((period, data) {
      final totalActivity = data['totalActivity'] ?? 0.0;
      if (totalActivity > maxActivity) {
        maxActivity = totalActivity;
        peakActivityPeriod = period;
      }
    });

    // Build final analysis object
    analysis['totalCounts'] = counts.length;
    analysis['periodCounts'] = periodCounts;
    analysis['dailyAverages'] = dailyAverages;
    analysis['temperatureCorrelation'] = temperatureCorrelation;
    analysis['humidityCorrelation'] = humidityCorrelation;
    analysis['windCorrelation'] = windCorrelation;
    analysis['peakActivityTime'] = peakActivityPeriod;

    return analysis;
  }

  // Use the prefixed class name to avoid ambiguity
  Future<List<efficiency.ForagingEfficiencyMetric>> _calculateEfficiencyMetrics(
    List<BeeCount> counts,
    Map<DateTime, WeatherData> weather,
  ) async {
    // Simplified version of efficiency calculation
    final List<efficiency.ForagingEfficiencyMetric> metrics = [];

    if (counts.isEmpty) {
      return metrics;
    }

    // Group counts by day
    final dailyCounts = <DateTime, List<BeeCount>>{};
    for (final count in counts) {
      final day = DateTime(
        count.timestamp.year,
        count.timestamp.month,
        count.timestamp.day,
      );

      if (!dailyCounts.containsKey(day)) {
        dailyCounts[day] = [];
      }

      dailyCounts[day]!.add(count);
    }

    // Calculate daily efficiency metrics
    for (final day in dailyCounts.keys) {
      final dayCounts = dailyCounts[day]!;

      // Get average weather for the day
      double avgTemp = 0.0;
      double avgHumidity = 0.0;
      double avgWind = 0.0;
      int weatherPoints = 0;

      for (var hour = 0; hour < 24; hour++) {
        final time = DateTime(day.year, day.month, day.day, hour);
        if (weather.containsKey(time)) {
          avgTemp += weather[time]!.temperature;
          avgHumidity += weather[time]!.humidity;
          avgWind += weather[time]!.windSpeed;
          weatherPoints++;
        }
      }

      if (weatherPoints > 0) {
        avgTemp /= weatherPoints;
        avgHumidity /= weatherPoints;
        avgWind /= weatherPoints;
      }

      // Calculate foraging metrics
      int totalIn = 0;
      int totalOut = 0;

      // Keep track of activity by time period to determine peak time
      Map<String, int> activityByPeriod = {
        'morning': 0, // 5-10 AM
        'noon': 0, // 10 AM-3 PM
        'evening': 0, // 3-8 PM
      };

      for (final count in dayCounts) {
        totalIn += count.beesEntering;
        totalOut += count.beesExiting;

        // Track activity by time period
        final hour = count.timestamp.hour;
        final periodActivity = count.beesEntering + count.beesExiting;

        if (hour >= 5 && hour < 10) {
          activityByPeriod['morning'] =
              (activityByPeriod['morning'] ?? 0) + periodActivity;
        } else if (hour >= 10 && hour < 15) {
          activityByPeriod['noon'] =
              (activityByPeriod['noon'] ?? 0) + periodActivity;
        } else if (hour >= 15 && hour < 20) {
          activityByPeriod['evening'] =
              (activityByPeriod['evening'] ?? 0) + periodActivity;
        }
      }

      // Determine peak time period
      String? peakTimePeriod;
      int maxActivity = 0;

      activityByPeriod.forEach((period, activity) {
        if (activity > maxActivity) {
          maxActivity = activity;
          peakTimePeriod = period;
        }
      });

      final totalActivity = totalIn + totalOut;
      final netChange = totalIn - totalOut;

      // Calculate return rate
      final returnRate = totalOut > 0 ? totalIn / totalOut : 0.0;

      // Calculate efficiency score
      final efficiencyScore = efficiency
          .ForagingEfficiencyCalculator.calculateEfficiencyScore(
        totalBeesIn: totalIn,
        totalBeesOut: totalOut,
        temperature: avgTemp,
        windSpeed: avgWind,
        timestamp: day,
      );
    }

    // Sort by date with null safety
    if (metrics.isNotEmpty) {
      metrics.sort((a, b) => a.date.compareTo(b.date));
    }

    return metrics;
  }

  List<String> _generateAdvisories(
    Map<String, dynamic> analysis,
    List<efficiency.ForagingEfficiencyMetric> metrics,
  ) {
    // Simplified version of advisory generation
    final advisories = <String>[
      'OPTIMAL FORAGING CONDITIONS:\n\n'
          'Based on your colony\'s historical data, optimal foraging conditions include:\n'
          '• Temperature: ${analysis['optimalConditions']['temperature'].toStringAsFixed(1)}°C\n'
          '• Humidity: ${analysis['optimalConditions']['humidity'].toStringAsFixed(0)}%\n'
          '• Wind Speed: ${analysis['optimalConditions']['wind'].toStringAsFixed(1)} m/s\n'
          '• Peak activity time: ${_formatPeakTime(analysis['peakActivityTime'])}\n\n'
          'Plan hive management activities and inspections outside of peak foraging hours to minimize disruption to the colony\'s foraging cycle.',

      'FORAGING TIMING ADVISORY:\n\n'
          'Your hive shows highest foraging activity during ${_formatPeriod(analysis['peakActivityTime'])}.\n\n'
          'Research indicates that honey bee foraging patterns are closely tied to daily floral nectar rhythms. Consider:\n'
          '• Placing hives where morning sun will warm them early, encouraging earlier foraging\n'
          '• Ensuring a water source is available within 100 meters of the hive\n'
          '• Observing which plant species are being visited during peak activity times\n'
          '• Timing supplemental feeding to avoid interfering with natural foraging patterns',
    ];

    return advisories;
  }

  String _formatPeakTime(String period) {
    switch (period) {
      case 'morning':
        return 'Morning (5-10 AM)';
      case 'noon':
        return 'Midday (10 AM-3 PM)';
      case 'evening':
        return 'Evening (3-8 PM)';
      default:
        return period;
    }
  }

  String _formatPeriod(String period) {
    switch (period) {
      case 'morning':
        return 'morning hours (5-10 AM)';
      case 'noon':
        return 'midday hours (10 AM-3 PM)';
      case 'evening':
        return 'evening hours (3-8 PM)';
      default:
        return period;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hive ${widget.hiveId} Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildDashboard(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder:
          //         (context) => BeeAnalysisScreen(
          //           hiveId: widget.hiveId,
          //           startDate: DateTime.now().subtract(
          //             Duration(days: _selectedTimeRange),
          //           ),
          //           endDate: DateTime.now(),
          //         ),
          //   ),
          // );
        },
        label: const Text('Full Analysis'),
        icon: const Icon(Icons.analytics),
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time range indicator
          _buildTimeRangeSelector(),
          const SizedBox(height: 16),

          // Quick stats cards
          _buildQuickStatsSection(),
          const SizedBox(height: 24),

          // Recent activity chart
          _buildRecentActivitySection(),
          const SizedBox(height: 24),

          // Key insights and recommendations
          _buildInsightsSection(),
          const SizedBox(height: 24),

          // Actions section
          _buildActionsSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time Range', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),

            // Time range buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTimeRangeButton('7 Days', 7),
                  _buildTimeRangeButton('30 Days', 30),
                  _buildTimeRangeButton('90 Days', 90),
                  _buildTimeRangeButton('1 Year', 365),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Custom'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Text(
              'Showing data from ${DateFormat('MMM d, yyyy').format(DateTime.now().subtract(Duration(days: _selectedTimeRange)))} to ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeButton(String label, int days) {
    final isSelected = _selectedTimeRange == days;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
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

  Widget _buildQuickStatsSection() {
    final totalBeesIn = _quickStats['totalBeesIn'] ?? 0;
    final totalBeesOut = _quickStats['totalBeesOut'] ?? 0;
    final netChange = _quickStats['netChange'] ?? 0;
    final avgDaily = _quickStats['avgDailyActivity'] ?? 0;
    final peakDay = _quickStats['peakDay'] as DateTime?;
    final peakActivity = _quickStats['peakDayActivity'] ?? 0;
    final trend = _quickStats['recentTrend'] ?? 'neutral';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Stats', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),

        // Stats cards in grid
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStatCard(
              'Total Bees Entering',
              totalBeesIn.toString(),
              Icons.arrow_downward,
              Colors.green,
            ),
            _buildStatCard(
              'Total Bees Exiting',
              totalBeesOut.toString(),
              Icons.arrow_upward,
              Colors.orange,
            ),
            _buildStatCard(
              'Net Colony Change',
              netChange.toString(),
              netChange >= 0 ? Icons.add : Icons.remove,
              netChange >= 0 ? Colors.green : Colors.red,
              subtitle: netChange >= 0 ? 'Net gain' : 'Net loss',
            ),
            _buildStatCard(
              'Average Daily Activity',
              avgDaily.toString(),
              Icons.show_chart,
              Colors.blue,
              subtitle: 'Bees per day',
            ),
            _buildStatCard(
              'Peak Activity Day',
              peakDay != null ? DateFormat('MMM d').format(peakDay) : 'N/A',
              Icons.calendar_today,
              Colors.purple,
              subtitle: 'Activity: $peakActivity',
            ),
            _buildStatCard(
              'Recent Trend',
              _getTrendText(trend),
              _getTrendIcon(trend),
              _getTrendColor(trend),
              subtitle: 'Last 7 days vs previous',
            ),
          ],
        ),
      ],
    );
  }

  String _getTrendText(String trend) {
    switch (trend) {
      case 'increasing':
        return 'Increasing';
      case 'decreasing':
        return 'Decreasing';
      case 'stable':
        return 'Stable';
      default:
        return 'Neutral';
    }
  }

  IconData _getTrendIcon(String trend) {
    switch (trend) {
      case 'increasing':
        return Icons.trending_up;
      case 'decreasing':
        return Icons.trending_down;
      case 'stable':
        return Icons.trending_flat;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Color _getTrendColor(String trend) {
    switch (trend) {
      case 'increasing':
        return Colors.green;
      case 'decreasing':
        return Colors.red;
      case 'stable':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null)
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    final dailyActivity =
        _quickStats['dailyActivity'] as Map<DateTime, int>? ?? {};

    if (dailyActivity.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No activity data available for the selected period',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }

    // Sort dates for chart
    final sortedDates =
        dailyActivity.keys.toList()..sort((a, b) => a.compareTo(b));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),

        Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Foraging Activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),

                // Activity chart
                SizedBox(
                  height: 200,
                  child: _buildActivityChart(sortedDates, dailyActivity),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityChart(
    List<DateTime> dates,
    Map<DateTime, int> activity,
  ) {
    if (dates.isEmpty) {
      return const Center(child: Text('No activity data available'));
    }

    // Create spots for line chart
    List<FlSpot> spots = [];
    for (int i = 0; i < dates.length; i++) {
      spots.add(FlSpot(i.toDouble(), activity[dates[i]]!.toDouble()));
    }

    // Calculate max Y value for chart
    double maxY = 0;
    activity.values.forEach((value) {
      if (value > maxY) maxY = value.toDouble();
    });

    // Add 20% to max Y for better visualization
    maxY = (maxY * 1.2).ceilToDouble();
    if (maxY == 0) maxY = 10;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                // Show about 5 dates on x-axis

                if (value.toInt() % max(1, (dates.length / 5).round()) != 0) {
                  return const SizedBox.shrink();
                }

                if (value.toInt() >= 0 && value.toInt() < dates.length) {
                  final date = dates[value.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('M/d').format(date),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                // Show about 5 values on y-axis
                if (value % (maxY / 5).ceilToDouble() != 0) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
        ),
        minX: 0,
        maxX: (dates.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).primaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).primaryColor.withOpacity(0.2),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final date = dates[touchedSpot.x.toInt()];
                final activity = touchedSpot.y.round();
                return LineTooltipItem(
                  '${DateFormat('MMM d').format(date)}\n$activity bees',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsSection() {
    // Get insights based on data
    final insights = _generateInsights();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Key Insights', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),

        Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show insights
                for (int i = 0; i < insights.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i < insights.length - 1 ? 16.0 : 0,
                    ),
                    child: _buildInsightItem(
                      insights[i]['title'] as String,
                      insights[i]['description'] as String,
                      insights[i]['icon'] as IconData,
                      insights[i]['color'] as Color,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightItem(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _generateInsights() {
    final insights = <Map<String, dynamic>>[];

    // Get required data from stats
    final totalBeesIn = _quickStats['totalBeesIn'] ?? 0;
    final totalBeesOut = _quickStats['totalBeesOut'] ?? 0;
    final netChange = _quickStats['netChange'] ?? 0;
    final trend = _quickStats['recentTrend'] ?? 'neutral';

    // Insight 1: Colony growth/decline
    if (netChange > 0) {
      insights.add({
        'title': 'Colony Growth Detected',
        'description':
            'Your colony has grown by $netChange bees during this period, indicating good health and productivity.',
        'icon': Icons.trending_up,
        'color': Colors.green,
      });
    } else if (netChange < 0) {
      insights.add({
        'title': 'Colony Decline Detected',
        'description':
            'Your colony has decreased by ${netChange.abs()} bees during this period. Consider checking for queen issues, disease, or resource limitations.',
        'icon': Icons.trending_down,
        'color': Colors.red,
      });
    } else {
      insights.add({
        'title': 'Stable Colony Size',
        'description':
            'Your colony size has remained stable during this period. This can indicate a healthy balance between bee production and natural losses.',
        'icon': Icons.trending_flat,
        'color': Colors.blue,
      });
    }

    // Insight 2: Recent trend
    if (trend == 'increasing') {
      insights.add({
        'title': 'Increasing Activity Trend',
        'description':
            'Foraging activity has increased over the past week, suggesting improved weather conditions or increased available forage.',
        'icon': Icons.arrow_upward,
        'color': Colors.green,
      });
    } else if (trend == 'decreasing') {
      insights.add({
        'title': 'Decreasing Activity Trend',
        'description':
            'Foraging activity has decreased over the past week, possibly due to changing weather, depleted resources, or colony issues.',
        'icon': Icons.arrow_downward,
        'color': Colors.orange,
      });
    } else {
      insights.add({
        'title': 'Stable Activity Pattern',
        'description':
            'Foraging activity has remained consistent over the past week, indicating stable environmental conditions and colony health.',
        'icon': Icons.swap_horiz,
        'color': Colors.blue,
      });
    }

    // Insight 3: Forage recommendation based on data
    // In a real app, this would be more sophisticated based on activity patterns
    insights.add({
      'title': 'Forage Recommendation',
      'description':
          'Based on current foraging patterns, consider ensuring diverse pollen sources are available within 2km of the hive to maintain nutrition needs.',
      'icon': Icons.landscape,
      'color': Colors.green,
    });

    return insights;
  }

  Widget _buildActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Generate Report',
                Icons.description,
                _generatingReport ? null : _generateReport,
                isLoading: _generatingReport,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton('Full Analysis', Icons.analytics, () {
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(
                //     builder:
                //         (context) => BeeAnalysisScreen(
                //           hiveId: widget.hiveId,
                //           startDate: DateTime.now().subtract(
                //             Duration(days: _selectedTimeRange),
                //           ),
                //           endDate: DateTime.now(),
                //         ),
                //   ),
                // );
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback? onPressed, {
    bool isLoading = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon:
          isLoading
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    );
  }
}

