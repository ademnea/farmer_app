import 'package:flutter/material.dart';
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/bee_counter/server_video_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class BeeCountResultsScreen extends StatefulWidget {
  final String hiveId;
  final DateTime date;

  const BeeCountResultsScreen({
    Key? key,
    required this.hiveId,
    required this.date,
  }) : super(key: key);

  @override
  _BeeCountResultsScreenState createState() => _BeeCountResultsScreenState();
}

class _BeeCountResultsScreenState extends State<BeeCountResultsScreen> {
  final ServerVideoService _serverVideoService = ServerVideoService();
  List<BeeCount> _beeCounts = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Define theme colors
  final Color _primaryColor = Color(0xFFFFB74D); // Amber accent
  final Color _secondaryColor = Color(0xFF4CAF50); // Green
  final Color _backgroundColor = Color(0xFFF5F5F5); // Light grey background
  final Color _cardColor = Colors.white;
  final Color _textColor = Color(0xFF424242); // Dark grey
  final Color _enteringColor = Color(0xFF4CAF50); // Green for entering bees
  final Color _exitingColor = Color(0xFFE57373); // Red for exiting bees

  @override
  void initState() {
    super.initState();
    _loadBeeCountsForDate();
  }

  Future<void> _loadBeeCountsForDate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final counts = await _serverVideoService.getBeeCountsForDate(
        widget.hiveId,
        widget.date,
      );

      setState(() {
        _beeCounts = counts;
        _isLoading = false;
      });

