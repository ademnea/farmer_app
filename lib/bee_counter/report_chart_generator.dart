import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/Services/weather_service.dart';
import 'package:farmer_app/bee_counter/foraging_efficiency_metric.dart';

/// Utility class for generating charts and visualizations for PDF reports
class ReportChartGenerator {
  
  /// Generate a bar chart for time-period analysis
  static pw.Widget generateTimePeriodChart(
    Map<String, dynamic> periodData,
    pw.Font font,
  ) {
    // Prepare data for bar chart
    final periods = ['morning', 'noon', 'evening'];
    final labels = ['Morning', 'Noon', 'Evening'];
    final beesIn = <double>[];
    final beesOut = <double>[];
    
    for (final period in periods) {
      final data = periodData[period] as Map<String, dynamic>? ?? {};
      beesIn.add(data['averageIn'] as double? ?? 0.0);
      beesOut.add(data['averageOut'] as double? ?? 0.0);
    }
    
    // Find max value for chart scaling
    double maxValue = 0.0;
    for (int i = 0; i < beesIn.length; i++) {
      if (beesIn[i] > maxValue) maxValue = beesIn[i];
      if (beesOut[i] > maxValue) maxValue = beesOut[i];
    }
    maxValue = (maxValue * 1.2).ceilToDouble(); // Add 20% headroom
    
    return pw.Chart(
      title: pw.Text(
        'Average Bee Activity by Time Period',
        style: pw.TextStyle(font: font, fontSize: 14),
      ),
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis([0, 1, 2]),
        yAxis: pw.FixedAxis.fromStrings(
          List.generate((maxValue ~/ 10) + 1, (index) => (index * 10).toString()),
          divisions: true,
        ),
      ),
      datasets: [
        pw.BarDataSet(
          color: PdfColors.green700,
          legend: 'Bees Entering',
          width: 40,
          offset: -25,
          data: List.generate(beesIn.length, (i) => 
            pw.PointChartValue(i.toDouble(), beesIn[i]),
          ),
        ),
        pw.BarDataSet(
          color: PdfColors.orange700,
          legend: 'Bees Exiting',
          width: 40,
          offset: 25,
          data: List.generate(beesOut.length, (i) => 
            pw.PointChartValue(i.toDouble(), beesOut[i]),
          ),
        ),
      ],
    );
  }
  
  /// Generate a line chart for daily efficiency metrics
  static pw.Widget generateEfficiencyTimelineChart(
    List<ForagingEfficiencyMetric> metrics,
    pw.Font font,
  ) {
    if (metrics.isEmpty) {
      return pw.Container();
    }
    
    // Prepare efficiency score data for line chart
    final efficiencyData = <pw.PointChartValue>[];
    
    for (int i = 0; i < metrics.length; i++) {
      efficiencyData.add(pw.PointChartValue(
        i.toDouble(), 
        metrics[i].efficiencyScore,
      ));
    }
    
    // Calculate max Y value
    double maxY = 0.0;
    for (final metric in metrics) {
      if (metric.efficiencyScore > maxY) {
        maxY = metric.efficiencyScore;
      }
    }
    maxY = (maxY * 1.2).ceilToDouble(); // Add 20% headroom
    
    return pw.Chart(
      title: pw.Text(
        'Daily Foraging Efficiency Score',
        style: pw.TextStyle(font: font, fontSize: 14),
      ),
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis(
          List.generate(metrics.length, (index) => index.toDouble()),
        ),
        yAxis: pw.FixedAxis.fromStrings(
          List.generate(
            (maxY ~/ 10) + 1, 
            (index) => (index * 10).toString(),
          ),
          divisions: true,
        ),
      ),
      datasets: [
        pw.LineDataSet(
          legend: 'Efficiency Score',
          drawPoints: true,
          isCurved: true,
          color: PdfColors.blue700,
          data: efficiencyData,
        ),
      ],
    );
  }
  
  /// Generate a scatter plot for temperature vs efficiency
  static pw.Widget generateTempVsEfficiencyChart(
    List<ForagingEfficiencyMetric> metrics,
    pw.Font font,
  ) {
    if (metrics.isEmpty) {
      return pw.Container();
    }
    
    // Prepare scatter data
    final scatterData = <pw.PointChartValue>[];
    
    // Calculate min/max temperature
    double minTemp = double.infinity;
    double maxTemp = -double.infinity;
    double maxEfficiency = 0.0;
    
    for (final metric in metrics) {
      scatterData.add(pw.PointChartValue(
        metric.temperature, 
        metric.efficiencyScore,
      ));
      
      if (metric.temperature < minTemp) minTemp = metric.temperature;
      if (metric.temperature > maxTemp) maxTemp = metric.temperature;
      if (metric.efficiencyScore > maxEfficiency) maxEfficiency = metric.efficiencyScore;
    }
    
    // Add padding to ranges
    minTemp = (minTemp - 2).floorToDouble();
    maxTemp = (maxTemp + 2).ceilToDouble();
    maxEfficiency = (maxEfficiency * 1.1).ceilToDouble();
    
    return pw.Chart(
      title: pw.Text(
        'Temperature vs Foraging Efficiency',
        style: pw.TextStyle(font: font, fontSize: 14),
      ),
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis.fromStrings(
          List.generate(
            ((maxTemp - minTemp) ~/ 2) + 1, 
            (index) => (minTemp + index * 2).round().toString(),
          ),
        ),
        yAxis: pw.FixedAxis.fromStrings(
          List.generate(
            (maxEfficiency ~/ 10) + 1, 
            (index) => (index * 10).toString(),
          ),
          divisions: true,
        ),
      ),
      datasets: [
        // Replace ScatterDataSet with LineDataSet configured to look like a scatter plot
        pw.LineDataSet(
          legend: 'Efficiency by Temperature',
          drawPoints: true,
          isCurved: false,  // Turn off line curve
          pointSize: 5.0,   // Increase point size 
          drawSurface: false, // Don't draw connecting lines if available
          data: scatterData,
          color: PdfColors.blue,
        ),
      ],
    );
  }
  
  /// Generate a daily activity chart for bee counts
  static pw.Widget generateActivityTimeline(
    Map<DateTime, Map<String, double>> dailyAverages,
    pw.Font font,
  ) {
    if (dailyAverages.isEmpty) {
      return pw.Container();
    }
    
    // Sort dates
    final sortedDates = dailyAverages.keys.toList()..sort((a, b) => a.compareTo(b));
    
    // Prepare data for line chart
    final inData = <pw.PointChartValue>[];
    final outData = <pw.PointChartValue>[];
    
    double maxY = 0.0;
    
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final data = dailyAverages[date]!;
      
      final inValue = data['averageIn'] ?? 0.0;
      final outValue = data['averageOut'] ?? 0.0;
      
      inData.add(pw.PointChartValue(i.toDouble(), inValue));
      outData.add(pw.PointChartValue(i.toDouble(), outValue));
      
      if (inValue > maxY) maxY = inValue;
      if (outValue > maxY) maxY = outValue;
    }
    
    maxY = (maxY * 1.2).ceilToDouble(); // Add 20% headroom
    
    return pw.Chart(
      title: pw.Text(
        'Daily Bee Activity',
        style: pw.TextStyle(font: font, fontSize: 14),
      ),
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis(
          List.generate(sortedDates.length, (index) => index.toDouble()),
        ),
        yAxis: pw.FixedAxis.fromStrings(
          List.generate(
            (maxY ~/ 10) + 1, 
            (index) => (index * 10).toString(),
          ),
          divisions: true,
        ),
      ),
      datasets: [
        pw.LineDataSet(
          legend: 'Bees Entering',
          drawPoints: false,
          isCurved: true,
          color: PdfColors.green700,
          data: inData,
        ),
        pw.LineDataSet(
          legend: 'Bees Exiting',
          drawPoints: false,
          isCurved: true,
          color: PdfColors.orange700,
          data: outData,
        ),
      ],
    );
  }
  
  /// Generate a weather correlation chart showing activity vs temperature
  static pw.Widget generateWeatherCorrelationChart(
    List<ForagingEfficiencyMetric> metrics,
    pw.Font font,
  ) {
    if (metrics.isEmpty) {
      return pw.Container();
    }
    
    // Group metrics by temperature ranges (2°C intervals)
    final tempRanges = <double, List<ForagingEfficiencyMetric>>{};
    double minTemp = double.infinity;
    double maxTemp = -double.infinity;
    
    for (final metric in metrics) {
      // Round temperature to nearest 2°C
      final double tempRange = ((metric.temperature / 2).round() * 2).toDouble(); // Explicitly convert to double
      
      if (!tempRanges.containsKey(tempRange)) {
        tempRanges[tempRange] = [];
      }
      
      tempRanges[tempRange]!.add(metric);
      
      
      if (tempRange < minTemp) minTemp = tempRange;
      if (tempRange > maxTemp) maxTemp = tempRange;
    }
    
    // Calculate average activity for each temperature range
    final activityByTemp = <pw.PointChartValue>[];
    double maxActivity = 0.0;
    
    for (double temp = minTemp; temp <= maxTemp; temp += 2) {
      if (tempRanges.containsKey(temp)) {
        final metricsInRange = tempRanges[temp]!;
        double totalActivity = 0.0;
        
        for (final metric in metricsInRange) {
          totalActivity += metric.totalActivity.toDouble();
        }
        
        final avgActivity = totalActivity / metricsInRange.length;
        activityByTemp.add(pw.PointChartValue(temp, avgActivity));
        
        if (avgActivity > maxActivity) maxActivity = avgActivity;
      }
    }
    
    maxActivity = (maxActivity * 1.2).ceilToDouble(); // Add 20% headroom
    
    return pw.Chart(
      title: pw.Text(
        'Average Activity by Temperature',
        style: pw.TextStyle(font: font, fontSize: 14),
      ),
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis.fromStrings(
          List.generate(
            ((maxTemp - minTemp) ~/ 2) + 1, 
            (index) => (minTemp + index * 2).round().toString(),
          ),
        ),
        yAxis: pw.FixedAxis.fromStrings(
          List.generate(
            (maxActivity ~/ 50) + 1, 
            (index) => (index * 50).toString(),
          ),
          divisions: true,
        ),
      ),
      datasets: [
        pw.LineDataSet(
          legend: 'Bee Activity',
          drawPoints: true,
          isCurved: true,
          color: PdfColors.amber700,
          data: activityByTemp,
        ),
      ],
    );
  }
  
  /// Generate a pie chart showing the distribution of activity by time period
  static pw.Widget generateActivityDistributionPie(
    Map<String, dynamic> periodData,
    pw.Font font,
  ) {
    // Prepare data for pie chart
    final periods = ['morning', 'noon', 'evening'];
    final labels = ['Morning', 'Noon', 'Evening'];
    final colors = [PdfColors.amber300, PdfColors.amber500, PdfColors.amber700];
    final activities = <double>[];
    
    for (final period in periods) {
      final data = periodData[period] as Map<String, dynamic>? ?? {};
      activities.add(data['totalActivity'] as double? ?? 0.0);
    }
    
    // Calculate total for percentages
    final total = activities.fold<double>(0, (sum, value) => sum + value);
    
    // Create pie segments
    final pieData = <Map<String, dynamic>>[];
    
    for (int i = 0; i < periods.length; i++) {
      if (activities[i] > 0) {
        pieData.add({
          'value': activities[i],
          'color': colors[i],
          'label': '${labels[i]} (${(activities[i] / total * 100).round()}%)',
        });
      }
    }
    
    // Then create a simple table-based representation
    final pieChart = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Title
        pw.Text(
          'Activity Distribution by Time of Day',
          style: pw.TextStyle(font: font, fontSize: 14),
        ),
        pw.SizedBox(height: 10),
        
        // Colored legend boxes with percentages
        ...pieData.map((segment) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            children: [
              pw.Container(
                width: 16,
                height: 16,
                color: segment['color'],
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                segment['label'],
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ],
          ),
        )),
        
        // Visual bar representation of proportions
        pw.SizedBox(height: 10),
        pw.Container(
          height: 20,
          child: pw.Row(
            children: pieData.map((segment) => pw.Expanded(
              flex: ((segment['value'] / total) * 100).round(),
              child: pw.Container(color: segment['color']),
            )).toList(),
          ),
        ),
      ],
    );
    
    return pieChart;
  }
}
