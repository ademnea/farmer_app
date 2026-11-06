// File: lib/bee_counter/bee_activity_visualization_fixed.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/bee_counter/weatherdata.dart';
import 'package:farmer_app/hive_model.dart';

/// A class to generate visualizations of bee activity correlated with environmental factors
class BeeActivityVisualization {
  /// Generate a chart showing bee activity over time
  static Widget buildActivityTimelineChart({
    required List<BeeCount> beeCounts,
    required BuildContext context,
    bool showLegend = true,
    bool showEnteringBees = true,
    bool showExitingBees = true,
  }) {
    if (beeCounts.isEmpty) {
      return _buildNoDataWidget('No bee activity data available');
    }

    // Sort counts by timestamp
    final sortedCounts = List<BeeCount>.from(beeCounts)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Group by hour to avoid overcrowding
    final Map<DateTime, BeeCount> hourlyData = {};

    for (final count in sortedCounts) {
      final hour = DateTime(
        count.timestamp.year,
        count.timestamp.month,
        count.timestamp.day,
        count.timestamp.hour,
      );

      if (!hourlyData.containsKey(hour)) {
        hourlyData[hour] = BeeCount(
          hiveId: count.hiveId,
          beesEntering: 0,
          beesExiting: 0,
          timestamp: hour,
        );
      }

      final existing = hourlyData[hour]!;
      hourlyData[hour] = BeeCount(
        hiveId: existing.hiveId,
        videoId: existing.videoId,
        beesEntering: existing.beesEntering + count.beesEntering,
        beesExiting: existing.beesExiting + count.beesExiting,
        timestamp: existing.timestamp,
      );
    }

    // Convert to sorted list
    final List<MapEntry<DateTime, BeeCount>> sortedHourlyData =
        hourlyData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    // Prepare data for the chart
    final enteringSpots = <FlSpot>[];
    final exitingSpots = <FlSpot>[];

    for (int i = 0; i < sortedHourlyData.length; i++) {
      final count = sortedHourlyData[i].value;
      enteringSpots.add(FlSpot(i.toDouble(), count.beesEntering.toDouble()));
      exitingSpots.add(FlSpot(i.toDouble(), count.beesExiting.toDouble()));
    }

    // Find max Y value for the chart
    double maxY = 0;
    for (final count in hourlyData.values) {
      if (count.beesEntering > maxY) maxY = count.beesEntering.toDouble();
      if (count.beesExiting > maxY) maxY = count.beesExiting.toDouble();
    }
    maxY = (maxY * 1.2).ceilToDouble();
    if (maxY < 10) maxY = 10;
    // Use the constructor explicitly to avoid static method issues
    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 &&
                      value.toInt() < sortedHourlyData.length &&
                      value.toInt() % (sortedHourlyData.length ~/ 5 + 1) == 0) {
                    final timestamp = sortedHourlyData[value.toInt()].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('HH:mm').format(timestamp),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
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
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          minX: 0,
          maxX: sortedHourlyData.length - 1,
          minY: 0,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index >= 0 && index < sortedHourlyData.length) {
                    final timestamp = sortedHourlyData[index].key;
                    final activity = spot.y.toInt();
                    final isEntering = spot.barIndex == 0;

                    return LineTooltipItem(
                      '${DateFormat('yyyy-MM-dd HH:mm').format(timestamp)}\n'
                      '${isEntering ? 'Entering' : 'Exiting'}: $activity bees',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }
                  return null;
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            if (showEnteringBees)
              LineChartBarData(
                spots: enteringSpots,
                isCurved: true,
                color: Colors.green,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.green.withOpacity(0.2),
                ),
              ),
            if (showExitingBees)
              LineChartBarData(
                spots: exitingSpots,
                isCurved: true,
                color: Colors.orange,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.orange.withOpacity(0.2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds insights text about correlations between bee activity and environmental factors
  static Widget buildCorrelationInsights({
    required Map<String, double> correlations,
    required BuildContext context,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Insights',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...correlations.entries.map((entry) {
              final correlationValue = entry.value;
              final correlationText = _getCorrelationText(correlationValue);
              final correlationColor = _getCorrelationColor(correlationValue);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Icon(
                      _getCorrelationIcon(correlationValue),
                      color: correlationColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${entry.key}: $correlationText',
                        style: TextStyle(
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: correlationColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        correlationValue.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: correlationColor,
                          fontWeight: FontWeight.bold,
                        ),
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

  /// Build a chart showing bee activity correlation with temperature
  static Widget buildTemperatureCorrelationChart({
    required List<BeeCount> beeCounts,
    required Map<DateTime, WeatherData> weatherData,
    required BuildContext context,
  }) {
    if (beeCounts.isEmpty || weatherData.isEmpty) {
      return _buildNoDataWidget(
          'No data available for temperature correlation');
    }

    // Prepare data points
    final List<_Point> dataPoints = [];

    for (final count in beeCounts) {
      final timestamp = DateTime(
        count.timestamp.year,
        count.timestamp.month,
        count.timestamp.day,
        count.timestamp.hour,
      );

      // Find the closest weather data
      WeatherData? nearestWeather;
      Duration smallestDiff = const Duration(days: 1);

      for (final entry in weatherData.entries) {
        final diff = (entry.key.difference(timestamp)).abs();
        if (diff < smallestDiff) {
          smallestDiff = diff;
          nearestWeather = entry.value;
        }
      }

      // Only add if we have weather data
      if (nearestWeather != null) {
        dataPoints.add(
          _Point(
            x: nearestWeather.temperature,
            y: count.totalActivity.toDouble(),
          ),
        );
      }
    }

    // Create scatter chart
    return SizedBox(
      height: 250,
      child: ScatterChart(
        ScatterChartData(
          scatterSpots:
              dataPoints.map((spot) => ScatterSpot(spot.x, spot.y)).toList(),
          minX: dataPoints.isEmpty
              ? 0
              : dataPoints.map((e) => e.x).reduce(min) - 2,
          maxX: dataPoints.isEmpty
              ? 40
              : dataPoints.map((e) => e.x).reduce(max) + 2,
          minY: 0,
          maxY: dataPoints.isEmpty
              ? 100
              : dataPoints.map((e) => e.y).reduce(max) * 1.1,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Text(
                'Temperature (°C)',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text(
                'Bee Activity',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            drawHorizontalLine: true,
            horizontalInterval: 20,
            verticalInterval: 5,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: const Color(0xff37434d),
              width: 1,
            ),
          ),
          scatterTouchData: ScatterTouchData(
            enabled: true,
            touchTooltipData: ScatterTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpot) {
                return ScatterTooltipItem(
                  'Temperature: ${touchedSpot.x.toStringAsFixed(1)}°C\n'
                  'Activity: ${touchedSpot.y.toInt()} bees',
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Build a chart showing bee activity correlation with humidity
  static Widget buildHumidityCorrelationChart({
    required List<BeeCount> beeCounts,
    required Map<DateTime, WeatherData> weatherData,
    required BuildContext context,
  }) {
    if (beeCounts.isEmpty || weatherData.isEmpty) {
      return _buildNoDataWidget('No data available for humidity correlation');
    }

    // Prepare data points
    final List<_Point> dataPoints = [];

    for (final count in beeCounts) {
      final timestamp = DateTime(
        count.timestamp.year,
        count.timestamp.month,
        count.timestamp.day,
        count.timestamp.hour,
      );

      // Find the closest weather data
      WeatherData? nearestWeather;
      Duration smallestDiff = const Duration(days: 1);

      for (final entry in weatherData.entries) {
        final diff = (entry.key.difference(timestamp)).abs();
        if (diff < smallestDiff) {
          smallestDiff = diff;
          nearestWeather = entry.value;
        }
      }

      // Only add if we have weather data
      if (nearestWeather != null) {
        dataPoints.add(
          _Point(
            x: nearestWeather.humidity,
            y: count.totalActivity.toDouble(),
          ),
        );
      }
    }

    // Create scatter chart
    return SizedBox(
      height: 250,
      child: ScatterChart(
        ScatterChartData(
          scatterSpots:
              dataPoints.map((spot) => ScatterSpot(spot.x, spot.y)).toList(),
          minX: dataPoints.isEmpty
              ? 0
              : dataPoints.map((e) => e.x).reduce(min) - 5,
          maxX: dataPoints.isEmpty
              ? 100
              : dataPoints.map((e) => e.x).reduce(max) + 5,
          minY: 0,
          maxY: dataPoints.isEmpty
              ? 100
              : dataPoints.map((e) => e.y).reduce(max) * 1.1,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Text(
                'Humidity (%)',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text(
                'Bee Activity',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            drawHorizontalLine: true,
            horizontalInterval: 20,
            verticalInterval: 10,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: const Color(0xff37434d),
              width: 1,
            ),
          ),
          scatterTouchData: ScatterTouchData(
            enabled: true,
            touchTooltipData: ScatterTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpot) {
                return ScatterTooltipItem(
                  'Humidity: ${touchedSpot.x.toStringAsFixed(1)}%\n'
                  'Activity: ${touchedSpot.y.toInt()} bees',
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Build a chart showing time of day activity patterns
  static Widget buildTimeOfDayActivityChart({
    required List<BeeCount> beeCounts,
    required BuildContext context,
  }) {
    if (beeCounts.isEmpty) {
      return _buildNoDataWidget('No data available for time of day analysis');
    }

    // Prepare hourly data
    final List<int> hourlyActivity = List.filled(24, 0);
    final List<int> hourlyCount = List.filled(24, 0);

    for (final count in beeCounts) {
      final hour = count.timestamp.hour;
      hourlyActivity[hour] += count.totalActivity;
      hourlyCount[hour]++;
    }

    // Calculate average activity per hour
    final List<double> averageHourlyActivity = List.filled(24, 0);
    for (int i = 0; i < 24; i++) {
      if (hourlyCount[i] > 0) {
        averageHourlyActivity[i] = hourlyActivity[i] / hourlyCount[i];
      }
    }

    // Prepare data for the chart
    final List<BarChartGroupData> barGroups = [];
    for (int hour = 0; hour < 24; hour++) {
      barGroups.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: averageHourlyActivity[hour],
              color: _getColorForHour(hour),
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
        ),
      );
    }

    // Create bar chart
    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          barGroups: barGroups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Text(
                'Hour of Day (24-hour format)',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final hour = value.toInt();
                  // Only show every 4 hours
                  if (hour % 4 != 0) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      hour.toString().padLeft(2, '0') + ':00',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text(
                'Average Bee Activity',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.8),
                width: 1,
              ),
              left: BorderSide(
                color: Colors.grey.withOpacity(0.8),
                width: 1,
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final hour = group.x;
                final activity = rod.toY;
                return BarTooltipItem(
                  '${hour.toString().padLeft(2, '0')}:00 - ${(hour + 1) % 24}:00\n'
                  'Activity: ${activity.toStringAsFixed(1)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Get a color based on the hour of day
  static Color _getColorForHour(int hour) {
    if (hour < 6) {
      return Colors.indigo.shade300; // Night
    } else if (hour < 12) {
      return Colors.amber.shade500; // Morning
    } else if (hour < 18) {
      return Colors.orange.shade600; // Afternoon
    } else {
      return Colors.deepPurple.shade300; // Evening
    }
  }

  /// Build a chart showing correlation between bee activity and hive weight
  static Widget buildWeightCorrelationChart({
    required List<BeeCount> beeCounts,
    required List<HiveData> hiveData,
    required BuildContext context,
  }) {
    if (beeCounts.isEmpty || hiveData.isEmpty) {
      return _buildNoDataWidget('No data available for weight correlation');
    }

    // Prepare data for timeline chart with dual y axes
    final List<FlSpot> activitySpots = [];
    final List<FlSpot> weightSpots = [];

    // Sort by date first
    final sortedCounts = List<BeeCount>.from(beeCounts)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Group bee counts by day
    final Map<DateTime, BeeCount> dailyActivity = {};
    for (final count in sortedCounts) {
      final day = DateTime(
        count.timestamp.year,
        count.timestamp.month,
        count.timestamp.day,
      );

      if (!dailyActivity.containsKey(day)) {
        dailyActivity[day] = BeeCount(
          hiveId: count.hiveId,
          beesEntering: 0,
          beesExiting: 0,
          timestamp: day,
        );
      }

      final existing = dailyActivity[day]!;
      dailyActivity[day] = BeeCount(
        hiveId: existing.hiveId,
        beesEntering: existing.beesEntering + count.beesEntering,
        beesExiting: existing.beesExiting + count.beesExiting,
        timestamp: day,
      );
    }

    // Sort hive data by date
    final sortedHiveData = List<HiveData>.from(hiveData)
      ..sort((a, b) {
        try {
          final timestampA = DateTime.parse(a.lastChecked);
          final timestampB = DateTime.parse(b.lastChecked);
          return timestampA.compareTo(timestampB);
        } catch (e) {
          return 0;
        }
      });

    // Convert to data points
    final allDates = <DateTime>{};
    dailyActivity.keys.forEach(allDates.add);
    for (final data in sortedHiveData) {
      try {
        allDates.add(DateTime.parse(data.lastChecked));
      } catch (e) {
        // Skip invalid dates
      }
    }

    final sortedDates = allDates.toList()..sort();

    int maxActivity = 0;
    double maxWeight = 0;

    // Create data points
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];

      // Get activity for this date
      final activityValue = dailyActivity[date]?.totalActivity ?? 0;
      activitySpots.add(FlSpot(i.toDouble(), activityValue.toDouble()));
      if (activityValue > maxActivity) {
        maxActivity = activityValue;
      }

      // Find closest hive data for this date
      HiveData? closestData;
      Duration closestDuration = const Duration(days: 365);

      for (final data in sortedHiveData) {
        try {
          final hiveDate = DateTime.parse(data.lastChecked);
          final diff = (hiveDate.difference(date)).abs();
          if (diff < closestDuration) {
            closestDuration = diff;
            closestData = data;
          }
        } catch (e) {
          // Skip invalid dates
        }
      } // Add weight data point if we found matching data
      if (closestData != null) {
        // Use the weight directly - treat it as non-nullable
        final weight = closestData.weight;
        weightSpots.add(FlSpot(i.toDouble(), weight));
        if (weight > maxWeight) {
          maxWeight = weight;
        }
      }
    }

    // Create chart with weight data
    return _buildWeightChart(
      context: context,
      activitySpots: activitySpots,
      weightSpots: weightSpots,
      sortedDates: sortedDates,
      maxActivity: maxActivity,
      maxWeight: maxWeight,
    );
  }

  /// Helper method to build weight correlation chart
  static Widget _buildWeightChart({
    required BuildContext context,
    required List<FlSpot> activitySpots,
    required List<FlSpot> weightSpots,
    required List<DateTime> sortedDates,
    required int maxActivity,
    required double maxWeight,
  }) {
    // We'll display the weight values as they are without scaling
    // We'll use the original weight spots directly instead of scaling them

    // Create line chart with dual y-axes
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxActivity / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 &&
                      index < sortedDates.length &&
                      index % (sortedDates.length ~/ 5 + 1) == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('MM/dd').format(sortedDates[index]),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text(
                'Bee Activity',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(
              axisNameWidget: const Text(
                'Hive Weight (kg)',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index >= 0 && index < sortedDates.length) {
                    final date = sortedDates[index];
                    final value = spot.y.toStringAsFixed(1);
                    final isActivity = spot.barIndex == 0;
                    return LineTooltipItem(
                      '${DateFormat('yyyy-MM-dd').format(date)}\n'
                      '${isActivity ? 'Activity: $value bees' : 'Weight: $value kg'}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }
                  return null;
                }).toList();
              },
            ),
          ),
          minX: 0,
          maxX: sortedDates.length - 1,
          minY: 0,
          maxY: maxActivity.toDouble(),
          lineBarsData: [
            // Activity data (left axis)
            LineChartBarData(
              spots: activitySpots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.2),
              ),
            ),
            // Weight data (right axis)
            LineChartBarData(
              spots: weightSpots,
              isCurved: true,
              color: Colors.amber,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.amber.withOpacity(0.1),
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [],
            verticalLines: [],
            extraLinesOnTop: true,
          ),
        ),
      ),
    );
  }

  // Widget for showing no data message
  static Widget _buildNoDataWidget(String message) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_sharp,
              size: 48,
              color: Colors.grey[400],
            ),
            Container(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper functions for correlation insights
  static String _getCorrelationText(double value) {
    final absValue = value.abs();
    if (absValue < 0.1) {
      return 'No correlation';
    } else if (absValue < 0.3) {
      return 'Weak ' + (value > 0 ? 'positive' : 'negative') + ' correlation';
    } else if (absValue < 0.5) {
      return 'Moderate ' +
          (value > 0 ? 'positive' : 'negative') +
          ' correlation';
    } else if (absValue < 0.7) {
      return 'Strong ' + (value > 0 ? 'positive' : 'negative') + ' correlation';
    } else {
      return 'Very strong ' +
          (value > 0 ? 'positive' : 'negative') +
          ' correlation';
    }
  }

  static Color _getCorrelationColor(double value) {
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

  static IconData _getCorrelationIcon(double value) {
    final absValue = value.abs();
    if (absValue < 0.1) {
      return Icons.remove;
    } else if (value > 0) {
      return absValue < 0.3 ? Icons.trending_up : Icons.arrow_upward;
    } else {
      return absValue < 0.3 ? Icons.trending_down : Icons.arrow_downward;
    }
  }
}

/// Helper class to store pointdata for charts
class _Point {
  final double x;
  final double y;

  _Point({required this.x, required this.y});
}