      print('Loaded ${counts.length} bee counts for date: ${widget.date}');
    } catch (e) {
      print('Error loading bee counts: $e');
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bee Count Results'),
        backgroundColor: _primaryColor,
        elevation: 0,
      ),
      backgroundColor: _backgroundColor,
      body:
          _isLoading
              ? _buildLoadingIndicator()
              : _errorMessage.isNotEmpty
              ? _buildErrorMessage()
              : _beeCounts.isEmpty
              ? _buildNoDataMessage()
              : _buildResultsContent(),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
          ),
          SizedBox(height: 16),
          Text(
            'Loading bee count data...',
            style: TextStyle(color: _textColor, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: TextStyle(
                color: _textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(color: _textColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              onPressed: _loadBeeCountsForDate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text(
              'No Bee Count Data Available',
              style: TextStyle(
                color: _textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'There are no bee count records for ${DateFormat('MMMM d, yyyy').format(widget.date)}.',
              style: TextStyle(color: _textColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.calendar_today),
              label: Text('Select Another Date'),
              onPressed: () {
                _selectDate(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: widget.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != widget.date) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  BeeCountResultsScreen(hiveId: widget.hiveId, date: picked),
        ),
      );
    }
  }

  Widget _buildResultsContent() {
    // Calculate daily totals
    final totalEntering = _beeCounts.fold<int>(
      0,
      (sum, count) => sum + count.beesEntering,
    );
    final totalExiting = _beeCounts.fold<int>(
      0,
      (sum, count) => sum + count.beesExiting,
    );
    final netChange = totalEntering - totalExiting;
    final totalActivity = totalEntering + totalExiting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateHeader(),
          SizedBox(height: 16),
          _buildDailySummaryCard(
            totalEntering,
            totalExiting,
            netChange,
            totalActivity,
          ),
          SizedBox(height: 24),
          _buildActivityChart(),
          SizedBox(height: 24),
          _buildBeeCountsList(),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: Colors.white, size: 28),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM d, yyyy').format(widget.date),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Bee Activity Summary',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.calendar_month, color: Colors.white),
            onPressed: () => _selectDate(context),
            tooltip: 'Select another date',
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummaryCard(
    int totalEntering,
    int totalExiting,
    int netChange,
    int totalActivity,
  ) {
    final netChangeColor = netChange >= 0 ? _enteringColor : _exitingColor;
    final netChangeIcon =
        netChange >= 0 ? Icons.arrow_upward : Icons.arrow_downward;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: _primaryColor, size: 24),
                SizedBox(width: 12),
                Text(
                  'Daily Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Entering',
                    '$totalEntering',
                    Icons.login,
                    _enteringColor,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Exiting',
                    '$totalExiting',
                    Icons.logout,
                    _exitingColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Net Change',
                    '${netChange >= 0 ? "+" : ""}$netChange',
                    netChangeIcon,
                    netChangeColor,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Activity',
                    '$totalActivity',
                    Icons.sync,
                    _secondaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: _textColor.withOpacity(0.8), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChart() {
    if (_beeCounts.isEmpty) {
      return SizedBox.shrink();
    }

    // Sort bee counts by timestamp
    final sortedCounts = List<BeeCount>.from(_beeCounts)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Prepare data for the chart
    final enteringSpots = <FlSpot>[];
    final exitingSpots = <FlSpot>[];

    for (int i = 0; i < sortedCounts.length; i++) {
      final count = sortedCounts[i];
      enteringSpots.add(FlSpot(i.toDouble(), count.beesEntering.toDouble()));
      exitingSpots.add(FlSpot(i.toDouble(), count.beesExiting.toDouble()));
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: _primaryColor, size: 24),
                SizedBox(width: 12),
                Text(
                  'Activity Throughout the Day',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Container(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 5,
                    verticalInterval: 1,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < sortedCounts.length) {
                            final time = DateFormat(
                              'HH:mm',
                            ).format(sortedCounts[value.toInt()].timestamp);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                time,
                                style: TextStyle(
                                  color: _textColor.withOpacity(0.7),
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return Text('');
                        },
                        interval: 1,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: _textColor.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          );
                        },
                        interval: 5,
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  minX: 0,
                  maxX: (sortedCounts.length - 1).toDouble(),
                  minY: 0,
                  maxY:
                      sortedCounts
                          .map((e) => max(e.beesEntering, e.beesExiting))
                          .reduce(max)
                          .toDouble() +
                      5,
                  lineBarsData: [
                    LineChartBarData(
                      spots: enteringSpots,
                      isCurved: true,
                      color: _enteringColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _enteringColor.withOpacity(0.2),
                      ),
                    ),
                    LineChartBarData(
                      spots: exitingSpots,
                      isCurved: true,
                      color: _exitingColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _exitingColor.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Entering', _enteringColor),
                SizedBox(width: 24),
                _buildLegendItem('Exiting', _exitingColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 8),
        Text(label, style: TextStyle(color: _textColor, fontSize: 14)),
      ],
    );
  }

  Widget _buildBeeCountsList() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: _primaryColor, size: 24),
                SizedBox(width: 12),
                Text(
                  'Detailed Records',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _beeCounts.length,
              separatorBuilder: (context, index) => Divider(),
              itemBuilder: (context, index) {
                final beeCount = _beeCounts[index];
                return _buildBeeCountItem(beeCount);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeeCountItem(BeeCount beeCount) {
    final netChange = beeCount.netChange;
    final netChangeColor = netChange >= 0 ? _enteringColor : _exitingColor;
    final netChangeIcon =
        netChange >= 0 ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: _textColor.withOpacity(0.7),
              ),
              SizedBox(width: 8),
              Text(
                DateFormat('HH:mm:ss').format(beeCount.timestamp),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: netChangeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: netChangeColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(netChangeIcon, size: 14, color: netChangeColor),
                    SizedBox(width: 4),
                    Text(
                      '${netChange >= 0 ? "+" : ""}${netChange}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: netChangeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.login, size: 16, color: _enteringColor),
                    SizedBox(width: 4),
                    Text(
                      'Entering: ${beeCount.beesEntering}',
                      style: TextStyle(fontSize: 14, color: _textColor),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 16, color: _exitingColor),
                    SizedBox(width: 4),
                    Text(
                      'Exiting: ${beeCount.beesExiting}',
                      style: TextStyle(fontSize: 14, color: _textColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (beeCount.notes != null && beeCount.notes!.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              beeCount.notes!,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: _textColor.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

