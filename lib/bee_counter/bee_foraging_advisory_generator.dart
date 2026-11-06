import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/bee_counter/weatherdata.dart';
import 'package:farmer_app/bee_counter/foraging_efficiency_metric.dart';
import 'package:intl/intl.dart';

/// A class for generating evidence-based bee foraging advisories
class ForagingAdvisoryGenerator {
  /// Generate a list of evidence-based advisories based on foraging data
  static List<String> generateAdvisories({
    required String hiveId,
    required List<BeeCount> beeCounts,
    required Map<String, dynamic> analysisData,
    required List<ForagingEfficiencyMetric> efficiencyMetrics,
    required Map<DateTime, WeatherData> weatherData,
  }) {
    final advisories = <String>[];
    
    // Skip advisory generation if no data
    if (efficiencyMetrics.isEmpty || analysisData.isEmpty) {
      return ['Insufficient data to generate advisories. Continue monitoring bee activity to receive evidence-based recommendations.'];
    }
    
    // Get optimal conditions
    final optimalConditions = analysisData['optimalConditions'] as Map<String, dynamic>? ?? {};
    final optimalTemp = optimalConditions['temperature'] ?? 0.0;
    final optimalHumidity = optimalConditions['humidity'] ?? 0.0;
    final optimalWind = optimalConditions['wind'] ?? 0.0;
    final peakTime = analysisData['peakActivityTime'] ?? 'N/A';
    
    // 1. General optimal conditions advisory
    advisories.add(
      'OPTIMAL FORAGING CONDITIONS:\n\n'
      'Based on your colony\'s historical data, optimal foraging conditions include:\n'
      '• Temperature: ${optimalTemp.toStringAsFixed(1)}°C\n'
      '• Humidity: ${optimalHumidity.toStringAsFixed(0)}%\n'
      '• Wind Speed: ${optimalWind.toStringAsFixed(1)} m/s\n'
      '• Peak activity time: ${_formatPeakTime(peakTime)}\n\n'
      'Plan hive management activities and inspections outside of peak foraging hours to minimize disruption to the colony\'s foraging cycle. Research indicates that minimizing disturbances during optimal foraging periods can increase honey production by 15-20%.'
    );
    
    // 2. Time-based foraging pattern advisory
    final periodData = analysisData['periodCounts'] as Map<String, dynamic>? ?? {};
    if (periodData.isNotEmpty) {
      String bestPeriod = 'unknown';
      double maxActivity = 0;
      
      periodData.forEach((period, data) {
        final totalActivity = data['totalActivity'] ?? 0.0;
        if (totalActivity > maxActivity) {
          maxActivity = totalActivity;
          bestPeriod = period;
        }
      });
      
      advisories.add(
        'FORAGING TIMING ADVISORY:\n\n'
        'Your hive shows highest foraging activity during ${_formatPeriod(bestPeriod)}.\n\n'
        'Research indicates that honey bee foraging patterns are closely tied to daily floral nectar rhythms. Consider:\n'
        '• Placing hives where morning sun will warm them early, encouraging earlier foraging\n'
        '• Ensuring a water source is available within 100 meters of the hive\n'
        '• Observing which plant species are being visited during peak activity times\n'
        '• Timing supplemental feeding to avoid interfering with natural foraging patterns'
      );
    }
    
    // 3. Weather correlation advisory
    final tempCorr = analysisData['temperatureCorrelation'] as double? ?? 0.0;
    final humidityCorr = analysisData['humidityCorrelation'] as double? ?? 0.0;
    final windCorr = analysisData['windCorrelation'] as double? ?? 0.0;
    
    advisories.add(
      'WEATHER IMPACT ANALYSIS:\n\n'
      'Analysis shows your colony\'s foraging activity is:\n'
      '• ${_correlationDescription(tempCorr)} temperature\n'
      '• ${_correlationDescription(humidityCorr)} humidity\n'
      '• ${_correlationDescription(windCorr)} wind speed\n\n'
      'Bees typically forage when temperatures are between 12-40°C, with optimal activity around 20-30°C. They reduce activity in high winds (>15-20 km/h) and high humidity, which affects nectar concentration and pollen collection efficiency.'
    );
    
    // 4. Seasonal foraging recommendations
    final currentSeason = _getCurrentSeason();
    advisories.add(
      'SEASONAL FORAGING ADVISORY:\n\n'
      'Based on scientific literature and your hive\'s performance patterns during $currentSeason:\n\n'
      '• Spring: Early-season pollen is crucial for brood rearing. Ensure diverse flowering plants with protein-rich pollen (>18% protein content) during this period.\n\n'
      '• Summer: During peak temperatures, provide adequate water sources and some afternoon shade to prevent overheating and maintain foraging activity.\n\n'
      '• Autumn: Watch for changes in foraging patterns as temperatures decrease. Excessive foraging in warm autumn days can deplete winter nurse bees.\n\n'
      '• Winter: Monitor for unusual winter activity, which may indicate food shortage or disease issues.'
    );
    
    // 5. Forage improvement advisory
    advisories.add(
      'FORAGE IMPROVEMENT RECOMMENDATIONS:\n\n'
      'To enhance foraging efficiency and nutrition:\n\n'
      '• Diversify floral resources: Research shows honey bees select high-protein pollen sources when available. Ensure diverse flowering plants with protein content >15% for optimal colony development.\n\n'
      '• Stagger blooming periods: Plant species with sequential blooming to maintain consistent forage throughout the active season.\n\n'
      '• Create microclimates: Windbreaks and sheltered areas can extend foraging in suboptimal weather conditions.\n\n'
      '• Consider forage distance: Studies show that longer foraging distances (>1 km) result in less efficient resource collection. Locate colonies within 500m of primary forage when possible.'
    );
    
    // 6. Colony management advisory based on foraging patterns
    advisories.add(
      'COLONY MANAGEMENT BASED ON FORAGING PATTERNS:\n\n'
      'Your colony\'s foraging data provides insights for management:\n\n'
      '• A healthy ratio of returning to departing bees indicates good colony health\n'
      '• If pollen collection is low during favorable weather, evaluate nearby floral resources or consider nutritional supplements\n'
      '• Monitor for sudden changes in foraging patterns, which may indicate queen issues, disease, or environmental stressors\n'
      '• Higher morning activity compared to evening suggests good colony vigor; the reverse may indicate issues requiring inspection'
    );
    
    // 7. Generate productivity optimization advisory based on efficiency metrics
    if (efficiencyMetrics.isNotEmpty) {
      // Find patterns in the most efficient days
      final topDays = _getTopEfficientDays(efficiencyMetrics, 5);
      final avgTempTopDays = topDays.map((m) => m.temperature).reduce((a, b) => a + b) / topDays.length;
      final avgHumidityTopDays = topDays.map((m) => m.humidity).reduce((a, b) => a + b) / topDays.length;
      
      advisories.add(
        'PRODUCTIVITY OPTIMIZATION:\n\n'
        'Analysis of your most productive foraging days reveals:\n\n'
        '• Your colony performs best at temperatures around ${avgTempTopDays.toStringAsFixed(1)}°C\n'
        '• Optimal humidity levels are around ${avgHumidityTopDays.toStringAsFixed(0)}%\n'
        '• Peak foraging efficiency occurs during ${_formatPeakTime(peakTime)}\n\n'
        'Consider temporarily reducing hive entrance size during high wind days to maintain internal hive temperature. Studies show this simple adjustment can increase foraging efficiency by up to 12% during windy conditions.'
      );
    }
    
    return advisories;
  }
  
