// File: lib/bee_counter/bee_activity_visualization_new.dart
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

    // Implementation details...

    // Use Container instead of SizedBox to avoid instance member access issues
    return Container(
      height: 250,
      child: Text("Activity Timeline Chart"),
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

    // Implementation details...

    // Use Container instead of SizedBox
    return Container(
      height: 250,
      child: Text("Temperature Correlation Chart"),
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

    // Implementation details...

    // Use Container instead of SizedBox
    return Container(
      height: 250,
      child: Text("Humidity Correlation Chart"),
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

    // Implementation details...

    // Use Container instead of SizedBox
    return Container(
      height: 250,
      child: Text("Time of Day Activity Chart"),
    );
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

    // Implementation details...

    // Use Container instead of SizedBox to avoid instance member issues
    return Container(
      height: 300,
      child: Text("Weight Correlation Chart"),
    );
  }

  /// Builds insights text about correlations between bee activity and environmental factors
  static Widget buildCorrelationInsights({
    required Map<String, double> correlations,
    required BuildContext context,
  }) {
    // Implementation details...

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text("Correlation Insights"),
      ),
    );
  }

  // Widget for showing no data message - use Container instead of SizedBox
  static Widget _buildNoDataWidget(String message) {
    return Container(
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
            Container(height: 16), // Use Container instead of SizedBox
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
    // Implementation details...
    return "Correlation Text";
  }

  static Color _getCorrelationColor(double value) {
    // Implementation details...
    return Colors.blue;
  }

  static IconData _getCorrelationIcon(double value) {
    // Implementation details...
    return Icons.info;
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
}

/// Helper class to store point data for charts
class _Point {
  final double x;
  final double y;

  _Point({required this.x, required this.y});
}
