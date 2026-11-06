// File: lib/bee_counter/integrated_hive_monitoring.dart
import 'package:flutter/material.dart';
import 'package:flutter_echarts/flutter_echarts.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:convert';
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/bee_counter/bee_count_database.dart';
import 'package:farmer_app/bee_counter/bee_count_correlation_repository.dart';
import 'package:fl_chart/fl_chart.dart';

/// A widget that displays integrated monitoring data with correlations
/// This component combines temperature, humidity, weight, and bee count data
/// in a single view, improving the utility of the monitoring data
class IntegratedHiveMonitoring extends StatefulWidget {
  final String hiveId;
  final String token;

  const IntegratedHiveMonitoring({
    Key? key,
    required this.hiveId,
    required this.token,
  }) : super(key: key);

  @override
  _IntegratedHiveMonitoringState createState() => _IntegratedHiveMonitoringState();
}

class _IntegratedHiveMonitoringState extends State<IntegratedHiveMonitoring> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Date range for data filtering
  late DateTime _startDate;
  late DateTime _endDate;
  
  // Repository for correlation data
  final _repository = BeeCountCorrelationRepository();
  
  // Data for charts
  List<DateTime> _dates = [];
  Map<String, List<double>> _metricValues = {
    'temperature': [],
    'humidity': [],
    'weight': [],
    'beeCount': [],
  };
  
  // Correlation values
  Map<String, double> _correlations = {
    'Temperature': 0.0,
    'Humidity': 0.0,
    'Wind Speed': 0.0,
    'Time of Day': 0.0,
    'Hive Weight': 0.0,
  };
  
  // Insights based on correlations
  Map<String, String> _insights = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Initialize date range (last 30 days)
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));
    
    // Load the data
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
    /// Load all necessary data for the charts
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Calculate correlations
      final timeRangeDays = _endDate.difference(_startDate).inDays;
      final correlations = await _repository.calculateCorrelations(
        widget.hiveId,
        timeRangeDays,
      );
      
      // Generate insights
      final insights = _repository.generateDataInsights(correlations);
      
      // Prepare data for charts
      await _prepareChartData();
      
      setState(() {
        _correlations = correlations;
        _insights = insights;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading data: $e';
      });
    }
  }
  
  /// Prepare data for the charts
  Future<void> _prepareChartData() async {
    try {
      // Clear previous data
      _dates.clear();
      _metricValues.forEach((key, value) => value.clear());
      
      // Fetch temperature data from API
      await _fetchTemperatureData();
      
      // Fetch humidity data from API
      await _fetchHumidityData();
      
      // Fetch weight data from API
      await _fetchWeightData();
      
      // Fetch bee count data from local database
      await _fetchBeeCountData();
      
      // Sort dates to ensure chronological order
      _dates.sort();
    } catch (e) {
      print('Error preparing chart data: $e');
      rethrow;
    }
  }
    /// Fetch temperature data from the API
  Future<void> _fetchTemperatureData() async {
    try {
      // TODO: Implement actual API call
      // For now, generate some sample data
      final random = Random();
      final List<DateTime> tempDates = [];
      final List<double> temperatures = [];
      
      DateTime currentDate = _startDate;
      while (currentDate.isBefore(_endDate) || currentDate.isAtSameMomentAs(_endDate)) {
        tempDates.add(currentDate);
        
        // Generate realistic temperature values between 20 and 35
        final baseTemp = 25.0;
        final variation = random.nextDouble() * 10 - 5; // -5 to +5
        temperatures.add(baseTemp + variation);
        
        currentDate = currentDate.add(const Duration(days: 1));
      }
      
      // Add to our data collections
      _dates.addAll(tempDates);
      _metricValues['temperature'] = temperatures;
    } catch (e) {
      print('Error fetching temperature data: $e');
      rethrow;
    }
  }
  
  /// Fetch humidity data from the API
  Future<void> _fetchHumidityData() async {
    try {
      // TODO: Implement actual API call
      // For now, generate some sample data
      final random = Random();
      final List<double> humidities = [];
      
      DateTime currentDate = _startDate;
      while (currentDate.isBefore(_endDate) || currentDate.isAtSameMomentAs(_endDate)) {
        // Generate realistic humidity values between 40 and 80
        final baseHumidity = 60.0;
        final variation = random.nextDouble() * 20 - 10; // -10 to +10
        humidities.add(baseHumidity + variation);
        
        currentDate = currentDate.add(const Duration(days: 1));
      }
      
      // Add to our data collections
      _metricValues['humidity'] = humidities;
    } catch (e) {
      print('Error fetching humidity data: $e');
      rethrow;
    }
  }
  
  /// Fetch weight data from the API
  Future<void> _fetchWeightData() async {
    try {
      // TODO: Implement actual API call
      // For now, generate some sample data
      final random = Random();
      final List<double> weights = [];
      
      DateTime currentDate = _startDate;
      while (currentDate.isBefore(_endDate) || currentDate.isAtSameMomentAs(_endDate)) {
        // Generate realistic weight values that increase slightly over time
        final dayDifference = currentDate.difference(_startDate).inDays;
        final baseWeight = 50.0 + (dayDifference * 0.1); // Slight increase over time
        final variation = random.nextDouble() * 2 - 1; // -1 to +1
        weights.add(baseWeight + variation);
        
        currentDate = currentDate.add(const Duration(days: 1));
      }
      
      // Add to our data collections
      _metricValues['weight'] = weights;
    } catch (e) {
      print('Error fetching weight data: $e');
      rethrow;
    }
  }
    /// Fetch bee count data from the local database
  Future<void> _fetchBeeCountData() async {
    try {
      // Get bee counts from database
      final dbBeeCounts = await _repository.getBeeCountsForHiveInRange(
        widget.hiveId,
        _startDate,
        _endDate,
      );
      
      // Group by day to match the other metrics
      final Map<DateTime, int> countsByDay = {};
      for (final count in dbBeeCounts) {
        final day = DateTime(
          count.timestamp.year,
          count.timestamp.month,
          count.timestamp.day,
        );
        
        countsByDay[day] = (countsByDay[day] ?? 0) + count.totalActivity;
      }
      
      final List<double> beeCountValues = [];
      
      // Align with the dates we already have
      for (var date in _dates) {
        final day = DateTime(
          date.year,
          date.month,
          date.day,
        );
        
        beeCountValues.add(countsByDay[day]?.toDouble() ?? 0.0);
      }
      
      // If we have no bee count data, generate sample data
      if (beeCountValues.isEmpty && _metricValues['temperature'] != null && _metricValues['temperature']!.isNotEmpty) {
        final random = Random();
        
        for (int i = 0; i < _dates.length; i++) {
          // Generate bee count based on temperature (bees more active in warmer weather)
          final temp = _metricValues['temperature']![i];
          final baseCount = temp * 10; // More bees when warmer
          final variation = random.nextDouble() * 50 - 25; // +/- 25
          beeCountValues.add(max(0, baseCount + variation)); // Ensure non-negative
        }
      }
      
      // Add to our data collections
      _metricValues['beeCount'] = beeCountValues;
    } catch (e) {
      print('Error fetching bee count data: $e');
      rethrow;
    }
  }
  
  /// Select date range for data filtering
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.amber, // Header background color
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      
      // Reload data with new date range
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : Column(
                  children: [
                    // Header with date selector
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Hive Monitoring',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _selectDateRange(context),
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)}',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Insights card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildInsightsCard(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Tab bar
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.amber,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.amber,
                      tabs: const [
                        Tab(text: 'Temperature'),
                        Tab(text: 'Humidity'),
                        Tab(text: 'Weight'),
                        Tab(text: 'Combined'),
                      ],
                    ),
                    
                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Temperature with bee activity
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildCorrelationInfo('Temperature'),
                                const SizedBox(height: 16),
                                _buildTemperatureChart(),
                              ],
                            ),
                          ),
                          
                          // Humidity with bee activity
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildCorrelationInfo('Humidity'),
                                const SizedBox(height: 16),
                                _buildHumidityChart(),
                              ],
                            ),
                          ),
                          
                          // Weight with bee activity
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildCorrelationInfo('Hive Weight'),
                                const SizedBox(height: 16),
                                _buildWeightChart(),
                              ],
                            ),
                          ),
                          
                          // Combined chart
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Text(
                                  'Comprehensive View',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildCombinedChart(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        backgroundColor: Colors.amber,
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  /// Build the insights card with correlation data
  Widget _buildInsightsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber[800]),
                const SizedBox(width: 8),
                const Text(
                  'Smart Insights',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            ..._insights.entries.map((entry) {
              final factor = entry.key;
              final insight = entry.value;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _getInsightIcon(factor),
                      color: _getCorrelationColor(_correlations[factor] ?? 0),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  /// Build correlation info for a specific factor
  Widget _buildCorrelationInfo(String factor) {
    final correlation = _correlations[factor] ?? 0.0;
    final correlationText = _getCorrelationText(correlation);
    final color = _getCorrelationColor(correlation);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Correlation with Bee Activity: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$correlationText (${correlation.toStringAsFixed(2)})',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
  /// Build the temperature chart
  Widget _buildTemperatureChart() {
    // Skip if no data
    if (_dates.isEmpty || _metricValues['temperature']!.isEmpty) {
      return const Center(child: Text('No temperature data available'));
    }
    
    // Prepare data for ECharts
    final List<String> dateLabels = _dates.map((date) => DateFormat('MM/dd').format(date)).toList();
    final List<double> temperatures = _metricValues['temperature']!;
    final List<double> beeCounts = _metricValues['beeCount']!;
    
    // Convert to JSON format for ECharts
    final tempSeries = temperatures.map((temp) => temp).toList();
    final beeCountSeries = beeCounts.map((count) => count).toList();
    
    final options = {
      'tooltip': {
        'trigger': 'axis',
        'axisPointer': {
          'type': 'cross',
          'label': {
            'backgroundColor': '#6a7985'
          }
        }
      },
      'legend': {
        'data': ['Temperature (°C)', 'Bee Activity']
      },
      'xAxis': [
        {
          'type': 'category',
          'boundaryGap': false,
          'data': dateLabels
        }
      ],
      'yAxis': [
        {
          'type': 'value',
          'name': 'Temperature (°C)',
          'position': 'left',
          'axisLine': {
            'lineStyle': {
              'color': '#FF9800'
            }
          }
        },
        {
          'type': 'value',
          'name': 'Bee Activity',
          'position': 'right',
          'axisLine': {
            'lineStyle': {
              'color': '#4CAF50'
            }
          }
        }
      ],
      'series': [
        {
          'name': 'Temperature (°C)',
          'type': 'line',
          'yAxisIndex': 0,
          'data': tempSeries,
          'smooth': true,
          'itemStyle': {
            'color': '#FF9800'
          },
          'areaStyle': {
            'color': {
              'type': 'linear',
              'x': 0,
              'y': 0,
              'x2': 0,
              'y2': 1,
              'colorStops': [
                {
                  'offset': 0,
                  'color': 'rgba(255, 152, 0, 0.7)'
                },
                {
                  'offset': 1,
                  'color': 'rgba(255, 152, 0, 0.1)'
                }
              ]
            }
          }
        },
        {
          'name': 'Bee Activity',
          'type': 'line',
          'yAxisIndex': 1,
          'data': beeCountSeries,
          'smooth': true,
          'itemStyle': {
            'color': '#4CAF50'
          },
          'lineStyle': {
            'width': 2,
            'type': 'dashed'
          }
        }
      ],
      'grid': {
        'left': '3%',
        'right': '4%',
        'bottom': '3%',
        'containLabel': true
      }
    };
    
    return Container(
      height: 400,
      child: Echarts(
        option: '''${json.encode(options)}''',
        extraScript: '''
          chart.on('click', function(params) {
            if(window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('chartClick', params.name, params.value);
            }
          });
        ''',
      ),
    );
  }
  /// Build the humidity chart
  Widget _buildHumidityChart() {
    // Skip if no data
    if (_dates.isEmpty || _metricValues['humidity']!.isEmpty) {
      return const Center(child: Text('No humidity data available'));
    }
    
    // Prepare data for ECharts
    final List<String> dateLabels = _dates.map((date) => DateFormat('MM/dd').format(date)).toList();
    final List<double> humidities = _metricValues['humidity']!;
    final List<double> beeCounts = _metricValues['beeCount']!;
    
    // Convert to JSON format for ECharts
    final humiditySeries = humidities.map((humidity) => humidity).toList();
    final beeCountSeries = beeCounts.map((count) => count).toList();
    
    final options = {
      'tooltip': {
        'trigger': 'axis',
        'axisPointer': {
          'type': 'cross',
          'label': {
            'backgroundColor': '#6a7985'
          }
        }
      },
      'legend': {
        'data': ['Humidity (%)', 'Bee Activity']
      },
      'xAxis': [
        {
          'type': 'category',
          'boundaryGap': false,
          'data': dateLabels
        }
      ],
      'yAxis': [
        {
          'type': 'value',
          'name': 'Humidity (%)',
          'position': 'left',
          'axisLine': {
            'lineStyle': {
              'color': '#2196F3'
            }
          }
        },
        {
          'type': 'value',
          'name': 'Bee Activity',
          'position': 'right',
          'axisLine': {
            'lineStyle': {
              'color': '#4CAF50'
            }
          }
        }
      ],
      'series': [
        {
          'name': 'Humidity (%)',
          'type': 'line',
          'yAxisIndex': 0,
          'data': humiditySeries,
          'smooth': true,
          'itemStyle': {
            'color': '#2196F3'
          },
          'areaStyle': {
            'color': {
              'type': 'linear',
              'x': 0,
              'y': 0,
              'x2': 0,
              'y2': 1,
              'colorStops': [
                {
                  'offset': 0,
                  'color': 'rgba(33, 150, 243, 0.7)'
                },
                {
                  'offset': 1,
                  'color': 'rgba(33, 150, 243, 0.1)'
                }
              ]
            }
          }
        },
        {
          'name': 'Bee Activity',
          'type': 'line',
          'yAxisIndex': 1,
          'data': beeCountSeries,
          'smooth': true,
          'itemStyle': {
            'color': '#4CAF50'
          },
          'lineStyle': {
            'width': 2,
            'type': 'dashed'
          }
        }
      ],
      'grid': {
        'left': '3%',
        'right': '4%',
        'bottom': '3%',
        'containLabel': true
      }
    };
    
    return Container(
      height: 400,
      child: Echarts(
        option: '''${json.encode(options)}''',
        extraScript: '''
          chart.on('click', function(params) {
            if(window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('chartClick', params.name, params.value);
            }
          });
        ''',
      ),
    );
  }
  /// Build the weight chart
  Widget _buildWeightChart() {
    // Skip if no data
    if (_dates.isEmpty || _metricValues['weight']!.isEmpty) {
      return const Center(child: Text('No weight data available'));
    }
    
    // Prepare data for ECharts
    final List<String> dateLabels = _dates.map((date) => DateFormat('MM/dd').format(date)).toList();
    final List<double> weights = _metricValues['weight']!;
    final List<double> beeCounts = _metricValues['beeCount']!;
    
    // Convert to JSON format for ECharts
    final weightSeries = weights.map((weight) => weight).toList();
    final beeCountSeries = beeCounts.map((count) => count).toList();
    
    final options = {
      'tooltip': {
        'trigger': 'axis',
        'axisPointer': {
          'type': 'cross',
          'label': {
            'backgroundColor': '#6a7985'
          }
        }
      },
      'legend': {
        'data': ['Weight (kg)', 'Bee Activity']
      },
      'xAxis': [
        {
          'type': 'category',
          'boundaryGap': false,
          'data': dateLabels
        }
      ],
      'yAxis': [
        {
          'type': 'value',
          'name': 'Weight (kg)',
          'position': 'left',
          'axisLine': {
            'lineStyle': {
              'color': '#FFC107'
            }
          }
        },
        {
          'type': 'value',
          'name': 'Bee Activity',
          'position': 'right',
          'axisLine': {
            'lineStyle': {
              'color': '#4CAF50'
            }
          }
        }
      ],
      'series': [
        {
          'name': 'Weight (kg)',
          'type': 'line',
          'yAxisIndex': 0,
          'data': weightSeries,
          'smooth': true,
          'itemStyle': {
            'color': '#FFC107'
          },
          'areaStyle': {
            'color': {
              'type': 'linear',
              'x': 0,
              'y': 0,
              'x2': 0,
              'y2': 1,
              'colorStops': [
                {
                  'offset': 0,
                  'color': 'rgba(255, 193, 7, 0.7)'
                },
                {
                  'offset': 1,
                  'color': 'rgba(255, 193, 7, 0.1)'
                }
              ]
            }
          }
        },
        {
          'name': 'Bee Activity',
          'type': 'line',
          'yAxisIndex': 1,
          'data': beeCountSeries,
          'smooth': true,
          'itemStyle': {
            'color': '#4CAF50'
          },
          'lineStyle': {
            'width': 2,
            'type': 'dashed'
          }
        }
      ],
      'grid': {
        'left': '3%',
        'right': '4%',
        'bottom': '3%',
        'containLabel': true
      }
    };
    
    return Container(
      height: 400,
      child: Echarts(
        option: '''${json.encode(options)}''',
        extraScript: '''
          chart.on('click', function(params) {
            if(window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('chartClick', params.name, params.value);
            }
          });
        ''',
      ),
    );
  }
    /// Build a combined chart showing all metrics
  Widget _buildCombinedChart() {
    // Skip if no data
    if (_dates.isEmpty) {
      return const Center(child: Text('No data available'));
    }
    
    // Prepare data for ECharts
    final List<String> dateLabels = _dates.map((date) => DateFormat('MM/dd').format(date)).toList();
    
    // Convert data to match the expected format
    final tempSeries = _getMetricValues('temperature');
    final humiditySeries = _getMetricValues('humidity');
    final weightSeries = _getMetricValues('weight');
    final beeCountSeries = _getMetricValues('beeCount');
    
    final options = {
      'tooltip': {
        'trigger': 'axis',
        'axisPointer': {
          'type': 'cross',
          'label': {
            'backgroundColor': '#6a7985'
          }
        }
      },
      'legend': {
        'data': ['Temperature', 'Humidity', 'Weight', 'Bee Activity']
      },
      'xAxis': [
        {
          'type': 'category',
          'boundaryGap': false,
          'data': dateLabels
        }
      ],
      'yAxis': [
        {
          'type': 'value',
          'name': 'Temperature/Humidity',
          'position': 'left'
        },
        {
          'type': 'value',
          'name': 'Weight (kg)',
          'position': 'right',
          'offset': 80
        },
        {
          'type': 'value',
          'name': 'Bee Activity',
          'position': 'right'
        }
      ],
      'series': [
        {
          'name': 'Temperature',
          'type': 'line',
          'yAxisIndex': 0,
          'data': tempSeries,
          'itemStyle': {
            'color': '#FF9800'
          }
        },
        {
          'name': 'Humidity',
          'type': 'line',
          'yAxisIndex': 0,
          'data': humiditySeries,
          'itemStyle': {
            'color': '#2196F3'
          }
        },
        {
          'name': 'Weight',
          'type': 'line',
          'yAxisIndex': 1,
          'data': weightSeries,
          'itemStyle': {
            'color': '#FFC107'
          }
        },
        {
          'name': 'Bee Activity',
          'type': 'bar',
          'yAxisIndex': 2,
          'data': beeCountSeries,
          'itemStyle': {
            'color': '#4CAF50'
          }
        }
      ],
      'grid': {
        'left': '3%',
        'right': '10%',
        'bottom': '3%',
        'containLabel': true
      }
    };
    
    return Container(
      height: 450,
      child: Echarts(
        option: '''${json.encode(options)}''',
      ),
    );
  }
  
  /// Get metric values as a list, handling missing data points
  List<double> _getMetricValues(String metric) {
    if (_metricValues.containsKey(metric) && _metricValues[metric]!.isNotEmpty) {
      return _metricValues[metric]!;
    } else {
      return List.filled(_dates.length, 0.0);
    }
  }
  
  /// Get the color for a correlation value
  Color _getCorrelationColor(double value) {
    final absValue = value.abs();
    if (absValue < 0.1) {
      return Colors.grey;
    } else if (value > 0) {
      return absValue < 0.3 
          ? Colors.green[300]!
          : absValue < 0.7 
              ? Colors.green[600]!
              : Colors.green[900]!;
    } else {
      return absValue < 0.3
          ? Colors.red[300]!
          : absValue < 0.7
              ? Colors.red[600]!
              : Colors.red[900]!;
    }
  }
    /// Get a descriptive text for a correlation value
  String _getCorrelationText(double value) {
    final absValue = value.abs();
    if (absValue < 0.1) {
      return 'No correlation';
    } else if (absValue < 0.3) {
      return 'Weak ${value > 0 ? 'positive' : 'negative'}';
    } else if (absValue < 0.5) {
      return 'Moderate ${value > 0 ? 'positive' : 'negative'}';
    } else if (absValue < 0.7) {
      return 'Strong ${value > 0 ? 'positive' : 'negative'}';
    } else {
      return 'Very strong ${value > 0 ? 'positive' : 'negative'}';
    }
  }
  
  /// Get an icon for an insight category
  IconData _getInsightIcon(String factor) {
    switch (factor) {
      case 'Temperature':
        return Icons.thermostat;
      case 'Humidity':
        return Icons.water_drop;
      case 'Wind Speed':
        return Icons.air;
      case 'Time of Day':
        return Icons.access_time;
      case 'Hive Weight':
        return Icons.scale;
      default:
        return Icons.info_outline;
    }
  }
}