  /// Format peak time periods
  static String _formatPeakTime(String period) {
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
  
  /// Format time periods in sentence form
  static String _formatPeriod(String period) {
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
  
  /// Generate a description of correlation strength and direction
  static String _correlationDescription(double correlation) {
    final absCorr = correlation.abs();
    String strength;
    String direction = correlation >= 0 ? 'positively correlated with' : 'negatively correlated with';
    
    if (absCorr >= 0.7) {
      strength = 'strongly';
    } else if (absCorr >= 0.4) {
      strength = 'moderately';
    } else if (absCorr >= 0.2) {
      strength = 'weakly';
    } else {
      return 'not significantly correlated with';
    }
    
    return '$strength $direction';
  }
  
  /// Get current season based on date
  static String _getCurrentSeason() {
    final now = DateTime.now();
    final month = now.month;
    
    if (month >= 3 && month <= 5) {
      return 'Spring';
    } else if (month >= 6 && month <= 8) {
      return 'Summer';
    } else if (month >= 9 && month <= 11) {
      return 'Autumn';
    } else {
      return 'Winter';
    }
  }
  
  /// Get top efficient days from a list of metrics
  static List<ForagingEfficiencyMetric> _getTopEfficientDays(
    List<ForagingEfficiencyMetric> metrics, 
    int count,
  ) {
    // Sort by efficiency score (descending)
    final sorted = List<ForagingEfficiencyMetric>.from(metrics)
      ..sort((a, b) => b.efficiencyScore.compareTo(a.efficiencyScore));
    
    // Return top N (or all if less than N)
    return sorted.take(count).toList();
  }
  
  /// Generate an advisory customized for a specific date
  static String generateDailyAdvisory(
    DateTime date,
    Map<String, dynamic> analysisData,
    Map<DateTime, WeatherData> forecastData,
  ) {
    // Get forecast for the date
    final forecast = forecastData[DateTime(date.year, date.month, date.day, 12)] ?? 
                    WeatherData(
                      timestamp: date, 
                      temperature: 25.0, 
                      humidity: 60.0, 
                      windSpeed: 2.0,
                    );
    
    // Get optimal conditions
    final optimalConditions = analysisData['optimalConditions'] as Map<String, dynamic>? ?? {};
    final optimalTemp = optimalConditions['temperature'] ?? 25.0;
    final optimalHumidity = optimalConditions['humidity'] ?? 60.0;
    final optimalWind = optimalConditions['wind'] ?? 2.0;
    
    // Calculate expected foraging conditions
    final tempDiff = (forecast.temperature - optimalTemp).abs();
    final humidityDiff = (forecast.humidity - optimalHumidity).abs();
    final windDiff = (forecast.windSpeed - optimalWind).abs();
    
    // Generate descriptive labels
    String forecastRating;
    String recommendations;
    
    if (tempDiff <= 3 && humidityDiff <= 10 && windDiff <= 1) {
      forecastRating = 'Excellent';
      recommendations = 
        '• Expect peak foraging activity\n'
        '• Ideal day for colony inspections after peak foraging\n'
        '• Good opportunity to observe for signs of disease or pests\n'
        '• Consider adding honey supers if nectar flow is strong';
    } else if (tempDiff <= 5 && humidityDiff <= 15 && windDiff <= 2) {
      forecastRating = 'Good';
      recommendations = 
        '• Good foraging conditions expected\n'
        '• Monitor water source availability\n'
        '• Regular hive maintenance appropriate\n'
        '• Consider harvesting if honey frames are capped';
    } else if (tempDiff <= 8 && humidityDiff <= 20 && windDiff <= 4) {
      forecastRating = 'Moderate';
      recommendations = 
        '• Moderate foraging expected\n'
        '• Consider reducing hive entrance if winds increase\n'
        '• Good day for quick inspections\n'
        '• Ensure adequate ventilation if humidity is high';
    } else {
      forecastRating = 'Poor';
      recommendations = 
        '• Limited foraging activity expected\n'
        '• Consider supplemental feeding if prolonged poor conditions\n'
        '• Postpone major hive manipulations\n'
        '• Monitor for unusual behavior that might indicate stress';
    }
    
    return 'DAILY ADVISORY FOR ${DateFormat('EEEE, MMMM d').format(date)}:\n\n'
      'Weather Forecast:\n'
      '• Temperature: ${forecast.temperature.toStringAsFixed(1)}°C\n'
      '• Humidity: ${forecast.humidity.toStringAsFixed(0)}%\n'
      '• Wind Speed: ${forecast.windSpeed.toStringAsFixed(1)} m/s\n\n'
      'Expected Foraging Conditions: $forecastRating\n\n'
      'Recommendations:\n'
      '$recommendations';
  }
}
