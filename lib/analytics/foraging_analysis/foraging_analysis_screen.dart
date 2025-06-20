import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/bee_counter/bee_count_database.dart';
import 'package:farmer_app/Services/weather_service.dart';
import 'foraging_analysis_engine.dart';

class ForagingAnalysisScreen extends StatefulWidget {
  final String? hiveId;

  const ForagingAnalysisScreen({Key? key, this.hiveId}) : super(key: key);

  @override
  State<ForagingAnalysisScreen> createState() => _ForagingAnalysisScreenState();
}

class _ForagingAnalysisScreenState extends State<ForagingAnalysisScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic> _analysisResults = {};
  List<BeeCount> _beeCounterResults = [];
  Map<String, dynamic> _weatherData = {};

  late TabController _tabController;

  // Date range for analysis - MODIFIED to default to last 7 days
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  // Define theme colors for consistent UI
  final Color _primaryColor = Color(0xFF4CAF50);
  final Color _secondaryColor = Color(0xFFFFB74D);
  final Color _backgroundColor = Color(0xFFF5F5F5);
  final Color _cardColor = Colors.white;
  final Color _textColor = Color(0xFF424242);
  final Color _accentColor = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // Load bee counter data from local database
      _beeCounterResults = await _fetchBeeCounterData();

      if (_beeCounterResults.isEmpty) {
        // Try to fetch the most recent data instead of showing an error
        _beeCounterResults = await _fetchMostRecentBeeCounterData();

        if (_beeCounterResults.isEmpty) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage =
                'No bee counter data available for analysis. Please record some bee activity videos first.';
          });
          return;
        } else {
          // Update date range to match the found data
          DateTime oldestDate = _beeCounterResults
              .map((e) => e.timestamp)
              .reduce((a, b) => a.isBefore(b) ? a : b);
          DateTime newestDate = _beeCounterResults
              .map((e) => e.timestamp)
              .reduce((a, b) => a.isAfter(b) ? a : b);

          setState(() {
            _dateRange = DateTimeRange(
              start: DateTime(
                oldestDate.year,
                oldestDate.month,
                oldestDate.day,
              ),
              end: DateTime(newestDate.year, newestDate.month, newestDate.day),
            );
          });
        }
      }

      // Get weather data
      try {
        _weatherData = await WeatherService.getCurrentWeather();
      } catch (e) {
        print('Error loading weather data: $e');
        // Continue without weather data
        _weatherData = {};
      }

      // Process data with foraging analysis engine
      _analysisResults = await ForagingAnalysisEngine.analyzeForagingResults(
        _beeCounterResults,
        startDate: _dateRange.start,
        endDate: _dateRange.end,
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading foraging analysis data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error analyzing foraging data: ${e.toString()}';
      });
    }
  }

  // Fetch most recent bee counter data from local database
  Future<List<BeeCount>> _fetchMostRecentBeeCounterData() async {
    try {
      List<BeeCount> results = [];

      if (widget.hiveId != null) {
        // Get data for specific hive
        results = await BeeCountDatabase.instance.getBeeCountsForHive(
          widget.hiveId!,
        );
      } else {
        // Get all data
        results = await BeeCountDatabase.instance.getAllBeeCounts();
      }

      if (results.isEmpty) {
        return [];
      }

      // Sort by timestamp (newest first)
      results.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Get the date of the most recent record
      DateTime mostRecentDate = DateTime(
        results.first.timestamp.year,
        results.first.timestamp.month,
        results.first.timestamp.day,
      );

      // Filter to include only records from the most recent day with data
      results =
          results.where((result) {
            DateTime recordDate = DateTime(
              result.timestamp.year,
              result.timestamp.month,
              result.timestamp.day,
            );
            return recordDate.isAtSameMomentAs(mostRecentDate);
          }).toList();

      return results;
    } catch (e) {
      print('Error fetching most recent bee counter data: $e');
      return [];
    }
  }

  // Fetch bee counter data from local database
  Future<List<BeeCount>> _fetchBeeCounterData() async {
    try {
      List<BeeCount> results = [];

      if (widget.hiveId != null) {
        // Get data for specific hive
        results = await BeeCountDatabase.instance.getBeeCountsForHive(
          widget.hiveId!,
        );
      } else {
        // Get all data
        results = await BeeCountDatabase.instance.getAllBeeCounts();
      }

      // Filter by date range
      results =
          results.where((result) {
            return result.timestamp.isAfter(_dateRange.start) &&
                result.timestamp.isBefore(
                  _dateRange.end.add(Duration(days: 1)),
                );
          }).toList();

      return results;
    } catch (e) {
      print('Error fetching bee counter data: $e');
      return [];
    }
  }

  Future<void> _selectDateRange() async {
    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (newDateRange != null) {
      setState(() {
        _dateRange = newDateRange;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foraging Analysis'),
        backgroundColor: _primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Patterns'),
            Tab(text: 'Time Analysis'),
            Tab(text: 'Recommendations'),
          ],
        ),
      ),
      backgroundColor: _backgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
            )
          : _hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: Icon(Icons.refresh),
                          label: Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildPatternsTab(),
                    _buildTimeAnalysisTab(),
                    _buildRecommendationsTab(),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab() {
    if (!_analysisResults.containsKey('hasData') ||
        !_analysisResults['hasData']) {
      return _buildNoDataView();
    }

    final metrics = _analysisResults['metrics'];
    final efficiency = _analysisResults['efficiency'];
    final forageScore = _analysisResults['foragePerformanceScore'];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRangeCard(),
          SizedBox(height: 24), // Increased spacing
          _buildForagingScoreCard(forageScore),
          SizedBox(height: 24), // Increased spacing
          _buildKeyMetricsCard(metrics),
          SizedBox(height: 24), // Increased spacing
          _buildEfficiencyCard(efficiency),
          SizedBox(height: 24), // Increased spacing
          _buildWeatherImpactCard(),
          SizedBox(height: 24), // Increased spacing
          _buildActivityChartCard(),
          SizedBox(height: 32), // Extra bottom padding
        ],
      ),
    );
  }

  Widget _buildPatternsTab() {
    if (!_analysisResults.containsKey('hasData') ||
        !_analysisResults['hasData']) {
      return _buildNoDataView();
    }

    final patterns = _analysisResults['patterns'];
    final distributions = _analysisResults['distributions'];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Foraging Patterns Analysis'),
          SizedBox(height: 16),
          _buildForagingPatternsCard(patterns),
          SizedBox(height: 24), // Increased spacing
          _buildSectionHeader('Time Distribution'),
          SizedBox(height: 16),
          _buildTimeDistributionCard(distributions),
          SizedBox(height: 24), // Increased spacing
          _buildSectionHeader('Day of Week Analysis'),
          SizedBox(height: 16),
          _buildDayOfWeekDistributionCard(distributions),
          SizedBox(height: 24), // Increased spacing
          _buildSectionHeader('Hourly Activity Flux'),
          SizedBox(height: 16),
          _buildHourlyFluxCard(),
          SizedBox(height: 32), // Extra bottom padding
        ],
      ),
    );
  }

  // Improved time-based analysis tab
  Widget _buildTimeAnalysisTab() {
    if (!_analysisResults.containsKey('hasData') ||
        !_analysisResults['hasData'] ||
        !_analysisResults.containsKey('timeBasedAnalysis')) {
      return _buildNoDataView();
    }

    final timeBasedAnalysis = _analysisResults['timeBasedAnalysis'];

    if (!timeBasedAnalysis.containsKey('hasData') ||
        !timeBasedAnalysis['hasData']) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'No time-based analysis data available',
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'More bee activity data is needed for time-based analysis',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Return Rate Analysis'),
          SizedBox(height: 16),
          _buildReturnRateByTimeCard(timeBasedAnalysis),
          SizedBox(height: 24), // Increased spacing
          _buildSectionHeader('Trip Duration Distribution'),
          SizedBox(height: 16),
          _buildTripDurationDistributionCard(timeBasedAnalysis),
          SizedBox(height: 24), // Increased spacing
          _buildSectionHeader('Daily Time Comparison'),
          SizedBox(height: 16),
          _buildDailyTimeComparisonCard(timeBasedAnalysis),
          SizedBox(height: 24), // Increased spacing
          _buildSectionHeader('Time-Based Health Assessment'),
          SizedBox(height: 16),
          _buildTimeBasedHealthCard(timeBasedAnalysis),
          SizedBox(height: 32), // Extra bottom padding
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    if (!_analysisResults.containsKey('hasData') ||
        !_analysisResults['hasData']) {
      return _buildNoDataView();
    }
  
    // Fix the type casting issue
    List<Map<String, dynamic>> recommendations = [];
    
    // Check if recommendations exists and handle different possible types
    if (_analysisResults.containsKey('recommendations')) {
      var rawRecommendations = _analysisResults['recommendations'];
      
      if (rawRecommendations is List) {
        // If it's already a list, convert each item to Map<String, dynamic>
        recommendations = List<Map<String, dynamic>>.from(
          rawRecommendations.map((item) => 
            item is Map<String, dynamic> ? item : <String, dynamic>{}
          )
        );
      } else if (rawRecommendations is Map) {
        // If it's a map, convert it to a list with a single item
        recommendations = [Map<String, dynamic>.from(rawRecommendations)];
      }
    }
  
    final environmentalFactors = _analysisResults.containsKey('environmentalFactors') 
        ? _analysisResults['environmentalFactors'] 
        : <String, dynamic>{};
  
    // Add this at the beginning of _buildRecommendationsTab()#
    print("Recommendations data: ${_analysisResults['recommendations']}");
    print("Environmental factors: ${_analysisResults['environmentalFactors']}");
  
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Recommendations'),
          SizedBox(height: 16),
          recommendations.isNotEmpty 
              ? _buildRecommendationsCard(recommendations)
              : Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No recommendations available for this time period.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                  ),
                ),
          SizedBox(height: 24),
          _buildSectionHeader('Environmental Insights'),
          SizedBox(height: 16),
          _buildEnvironmentalInsightsCard(environmentalFactors),
          SizedBox(height: 24),
          _buildSectionHeader('Optimal Foraging Conditions'),
          SizedBox(height: 16),
          _buildOptimalConditionsCard(environmentalFactors),
          SizedBox(height: 32),
        ],
      ),
    );
  }

  // New section header widget for better visual separation
  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics, color: _primaryColor, size: 20),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // Improved time-based analysis cards
  Widget _buildReturnRateByTimeCard(Map<String, dynamic> timeBasedAnalysis) {
    if (!timeBasedAnalysis.containsKey('dailyReturnRates') ||
        timeBasedAnalysis['dailyReturnRates'].isEmpty) {
      return SizedBox();
    }

    // Get the most recent day's data
    final dailyRates = timeBasedAnalysis['dailyReturnRates'];
    final latestDay = dailyRates.keys.toList().last;
    final latestData = dailyRates[latestDay];

    if (!latestData.containsKey('timeBlocks') ||
        latestData['timeBlocks'].isEmpty) {
      return SizedBox();
    }

    final timeBlocks = latestData['timeBlocks'];

    // Prepare data for the chart
    List<BarChartGroupData> barGroups = [];
    List<String> timeLabels = [];
    int index = 0;

    timeBlocks.forEach((blockName, data) {
      if (data.containsKey('actualReturnRate') &&
          data.containsKey('expectedReturnRate')) {
        double actual = data['actualReturnRate'];
        double expected = data['expectedReturnRate'];

        barGroups.add(
          BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: actual,
                color: _getReturnRateColor(actual, expected),
                width: 16,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: expected,
                color: Colors.grey[400],
                width: 16,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          ),
        );

        timeLabels.add(_formatTimeBlockName(blockName));
        index++;
      }
    });

    return Card(
      elevation: 4, // Increased elevation for better shadow
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Return Rate by Time of Day',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Data for ${_formatDate(DateTime.parse(latestDay))}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              height: 250,
              padding: EdgeInsets.only(top: 16, right: 16), // Added padding for chart
              decoration: BoxDecoration(
                color: Colors.grey[50], // Light background for chart area
                borderRadius: BorderRadius.circular(8),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 110, // Allow some space above 100%
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String label = rodIndex == 0 ? 'Actual' : 'Expected';
                        return BarTooltipItem(
                          '$label: ${rod.toY.toStringAsFixed(1)}%',
                          TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value >= timeLabels.length) return SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              timeLabels[value.toInt()],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              '${value.toInt()}%',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color:
                            value == 100 ? Colors.red[200]! : Colors.grey[300]!,
                        strokeWidth: value == 100 ? 1.5 : 1,
                        dashArray: value == 100 ? [5, 5] : null,
                      );
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('Actual', Colors.green),
                  SizedBox(width: 24),
                  _buildLegendItem('Expected', Colors.grey[400]!),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'This chart compares actual return rates with expected rates based on scientific research on bee foraging behavior. Significant differences may indicate environmental challenges or colony health issues.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripDurationDistributionCard(
    Map<String, dynamic> timeBasedAnalysis,
  ) {
    if (!timeBasedAnalysis.containsKey('tripDistributionPercentages') ||
        timeBasedAnalysis['tripDistributionPercentages'].isEmpty) {
      return SizedBox();
    }

    final distribution = timeBasedAnalysis['tripDistributionPercentages'];
    final avgReturnTimes = timeBasedAnalysis['avgReturnTimes'];

    // Prepare data for the pie chart
    List<PieChartSectionData> sections = [];

    if (distribution.containsKey('short')) {
      sections.add(
        PieChartSectionData(
          value: distribution['short'],
          title: '${distribution['short'].toStringAsFixed(1)}%',
          color: Colors.blue,
          radius: 100,
          titleStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    if (distribution.containsKey('medium')) {
      sections.add(
        PieChartSectionData(
          value: distribution['medium'],
          title: '${distribution['medium'].toStringAsFixed(1)}%',
          color: Colors.green,
          radius: 100,
          titleStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    if (distribution.containsKey('long')) {
      sections.add(
        PieChartSectionData(
          value: distribution['long'],
          title: '${distribution['long'].toStringAsFixed(1)}%',
          color: Colors.orange,
          radius: 100,
          titleStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    return Card(
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foraging Trip Duration Distribution',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              height: 220,
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50], // Light background for chart area
                borderRadius: BorderRadius.circular(8),
              ),
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDurationLegendItem(
                    'Short',
                    'Under 30 min',
                    Colors.blue,
                    avgReturnTimes.containsKey('short')
                        ? '${avgReturnTimes['short'].toStringAsFixed(1)} min'
                        : 'N/A',
                  ),
                  _buildDurationLegendItem(
                    'Medium',
                    '30-90 min',
                    Colors.green,
                    avgReturnTimes.containsKey('medium')
                        ? '${avgReturnTimes['medium'].toStringAsFixed(1)} min'
                        : 'N/A',
                  ),
                  _buildDurationLegendItem(
                    'Long',
                    'Over 90 min',
                    Colors.orange,
                    avgReturnTimes.containsKey('long')
                        ? '${avgReturnTimes['long'].toStringAsFixed(1)} min'
                        : 'N/A',
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'This chart shows the distribution of foraging trip durations. A balanced distribution is typical for healthy colonies with good resource access.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTimeComparisonCard(Map<String, dynamic> timeBasedAnalysis) {
    if (!timeBasedAnalysis.containsKey('dailyReturnRates') ||
        timeBasedAnalysis['dailyReturnRates'].isEmpty) {
      return SizedBox();
    }

    final dailyRates = timeBasedAnalysis['dailyReturnRates'];

    // Prepare data for the chart
    List<String> days = dailyRates.keys.toList();
    // Sort days chronologically
    days.sort();

    // Limit to last 5 days to avoid overcrowding
    if (days.length > 5) {
      days = days.sublist(days.length - 5);
    }

    // Create line chart data for morning and afternoon return rates
    List<FlSpot> morningSpots = [];
    List<FlSpot> afternoonSpots = [];

    for (int i = 0; i < days.length; i++) {
      final dayData = dailyRates[days[i]];
      if (dayData.containsKey('timeBlocks')) {
        final timeBlocks = dayData['timeBlocks'];

        if (timeBlocks.containsKey('morning') &&
            timeBlocks['morning'].containsKey('actualReturnRate')) {
          morningSpots.add(
            FlSpot(i.toDouble(), timeBlocks['morning']['actualReturnRate']),
          );
        }

        if (timeBlocks.containsKey('afternoon') &&
            timeBlocks['afternoon'].containsKey('actualReturnRate')) {
          afternoonSpots.add(
            FlSpot(i.toDouble(), timeBlocks['afternoon']['actualReturnRate']),
          );
        }
      }
    }

    return Card(
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Return Rate Comparison by Time of Day',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              height: 250,
              padding: EdgeInsets.only(top: 16, right: 16), // Added padding for chart
              decoration: BoxDecoration(
                color: Colors.grey[50], // Light background for chart area
                borderRadius: BorderRadius.circular(8),
              ),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color:
                            value == 100 ? Colors.red[200]! : Colors.grey[300]!,
                        strokeWidth: value == 100 ? 1.5 : 1,
                        dashArray: value == 100 ? [5, 5] : null,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value >= days.length || value < 0)
                            return SizedBox();

                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _formatShortDate(
                                DateTime.parse(days[value.toInt()]),
                              ),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              '${value.toInt()}%',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                      left: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: morningSpots,
                      isCurved: true,
                      color: Colors.amber,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.amber.withOpacity(0.2),
                      ),
                    ),
                    LineChartBarData(
                      spots: afternoonSpots,
                      isCurved: true,
                      color: Colors.deepPurple,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.deepPurple.withOpacity(0.2),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: 110,
                ),
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('Morning', Colors.amber),
                  SizedBox(width: 24),
                  _buildLegendItem('Afternoon', Colors.deepPurple),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'This chart compares morning and afternoon return rates over time. Consistent patterns indicate stable foraging conditions, while significant variations may suggest changing environmental factors.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBasedHealthCard(Map<String, dynamic> timeBasedAnalysis) {
    if (!timeBasedAnalysis.containsKey('overallHealthScore')) {
      return SizedBox();
    }

    final healthScore = timeBasedAnalysis['overallHealthScore'];

    Color healthColor;
    String healthLabel;

    if (healthScore >= 80) {
      healthColor = Colors.green;
      healthLabel = 'Excellent';
    } else if (healthScore >= 70) {
      healthColor = Colors.lightGreen;
      healthLabel = 'Good';
    } else if (healthScore >= 60) {
      healthColor = Colors.amber;
      healthLabel = 'Fair';
    } else {
      healthColor = Colors.orange;
      healthLabel = 'Needs Improvement';
    }

    return Card(
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time-Based Foraging Health',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[200],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: healthScore / 100,
                                strokeWidth: 10,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  healthColor,
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    healthScore.toStringAsFixed(0),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: healthColor,
                                    ),
                                  ),
                                  Text(
                                    healthLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: healthColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Time-Based Health Score',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHealthFactor(
                          'Return Rate Consistency',
                          _getConsistencyRating(timeBasedAnalysis),
                        ),
                        SizedBox(height: 12),
                        _buildHealthFactor(
                          'Trip Duration Optimality',
                          _getTripDurationRating(timeBasedAnalysis),
                        ),
                        SizedBox(height: 12),
                        _buildHealthFactor(
                          'Time Pattern Stability',
                          _getPatternStabilityRating(timeBasedAnalysis),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'This score evaluates foraging health based on time-specific patterns. It considers return rates at different times of day, trip duration distributions, and pattern stability over time.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No foraging data available for analysis',
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Record some bee activity videos using the Bee Video Analysis tool to generate foraging insights',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/bee_video_analysis');
              },
              icon: Icon(Icons.videocam),
              label: Text('Record Bee Activity'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.date_range, color: _primaryColor),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analysis Period',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${DateFormat('MMM d, yyyy').format(_dateRange.start)} - ${DateFormat('MMM d, yyyy').format(_dateRange.end)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _selectDateRange,
              child: Text('Change'),
              style: TextButton.styleFrom(foregroundColor: _primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForagingScoreCard(double score) {
    Color scoreColor;
    String scoreLabel;

    if (score >= 80) {
      scoreColor = Colors.green;
      scoreLabel = 'Excellent';
    } else if (score >= 70) {
      scoreColor = Colors.lightGreen;
      scoreLabel = 'Good';
    } else if (score >= 60) {
      scoreColor = Colors.amber;
      scoreLabel = 'Fair';
    } else {
      scoreColor = Colors.orange;
      scoreLabel = 'Needs Improvement';
    }

    return Card(
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foraging Performance',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: score / 100,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              score.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: scoreColor,
                              ),
                            ),
                            Text(
                              scoreLabel,
                              style: TextStyle(fontSize: 14, color: scoreColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'This score represents the overall foraging performance of your hive, based on bee activity, return rates, and environmental factors.',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetricsCard(Map<String, dynamic> metrics) {
    return Card(
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Key Metrics',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricItem(
                          'Bees In',
                          metrics['totalBeesIn'].toString(),
                          'Total count',
                          Icons.login,
                          Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _buildMetricItem(
                          'Bees Out',
                          metrics['totalBeesOut'].toString(),
                          'Total count',
                          Icons.logout,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20), // Increased spacing
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricItem(
                          'Return Rate',
                          '${metrics['returnRate'].toStringAsFixed(1)}%',
                          'Bees returning',
                          Icons.loop,
                          _getReturnRateColor(metrics['returnRate'], 95.0),
                        ),
                      ),
                      Expanded(
                        child: _buildMetricItem(
                          'Trip Duration',
                          '${metrics['estimatedForagingDuration'].toStringAsFixed(0)} min',
                          'Average time',
                          Icons.timer,
                          _getTripDurationColor(metrics['estimatedForagingDuration']),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20), // Increased spacing
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricItem(
                          'Peak Activity',
                          '${metrics['peakActivityHour']}:00',
                          'Busiest hour',
                          Icons.show_chart,
                          Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _buildMetricItem(
                          'Net Change',
                          metrics['totalNetChange'].toString(),
                          'Population change',
                          Icons.people,
                          metrics['totalNetChange'] >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Divider(),
            SizedBox(height: 12),
            Text(
              'Daily Averages',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Daily In',
                      metrics['avgDailyBeesIn'].toStringAsFixed(0),
                      'Average per day',
                      Icons.login,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Daily Out',
                      metrics['avgDailyBeesOut'].toStringAsFixed(0),
                      'Average per day',
                      Icons.logout,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildEfficiencyCard(Map<String, dynamic> efficiency) {
    if (efficiency == null) {
       return SizedBox(); 
     }
   
     // Check if the required keys exist
     final efficiencyScore = efficiency.containsKey('efficiencyScore') ? efficiency['efficiencyScore'] : 0.0;
     final benchmarkComparison = efficiency.containsKey('benchmarkComparison') ? efficiency['benchmarkComparison'] : {};
   
     // Check if benchmarkComparison contains the required keys
     if (!benchmarkComparison.containsKey('efficiencyScore') ||
         !benchmarkComparison.containsKey('returnRate') ||
         !benchmarkComparison.containsKey('foragingDuration') ||
         !benchmarkComparison.containsKey('entryExitImbalance')) {
       return Card(
         elevation: 4,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
         child: Padding(
           padding: EdgeInsets.all(20),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(
                 'Foraging Efficiency',
                 style: TextStyle(
                   fontSize: 18, 
                   fontWeight: FontWeight.bold,
                   color: _textColor,
                 ),
               ),
               SizedBox(height: 20),
               Center(
                 child: Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Text(
                     'Insufficient data to calculate efficiency metrics',
                     style: TextStyle(
                       fontSize: 14,
                       color: Colors.grey[600],
                       fontStyle: FontStyle.italic,
                     ),
                   ),
                 ),
               ),
             ],
           ),
         ),
       );
     }
    Color efficiencyColor;
    if (efficiencyScore >= 80) {
      efficiencyColor = Colors.green;
    } else if (efficiencyScore >= 70) {
      efficiencyColor = Colors.lightGreen;
    } else if (efficiencyScore >= 60) {
      efficiencyColor = Colors.amber;
    } else {
      efficiencyColor = Colors.orange;
    }

    return Card(
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foraging Efficiency',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[200],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: efficiencyScore / 100,
                                strokeWidth: 10,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  efficiencyColor,
                                ),
                              ),
                              Text(
                                efficiencyScore.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: efficiencyColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Efficiency Score',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          benchmarkComparison['efficiencyScore']['performance'],
                          style: TextStyle(
                            fontSize: 12,
                            color: efficiencyColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildEfficiencyMetric(
                          'Return Rate',
                          benchmarkComparison['returnRate']['value']
                              .toStringAsFixed(1),
                          benchmarkComparison['returnRate']['benchmark']
                              .toStringAsFixed(1),
                          benchmarkComparison['returnRate']['performance'],
                          '%',
                        ),
                        SizedBox(height: 12),
                        _buildEfficiencyMetric(
                          'Trip Duration',
                          benchmarkComparison['foragingDuration']['value']
                              .toStringAsFixed(0),
                          benchmarkComparison['foragingDuration']['benchmark']
                              .toStringAsFixed(0),
                          benchmarkComparison['foragingDuration']['performance'],
                          'min',
                        ),
                        SizedBox(height: 12),
                        _buildEfficiencyMetric(
                          'Entry/Exit Balance',
                          benchmarkComparison['entryExitImbalance']['value']
                              .toStringAsFixed(1),
                          benchmarkComparison['entryExitImbalance']['benchmark']
                              .toStringAsFixed(1),
                          benchmarkComparison['entryExitImbalance']['performance'],
                          '%',
                          lowerIsBetter: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Divider(),
            SizedBox(height: 12),
            Text(
              'Limiting Factors',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildLimitingFactorsList(efficiency['limitingFactors']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEfficiencyMetric(
    String label,
    String value,
    String benchmark,
    String performance,
    String unit, {
    bool lowerIsBetter = false,
  }) {
    Color performanceColor;
    switch (performance) {
      case 'Excellent':
      case 'Optimal':
      case 'Above Average':
      case 'Good':
        performanceColor = Colors.green;
        break;
      case 'Average':
        performanceColor = Colors.lightGreen;
        break;
      case 'Fair':
      case 'Below Average':
      case 'Below Optimal':
        performanceColor = Colors.amber;
        break;
      default:
        performanceColor = Colors.orange;
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                'Benchmark: $benchmark$unit',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$value$unit',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: performanceColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  performance,
                  style: TextStyle(
                    fontSize: 12,
                    color: performanceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLimitingFactorsList(List<Map<String, dynamic>> limitingFactors) {
    if (limitingFactors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'No significant limiting factors detected',
          style: TextStyle(
            fontSize: 14,
            color: Colors.green,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      children:
          limitingFactors.map((factor) {
            Color severityColor =
                factor['severity'] == 'High'
                    ? Colors.red
                    : (factor['severity'] == 'Medium'
                        ? Colors.orange
                        : Colors.amber);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0), // Increased spacing
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 2),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: severityColor,
                    ),
                  ),
                  SizedBox(width: 12), // Increased spacing
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${factor['factor']} (${factor['severity']} Impact)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          factor['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildWeatherImpactCard() {
    if (!_analysisResults.containsKey('environmentalFactors') ||
        !_analysisResults['environmentalFactors'].containsKey(
          'environmentalInsights',
        )) {
      return SizedBox();
    }

    final environmentalFactors = _analysisResults['environmentalFactors'];
    final environmentalInsights = environmentalFactors['environmentalInsights'];
    final mostInfluentialFactor =
        environmentalFactors['mostInfluentialFactor'] ?? 'temperature';

    if (environmentalInsights.isEmpty) {
      return SizedBox();
    }

    // Get current weather if available
    String currentTemp = 'N/A';
    String currentCondition = 'Unknown';
    String weatherIconUrl = '';

    if (_weatherData.isNotEmpty &&
        _weatherData.containsKey('current') &&
        _weatherData['current'] != null) {
      var current = _weatherData['current'];
      if (current.containsKey('temperature')) {
        currentTemp = '${current['temperature'].toStringAsFixed(1)}°C';
      }
      if (current.containsKey('condition') &&
          current['condition'].containsKey('text')) {
        currentCondition = current['condition']['text'];
      }
      if (current.containsKey('condition') &&
          current['condition'].containsKey('icon')) {
        weatherIconUrl = current['condition']['icon'];
      }
    }

    return Card(
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weather Impact',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        weatherIconUrl.isNotEmpty
                            ? Image.network(
                              weatherIconUrl,
                              width: 64,
                              height: 64,
                              errorBuilder:
                                  (context, error, stackTrace) => Icon(
                                    Icons.wb_sunny,
                                    size: 48,
                                    color: Colors.amber,
                                  ),
                            )
                            : Icon(Icons.wb_sunny, size: 48, color: Colors.amber),
                        SizedBox(height: 8),
                        Text(
                          currentTemp,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          currentCondition,
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Most Influential Factor:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatWeatherFactor(mostInfluentialFactor),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          environmentalInsights[mostInfluentialFactor] ??
                              'No specific insights available.',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Divider(),
            SizedBox(height: 12),
            Text(
              'Environmental Insights',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildEnvironmentalInsightsList(environmentalInsights),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentalInsightsList(
    Map<String, String> environmentalInsights,
  ) {
    // Get the most influential factor from the parent data
    String mostInfluentialFactor =
        _analysisResults['environmentalFactors']['mostInfluentialFactor'] ?? '';

    List<MapEntry<String, String>> insights =
        environmentalInsights.entries
            .where((entry) => entry.key != mostInfluentialFactor)
            .toList();

    if (insights.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'No additional environmental insights available',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      children:
          insights.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0), // Increased spacing
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 2),
                    child: Icon(
                      _getWeatherIcon(entry.key),
                      size: 16,
                      color: Colors.blue[700],
                    ),
                  ),
                  SizedBox(width: 12), // Increased spacing
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatWeatherFactor(entry.key),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          entry.value,
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  IconData _getWeatherIcon(String factor) {
    switch (factor) {
      case 'temperature':
        return Icons.thermostat;
      case 'humidity':
        return Icons.water_drop;
      case 'windSpeed':
        return Icons.air;
      case 'precipitation':
        return Icons.umbrella;
      default:
        return Icons.wb_sunny;
    }
  }

  String _formatWeatherFactor(String factor) {
    switch (factor) {
      case 'temperature':
        return 'Temperature';
      case 'humidity':
        return 'Humidity';
      case 'windSpeed':
        return 'Wind Speed';
      case 'precipitation':
        return 'Precipitation';
      default:
        return factor.substring(0, 1).toUpperCase() + factor.substring(1);
    }
  }

  Widget _buildActivityChartCard() {
    if (!_analysisResults.containsKey('metrics') ||
        !_analysisResults['metrics'].containsKey('activityByHour')) {
      return SizedBox();
    }

    final metrics = _analysisResults['metrics'];
    final activityByHour = metrics['activityByHour'];

    // Convert string keys to int and sort
    List<MapEntry<int, dynamic>> sortedActivity = [];
    activityByHour.forEach((key, value) {
      int hour = int.tryParse(key) ?? 0;
      sortedActivity.add(MapEntry(hour, value));
    });
    sortedActivity.sort((a, b) => a.key.compareTo(b.key));

    // Filter to daylight hours (5 AM to 9 PM)
    sortedActivity =
        sortedActivity.where((entry) => entry.key >= 5 && entry.key <= 21)
            .toList();

    // Prepare data for the chart
    List<BarChartGroupData> barGroups = [];
    int maxActivity = 0;

    for (int i = 0; i < sortedActivity.length; i++) {
      int hour = sortedActivity[i].key;
      int activity = 0;

      if (sortedActivity[i].value is int) {
        activity = sortedActivity[i].value;
      } else if (sortedActivity[i].value is double) {
        activity = sortedActivity[i].value.toInt();
      } else if (sortedActivity[i].value is String) {
        activity = int.tryParse(sortedActivity[i].value) ?? 0;
      }

      if (activity > maxActivity) {
        maxActivity = activity;
      }

      Color barColor =
          hour == metrics['peakActivityHour']
              ? Colors.amber
              : _primaryColor;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: activity.toDouble(),
              color: barColor,
              width: 16,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hourly Activity',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              height: 250,
              padding: EdgeInsets.only(top: 16, right: 16), // Added padding for chart
              decoration: BoxDecoration(
                color: Colors.grey[50], // Light background for chart area
                borderRadius: BorderRadius.circular(8),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxActivity * 1.1, // Add 10% margin at the top
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        int hour = sortedActivity[group.x.toInt()].key;
                        String timeLabel =
                            hour < 12
                                ? '$hour AM'
                                : (hour == 12 ? '12 PM' : '${hour - 12} PM');
                        return BarTooltipItem(
                          '$timeLabel: ${rod.toY.toInt()} bees',
                          TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value >= sortedActivity.length) return SizedBox();
                          int hour = sortedActivity[value.toInt()].key;
                          // Only show every other hour to avoid crowding
                          if (hour % 3 != 0) return SizedBox();
                          String timeLabel =
                              hour < 12
                                  ? '$hour AM'
                                  : (hour == 12 ? '12 PM' : '${hour - 12} PM');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              timeLabel,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('Regular Activity', _primaryColor),
                  SizedBox(width: 24),
                  _buildLegendItem('Peak Hour', Colors.amber),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'This chart shows bee activity throughout the day. The peak hour (${metrics['peakActivityHour'] < 12 ? metrics['peakActivityHour'].toString() + ' AM' : (metrics['peakActivityHour'] == 12 ? '12 PM' : (metrics['peakActivityHour'] - 12).toString() + ' PM')}) is highlighted in amber.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForagingPatternsCard(Map<String, dynamic> patterns) {
    // Add null checks for all values
    final primaryForagingPeriod = patterns['primaryForagingPeriod']?.toString() ?? 'Unknown';
    final morningActivityPercentage = patterns['morningActivityPercentage'] ?? 0.0;
    final afternoonActivityPercentage = patterns['afternoonActivityPercentage'] ?? 0.0;
    final patternConsistency = patterns['patternConsistency'] ?? 0.0;
    final suspectedWeatherDependency = patterns['suspectedWeatherDependency'] ?? false;
    final hasBimodalPattern = patterns['hasBimodalPattern'] ?? false;
    final possibleSwarmingBehavior = patterns['possibleSwarmingBehavior'] ?? false;
    final peakActivityHours = patterns['peakActivityHours'] ?? [];
  
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foraging Patterns',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildPatternItem(
                    'Primary Foraging Period',
                    primaryForagingPeriod,
                    Icons.wb_twilight,
                    Colors.amber,
                  ),
                  Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPercentageItem(
                          'Morning Activity',
                          morningActivityPercentage,
                          Colors.amber[300]!,
                        ),
                      ),
                      Expanded(
                        child: _buildPercentageItem(
                          'Afternoon Activity',
                          afternoonActivityPercentage,
                          Colors.amber[700]!,
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 24),
                  _buildPatternItem(
                    'Pattern Consistency',
                    '${patternConsistency.toStringAsFixed(1)}%',
                    Icons.repeat,
                    _getConsistencyColor(patternConsistency),
                    subtitle: _getConsistencyLabel(patternConsistency),
                  ),
                  Divider(height: 24),
                  _buildPatternItem(
                    'Weather Dependency',
                    suspectedWeatherDependency ? 'High' : 'Low',
                    Icons.wb_cloudy,
                    suspectedWeatherDependency ? Colors.orange : Colors.green,
                  ),
                  Divider(height: 24),
                  _buildPatternItem(
                    'Bimodal Pattern',
                    hasBimodalPattern ? 'Present' : 'Not Present',
                    Icons.show_chart,
                    hasBimodalPattern ? Colors.blue : Colors.grey,
                    subtitle: hasBimodalPattern
                        ? 'Two distinct activity peaks'
                        : 'Single activity peak pattern',
                  ),
                  if (hasBimodalPattern && peakActivityHours is List && peakActivityHours.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 32.0, top: 8.0),
                      child: Text(
                        'Peak hours: ${peakActivityHours.map((hour) {
                          final h = hour is int ? hour : 0;
                          return h < 12 ? '$h AM' : (h == 12 ? '12 PM' : '${h - 12} PM');
                        }).join(', ')}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ),
                  Divider(height: 24),
                  _buildPatternItem(
                    'Swarming Behavior',
                    possibleSwarmingBehavior ? 'Possible' : 'Not Detected',
                    Icons.warning_amber,
                    possibleSwarmingBehavior ? Colors.red : Colors.green,
                    subtitle: possibleSwarmingBehavior
                        ? 'Unusual outbound activity detected'
                        : 'Normal outbound/inbound ratio',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternItem(
    String label,
    String? value,  // Change to accept nullable String
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    // Provide a default value if null
    final displayValue = value ?? 'N/A';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              displayValue,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageItem(String label, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            height: 8,
            width: 100,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.bold,
            ),
                   ),
        ],
      ),
    );
  }

  Widget _buildTimeDistributionCard(Map<String, dynamic> distributions) {
    if (!distributions.containsKey('timeBlockDistribution')) {
      return SizedBox();
    }

    final timeBlockDistribution = distributions['timeBlockDistribution'];
    List<MapEntry<String, double>> sortedBlocks =
        timeBlockDistribution.entries.toList();

    // Sort by time of day
    sortedBlocks.sort((a, b) {
      // Extract the hour range from the label
      int aStart = int.tryParse(a.key.split('(')[1].split('-')[0]) ?? 0;
      int bStart = int.tryParse(b.key.split('(')[1].split('-')[0]) ?? 0;
      return aStart.compareTo(bStart);
    });

    // Prepare data for the chart
    List<PieChartSectionData> sections = [];
    List<Color> blockColors = [
      Colors.lightBlue[300]!,
      Colors.amber[300]!,
      Colors.orange[300]!,
      Colors.deepOrange[300]!,
      Colors.purple[300]!,
    ];

    for (int i = 0; i < sortedBlocks.length; i++) {
      sections.add(
        PieChartSectionData(
          value: sortedBlocks[i].value,
          title: '${sortedBlocks[i].value.toStringAsFixed(0)}%',
          color: blockColors[i % blockColors.length],
          radius: 100,
          titleStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    return Card(
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Distribution by Time',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              height: 220,
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50], // Light background for chart area
                borderRadius: BorderRadius.circular(8),
              ),
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: List.generate(
                  sortedBlocks.length,
                  (index) => _buildColorLegendItem(
                    sortedBlocks[index].key,
                    blockColors[index % blockColors.length],
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'This chart shows how bee activity is distributed throughout the day. The percentages represent the proportion of total activity occurring during each time block.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayOfWeekDistributionCard(Map<String, dynamic> distributions) {
    if (!distributions.containsKey('dayOfWeekDistribution')) {
      return SizedBox();
    }

    final dayOfWeekDistribution = distributions['dayOfWeekDistribution'];
    List<String> daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    // Calculate total activity for each day
    Map<String, int> totalActivityByDay = {};
    int maxActivity = 0;

    daysOfWeek.forEach((day) {
      if (dayOfWeekDistribution.containsKey(day)) {
        int in_ = dayOfWeekDistribution[day]['in'] ?? 0;
        int out_ = dayOfWeekDistribution[day]['out'] ?? 0;
        int total = in_ + out_;
        totalActivityByDay[day] = total;
        if (total > maxActivity) {
          maxActivity = total;
        }
      } else {
        totalActivityByDay[day] = 0;
      }
    });

    // Prepare data for the chart
    List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < daysOfWeek.length; i++) {
      String day = daysOfWeek[i];
      int activity = totalActivityByDay[day] ?? 0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: activity.toDouble(),
              color: _primaryColor,
              width: 16,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity by Day of Week',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              height: 250,
              padding: EdgeInsets.only(top: 16, right: 16), // Added padding for chart
              decoration: BoxDecoration(
                color: Colors.grey[50], // Light background for chart area
                borderRadius: BorderRadius.circular(8),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxActivity * 1.1, // Add 10% margin at the top
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String day = daysOfWeek[group.x.toInt()];
                        return BarTooltipItem(
                          '$day: ${rod.toY.toInt()} bees',
                          TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value >= daysOfWeek.length) return SizedBox();
                          String day = daysOfWeek[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              day.substring(0, 3), // First 3 letters of day
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'This chart shows bee activity by day of the week. Consistent patterns may indicate regular foraging behavior, while significant variations could suggest external factors affecting activity.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyFluxCard() {
    if (!_analysisResults.containsKey('metrics') ||
        !_analysisResults['metrics'].containsKey('hourlyFlux')) {
      return SizedBox();
    }

    final metrics = _analysisResults['metrics'];
    final hourlyFlux = metrics['hourlyFlux'];

    // Convert string keys to int and sort
    List<MapEntry<int, dynamic>> sortedFlux = [];
    hourlyFlux.forEach((key, value) {
      int hour = int.tryParse(key) ?? 0;
      sortedFlux.add(MapEntry(hour, value));
    });
    sortedFlux.sort((a, b) => a.key.compareTo(b.key));

    // Filter to daylight hours (5 AM to 9 PM)
    sortedFlux =
        sortedFlux.where((entry) => entry.key >= 5 && entry.key <= 21).toList();

    // Prepare data for the chart
    List<FlSpot> spots = [];
    double maxFlux = 0;
    double minFlux = 0;

    for (int i = 0; i < sortedFlux.length; i++) {
      int flux = 0;

      if (sortedFlux[i].value is int) {
        flux = sortedFlux[i].value;
      } else if (sortedFlux[i].value is double) {
        flux = sortedFlux[i].value.toInt();
      } else if (sortedFlux[i].value is String) {
        flux = int.tryParse(sortedFlux[i].value) ?? 0;
      }

      if (flux > maxFlux) {
        maxFlux = flux.toDouble();
      }
      if (flux < minFlux) {
        minFlux = flux.toDouble();
      }

      spots.add(FlSpot(i.toDouble(), flux.toDouble()));
    }

    // Ensure min and max have some padding
    maxFlux = maxFlux * 1.1;
    minFlux = minFlux * 1.1;

    return Card(
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hourly Population Flux',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Net change in bee population by hour',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              height: 250,
              padding: EdgeInsets.only(top: 16, right: 16), // Added padding for chart
              decoration: BoxDecoration(
                color: Colors.grey[50], // Light background for chart area
                borderRadius: BorderRadius.circular(8),
              ),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color:
                            value == 0 ? Colors.red[200]! : Colors.grey[300]!,
                        strokeWidth: value == 0 ? 1.5 : 1,
                        dashArray: value == 0 ? [5, 5] : null,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value >= sortedFlux.length) return SizedBox();
                          int hour = sortedFlux[value.toInt()].key;
                          // Only show every other hour to avoid crowding
                          if (hour % 3 != 0) return SizedBox();
                          String timeLabel =
                              hour < 12
                                  ? '$hour AM'
                                  : (hour == 12 ? '12 PM' : '${hour - 12} PM');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              timeLabel,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                      left: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: _accentColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _accentColor.withOpacity(0.2),
                      ),
                    ),
                  ],
                  minY: minFlux,
                  maxY: maxFlux,
                ),
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Positive Values',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'More bees entering than exiting',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Negative Values',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'More bees exiting than entering',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard(List<Map<String, dynamic>> recommendations) {
    if (recommendations.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No recommendations available for this time period.',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ),
      );
    }
  
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendations',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 20),
            ...recommendations.map((recommendation) {
              // Add null checks for all string values
              final priority = recommendation['priority']?.toString() ?? 'Medium';
              final category = recommendation['category']?.toString() ?? 'General';
              final title = recommendation['recommendation']?.toString() ?? 'No title';
              final details = recommendation['details']?.toString() ?? 'No details available';
              final actionItems = recommendation['actionItems'] ?? <dynamic>[];
              
              Color priorityColor;
              switch (priority) {
                case 'High':
                  priorityColor = Colors.red;
                  break;
                case 'Medium':
                  priorityColor = Colors.orange;
                  break;
                default:
                  priorityColor = Colors.green;
              }
  
              return Container(
                margin: EdgeInsets.only(bottom: 20),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: priorityColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            priority,
                            style: TextStyle(
                              fontSize: 12,
                              color: priorityColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      details,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 12),
                    if (actionItems is List && actionItems.isNotEmpty)
                      ...actionItems.map((action) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            left: 16.0,
                            top: 4.0,
                            bottom: 4.0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.arrow_right,
                                size: 16,
                                color: Colors.grey[700],
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  action?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimalConditionsCard(
    Map<String, dynamic> environmentalFactors,
  ) {
    if (!environmentalFactors.containsKey('optimalConditions') ||
        environmentalFactors['optimalConditions'].isEmpty) {
      return SizedBox();
    }

    final optimalConditions = environmentalFactors['optimalConditions'];

    return Card(
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Optimal Foraging Conditions',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 20), // Increased spacing
            ...optimalConditions.entries.map((entry) {
              final factor = entry.key;
              final conditions = entry.value;

              return Container(
                margin: EdgeInsets.only(bottom: 20), // Increased spacing between conditions
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 2),
                      child: Icon(
                        _getWeatherIcon(factor),
                        size: 20,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatWeatherFactor(factor),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12), // Increased spacing
                          _buildOptimalRangeIndicator(conditions),
                          SizedBox(height: 8),
                          Text(
                            _getOptimalConditionDescription(factor, conditions),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
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

  Widget _buildEnvironmentalInsightsCard(
  Map<String, dynamic> environmentalFactors,
) {
  if (!environmentalFactors.containsKey('environmentalInsights') ||
      environmentalFactors['environmentalInsights'].isEmpty) {
    return SizedBox();
  }

  final environmentalInsights = environmentalFactors['environmentalInsights'];

  return Card(
    elevation: 4, // Increased elevation
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: EdgeInsets.all(20), // Increased padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Environmental Insights',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          SizedBox(height: 20), // Increased spacing
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: environmentalInsights.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0), // Increased spacing
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 2),
                        child: Icon(
                          _getWeatherIcon(entry.key),
                          size: 20,
                          color: Colors.blue[700],
                        ),
                      ),
                      SizedBox(width: 12), // Increased spacing
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatWeatherFactor(entry.key),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              entry.value,
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildOptimalRangeIndicator(Map<String, dynamic> conditions) {
    double min = conditions.containsKey('min') ? conditions['min'] : 0;
    double max = conditions.containsKey('max') ? conditions['max'] : 100;
    double ideal =
        conditions.containsKey('ideal') ? conditions['ideal'] : (min + max) / 2;
    String unit = conditions.containsKey('unit') ? conditions['unit'] : '';

    // Calculate positions (0-100%)
    double range = max - min;
    double idealPosition = range > 0 ? ((ideal - min) / range) * 100 : 50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: idealPosition / 100,
                child: Container(
                  decoration: BoxDecoration(color: Colors.transparent),
                ),
              ),
              Positioned(
                left: (idealPosition / 100) * double.infinity,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${min.toStringAsFixed(1)}$unit',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Ideal: ${ideal.toStringAsFixed(1)}$unit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Text(
              '${max.toStringAsFixed(1)}$unit',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  String _getOptimalConditionDescription(
    String factor,
    Map<String, dynamic> conditions,
  ) {
    switch (factor) {
      case 'temperature':
        return 'Bees forage most efficiently in moderate temperatures. Too cold and they cannot fly, too hot and they must collect water instead of nectar.';
      case 'humidity':
        return 'Moderate humidity is ideal for nectar production in flowers and bee flight efficiency.';
      case 'windSpeed':
        return 'Strong winds make it difficult for bees to navigate and can reduce foraging efficiency.';
      case 'precipitation':
        return 'Bees typically do not forage during rain, as it impedes flight and dilutes nectar.';
      default:
        return 'These conditions represent the optimal range for efficient foraging.';
    }
  }

  // Helper methods for time-based analysis
  String _getConsistencyRating(Map<String, dynamic> timeBasedAnalysis) {
    if (!timeBasedAnalysis.containsKey('dailyReturnRates') ||
        timeBasedAnalysis['dailyReturnRates'].isEmpty) {
      return 'Fair';
    }

    // Calculate consistency based on variation in return rates
    final dailyRates = timeBasedAnalysis['dailyReturnRates'];
    List<double> overallRates = [];

    dailyRates.forEach((day, data) {
      if (data.containsKey('overallReturnRate')) {
        overallRates.add(data['overallReturnRate']);
      }
    });

    if (overallRates.isEmpty) return 'Fair';

    // Calculate coefficient of variation
    double mean = overallRates.reduce((a, b) => a + b) / overallRates.length;
    double variance =
        overallRates.fold(0.0, (sum, rate) => sum + math.pow(rate - mean, 2)) /
        overallRates.length;
    double stdDev = math.sqrt(variance);
    double cv = mean > 0 ? stdDev / mean : 0;

    // Lower CV means more consistent
    if (cv < 0.1) return 'Excellent';
    if (cv < 0.2) return 'Good';
    if (cv < 0.3) return 'Fair';
    return 'Needs Improvement';
  }

  String _getTripDurationRating(Map<String, dynamic> timeBasedAnalysis) {
    if (!timeBasedAnalysis.containsKey('avgReturnTimes') ||
        timeBasedAnalysis['avgReturnTimes'].isEmpty) {
      return 'Fair';
    }

    final avgReturnTimes = timeBasedAnalysis['avgReturnTimes'];

    // Check if medium trips (optimal duration) are dominant
    if (timeBasedAnalysis.containsKey('tripDistributionPercentages')) {
      final distribution = timeBasedAnalysis['tripDistributionPercentages'];

      if (distribution.containsKey('medium') && distribution['medium'] > 50) {
        return 'Excellent';
      } else if (distribution.containsKey('medium') &&
          distribution['medium'] > 35) {
        return 'Good';
      } else if (distribution.containsKey('short') &&
          distribution['short'] > 60) {
        return 'Needs Improvement'; // Too many short trips
      }
    }

    // Check average medium trip duration
    if (avgReturnTimes.containsKey('medium')) {
      double mediumDuration = avgReturnTimes['medium'];

      if (mediumDuration >= 45 && mediumDuration <= 90) {
        return 'Good';
      }
    }

    return 'Fair';
  }

  String _getPatternStabilityRating(Map<String, dynamic> timeBasedAnalysis) {
    if (!timeBasedAnalysis.containsKey('dailyReturnRates') ||
        timeBasedAnalysis['dailyReturnRates'].isEmpty) {
      return 'Fair';
    }

    // Check if morning and afternoon patterns are consistent across days
    final dailyRates = timeBasedAnalysis['dailyReturnRates'];
    List<double> morningRatios = [];
    List<double> afternoonRatios = [];

    dailyRates.forEach((day, data) {
      if (data.containsKey('timeBlocks')) {
        final timeBlocks = data['timeBlocks'];

        if (timeBlocks.containsKey('morning') &&
            timeBlocks.containsKey('afternoon') &&
            timeBlocks['morning'].containsKey('actualReturnRate') &&
            timeBlocks['afternoon'].containsKey('actualReturnRate')) {
          double morningRate = timeBlocks['morning']['actualReturnRate'];
          double afternoonRate = timeBlocks['afternoon']['actualReturnRate'];

          if (morningRate > 0 && afternoonRate > 0) {
            morningRatios.add(morningRate);
            afternoonRatios.add(afternoonRate);
          }
        }
      }
    });

    if (morningRatios.isEmpty || afternoonRatios.isEmpty) return 'Fair';

    // Calculate coefficient of variation for both time periods
    double morningCV = _calculateCV(morningRatios);
    double afternoonCV = _calculateCV(afternoonRatios);

    // Average the two CVs
    double avgCV = (morningCV + afternoonCV) / 2;

    // Lower CV means more stable patterns
    if (avgCV < 0.1) return 'Excellent';
    if (avgCV < 0.2) return 'Good';
    if (avgCV < 0.3) return 'Fair';
    return 'Needs Improvement';
  }

  double _calculateCV(List<double> values) {
    if (values.isEmpty) return 0;

    double mean = values.reduce((a, b) => a + b) / values.length;
    double variance =
        values.fold(0.0, (sum, value) => sum + math.pow(value - mean, 2)) /
        values.length;
    double stdDev = math.sqrt(variance);

    return mean > 0 ? stdDev / mean : 0;
  }

  // Helper methods for formatting and styling
  String _formatTimeBlockName(String blockName) {
    switch (blockName) {
      case 'morning':
        return 'Morning';
      case 'midday':
        return 'Midday';
      case 'afternoon':
        return 'Afternoon';
      case 'evening':
        return 'Evening';
      default:
        return blockName.substring(0, 1).toUpperCase() + blockName.substring(1);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatShortDate(DateTime date) {
    return DateFormat('MM/dd').format(date);
  }

  Color _getReturnRateColor(double actual, double expected) {
    if (actual >= expected) {
      return Colors.green;
    } else if (actual >= expected * 0.9) {
      return Colors.lightGreen;
    } else if (actual >= expected * 0.8) {
      return Colors.amber;
    } else {
      return Colors.orange;
    }
  }

  Color _getTripDurationColor(double duration) {
    if (duration >= 45 && duration <= 90) {
      return Colors.green; // Optimal range
    } else if (duration >= 30 && duration <= 120) {
      return Colors.lightGreen; // Good range
    } else if (duration >= 15 && duration <= 150) {
      return Colors.amber; // Fair range
    } else {
      return Colors.orange; // Poor range
    }
  }

  Color _getConsistencyColor(double consistency) {
    if (consistency >= 90) {
      return Colors.green;
    } else if (consistency >= 75) {
      return Colors.lightGreen;
    } else if (consistency >= 60) {
      return Colors.amber;
    } else {
      return Colors.orange;
    }
  }

  String _getConsistencyLabel(double consistency) {
    if (consistency >= 90) {
      return 'Very Consistent';
    } else if (consistency >= 75) {
      return 'Consistent';
    } else if (consistency >= 60) {
      return 'Somewhat Variable';
    } else {
      return 'Highly Variable';
    }
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 16, height: 16, color: color),
        SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildColorLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildDurationLegendItem(
    String label,
    String range,
    Color color,
    String avgTime,
  ) {
    return Column(
      children: [
        Container(width: 16, height: 16, color: color),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(range, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(
          'Avg: $avgTime',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildHealthFactor(String label, String rating) {
    Color ratingColor;

    switch (rating) {
      case 'Excellent':
        ratingColor = Colors.green;
        break;
      case 'Good':
        ratingColor = Colors.lightGreen;
        break;
      case 'Fair':
        ratingColor = Colors.amber;
        break;
      default:
        ratingColor = Colors.orange;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 14))),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: ratingColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            rating,
            style: TextStyle(
              fontSize: 12,
              color: ratingColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

