// File: lib/bee_counter/bee_activity_visualization.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/bee_counter/weatherdata.dart';

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
                      TextStyle(
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
                dotData: FlDotData(show: false),
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
                dotData: FlDotData(show: false),
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
    // Function to describe the strength of a correlation
    String describeCorrelation(double value) {
      final absValue = value.abs();
      if (absValue < 0.1) return 'very weak';
      if (absValue < 0.3) return 'weak';
      if (absValue < 0.5) return 'moderate';
      if (absValue < 0.7) return 'strong';
      return 'very strong';
    }

    // Function to describe the direction of a correlation
    String correlationDirection(double value) {
      if (value > 0.05) return 'positive';
      if (value < -0.05) return 'negative';
      return 'no clear';
    }

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
            for (final entry in correlations.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '${entry.key}: ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'There is a ${describeCorrelation(entry.value)} ${correlationDirection(entry.value)} correlation '
                            '(r = ${entry.value.toStringAsFixed(2)}) between bee activity and ${entry.key.toLowerCase()}.',
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'What does this mean?',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'These correlation values show how strongly bee activity is related to each factor. '
              'A positive correlation means bee activity increases when the factor increases. '
              'A negative correlation means bee activity decreases when the factor increases. '
              'Stronger correlations (closer to 1 or -1) indicate a more reliable relationship.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
    final dataPoints = <FlSpot>[];
    final entries = weatherData.entries.toList();

    for (final count in beeCounts) {
      // Find closest weather data
      WeatherData? nearestWeather;
      Duration smallestDiff = const Duration(days: 1);

      for (final entry in entries) {
        final diff = (entry.key.difference(count.timestamp)).abs();
        if (diff < smallestDiff) {
          smallestDiff = diff;
          nearestWeather = entry.value;
        }
      }

      if (nearestWeather != null) {
        final temperature = nearestWeather.temperature;
        final activity = count.beesEntering + count.beesExiting;

        dataPoints.add(FlSpot(temperature, activity.toDouble()));
      }
    }

    // Sort data points by temperature for cleaner visualization
    dataPoints.sort((a, b) => a.x.compareTo(b.x));

    return SizedBox(
      height: 250,
      child: ScatterChart(
        ScatterChartData(
          scatterSpots: dataPoints
              .map((spot) => ScatterSpot(
                    spot.x,
                    spot.y,
                  ))
              .toList(),
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
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d), width: 1),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            horizontalInterval: 20,
            drawVerticalLine: true,
            verticalInterval: 2,
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString() + '°C',
                    style: const TextStyle(
                      color: Color(0xff68737d),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
                interval: 5,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: Color(0xff68737d),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          scatterTouchData: ScatterTouchData(
            touchTooltipData: ScatterTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpot) {
                return ScatterTooltipItem(
                  'Temperature: ${touchedSpot.x.toStringAsFixed(1)}°C\n'
                  'Bee Activity: ${touchedSpot.y.toInt()}',
                  textStyle: const TextStyle(color: Colors.white),
                  bottomMargin: 8,
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
    final dataPoints = <FlSpot>[];
    final entries = weatherData.entries.toList();

    for (final count in beeCounts) {
      // Find closest weather data
      WeatherData? nearestWeather;
      Duration smallestDiff = const Duration(days: 1);

      for (final entry in entries) {
        final diff = (entry.key.difference(count.timestamp)).abs();
        if (diff < smallestDiff) {
          smallestDiff = diff;
          nearestWeather = entry.value;
        }
      }

      if (nearestWeather != null) {
        final humidity = nearestWeather.humidity;
        final activity = count.beesEntering + count.beesExiting;

        dataPoints.add(FlSpot(humidity, activity.toDouble()));
      }
    }

    // Sort data points by humidity for cleaner visualization
    dataPoints.sort((a, b) => a.x.compareTo(b.x));

    return SizedBox(
      height: 250,
      child: ScatterChart(
        ScatterChartData(
          scatterSpots: dataPoints
              .map((spot) => ScatterSpot(
                    spot.x,
                    spot.y,
                  ))
              .toList(),
          minX: dataPoints.isEmpty
              ? 0
              : dataPoints.map((e) => e.x).reduce(min) - 2,
          maxX: dataPoints.isEmpty
              ? 100
              : dataPoints.map((e) => e.x).reduce(max) + 2,
          minY: 0,
          maxY: dataPoints.isEmpty
              ? 100
              : dataPoints.map((e) => e.y).reduce(max) * 1.1,
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d), width: 1),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            horizontalInterval: 20,
            drawVerticalLine: true,
            verticalInterval: 10,
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString() + '%',
                    style: const TextStyle(
                      color: Color(0xff68737d),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
                interval: 10,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: Color(0xff68737d),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          scatterTouchData: ScatterTouchData(
            touchTooltipData: ScatterTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpot) {
                return ScatterTooltipItem(
                  'Humidity: ${touchedSpot.x.toStringAsFixed(1)}%\n'
                  'Bee Activity: ${touchedSpot.y.toInt()}',
                  textStyle: const TextStyle(color: Colors.white),
                  bottomMargin: 8,
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

    // Group counts by hour of day
    final Map<int, int> hourlyActivity = {};

    for (int i = 0; i < 24; i++) {
      hourlyActivity[i] = 0;
    }

    for (final count in beeCounts) {
      final hour = count.timestamp.hour;
      final activity = count.beesEntering + count.beesExiting;

      final currentCount = hourlyActivity[hour] ?? 0;
      hourlyActivity[hour] = currentCount + activity.toInt();
    }

    // Convert to bar data
    final barData = <BarChartGroupData>[];

    for (int hour = 0; hour < 24; hour++) {
      barData.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: hourlyActivity[hour]!.toDouble(),
              color: _getColorForHour(hour),
              width: 12,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          barGroups: barData,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: Color(0xff68737d),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  // Only show a few hour labels to avoid crowding
                  final hour = value.toInt();
                  if (hour % 3 == 0) {
                    String amPm = hour < 12 ? 'AM' : 'PM';
                    final displayHour =
                        hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '$displayHour $amPm',
                        style: const TextStyle(
                          color: Color(0xff68737d),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final hour = group.x;
                final activity = rod.toY.toInt();
                String amPm = hour < 12 ? 'AM' : 'PM';
                final displayHour =
                    hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

                return BarTooltipItem(
                  '$displayHour:00 $amPm\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: 'Activity: $activity',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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

    // Sort bee counts by date
    final sortedCounts = List<BeeCount>.from(beeCounts)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Sort hive data by date
    final sortedHiveData = List<HiveData>.from(hiveData)
      ..sort((a, b) => DateTime.parse(a.lastChecked)
          .compareTo(DateTime.parse(b.lastChecked)));

    // Group bee counts by day
    final Map<DateTime, int> dailyActivity = {};

    for (final count in sortedCounts) {
      final day = DateTime(
        count.timestamp.year,
        count.timestamp.month,
        count.timestamp.day,
      );

      dailyActivity[day] = (dailyActivity[day] ?? 0) + count.totalActivity;
    }

    // Prepare data points for chart
    final List<DateTime> allDays = [...dailyActivity.keys];

    for (int i = 0; i < allDays.length; i++) {
      final day = allDays[i];
      final activity = dailyActivity[day] ?? 0;

      activitySpots.add(FlSpot(i.toDouble(), activity.toDouble()));

      // Find hive data for this day
      for (final data in sortedHiveData) {
        final hiveDataDate = DateTime.parse(data.lastChecked);
        final sameDay = day.year == hiveDataDate.year &&
            day.month == hiveDataDate.month &&
            day.day == hiveDataDate.day;
        if (sameDay && data.weight != null) {
          weightSpots.add(FlSpot(i.toDouble(), data.weight!));
          break;
        }
      }
    } // Find max values for scales
    final maxActivity = activitySpots.isEmpty
        ? 100.0
        : activitySpots.map((e) => e.y).reduce(max) * 1.1;

    final maxWeight = weightSpots.isEmpty
        ? 100.0
        : weightSpots.map((e) => e.y).reduce(max) * 1.1;

    final weightFactor = maxActivity / (maxWeight == 0.0 ? 1.0 : maxWeight);

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: activitySpots,
              isCurved: true,
              color: Colors.amber,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
            ),
            LineChartBarData(
              spots: weightSpots
                  .map((spot) => FlSpot(spot.x, spot.y * weightFactor))
                  .toList(),
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              dashArray: [5, 5], // Make this line dashed
            ),
          ],
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d), width: 1),
          ),
          minY: 0,
          maxY: maxActivity.toDouble(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < allDays.length && index % 3 == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('MMM d').format(allDays[index]),
                        style: const TextStyle(
                          color: Color(0xff68737d),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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
              axisNameWidget: const Text('Bee Activity'),
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: Color(0xff68737d),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
            rightTitles: AxisTitles(
              axisNameWidget: const Text('Hive Weight (kg)'),
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    (value / weightFactor).toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            horizontalInterval: maxActivity / 5,
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index >= 0 && index < allDays.length) {
                    if (spot.barIndex == 0) {
                      return LineTooltipItem(
                        '${DateFormat('MMM d').format(allDays[index])}\n'
                        'Activity: ${spot.y.toInt()}',
                        const TextStyle(color: Colors.amber),
                      );
                    } else {
                      return LineTooltipItem(
                        '${DateFormat('MMM d').format(allDays[index])}\n'
                        'Weight: ${(spot.y / weightFactor).toStringAsFixed(1)} kg',
                        const TextStyle(color: Colors.green),
                      );
                    }
                  }
                  return null;
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  // Widget for showing no data message
  static Widget _buildNoDataWidget(String message) {
    return SizedBox(
      height: 250,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Helper function to build a legend item
  static Widget buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Helper class for hive data to use in visualizations
class HiveData {
  final String id;
  final String name;
  final String status;
  final String healthStatus;
  final String lastChecked;
  final bool autoProcessingEnabled;
  final double? weight;
  final double? temperature;
  final double? honeyLevel;
  final bool isConnected;
  final bool isColonized;
  final double? exteriorTemperature;
  final double? interiorHumidity;
  final double? exteriorHumidity;
  final int? carbonDioxide;

  HiveData({
    required this.id,
    required this.name,
    required this.status,
    required this.healthStatus,
    required this.lastChecked,
    required this.autoProcessingEnabled,
    this.weight,
    this.temperature,
    this.honeyLevel,
    required this.isConnected,
    required this.isColonized,
    this.exteriorTemperature,
    this.interiorHumidity,
    this.exteriorHumidity,
    this.carbonDioxide,
  });
}
