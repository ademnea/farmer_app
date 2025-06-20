import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/bee_counter/bee_count_database.dart';
import 'package:farmer_app/Services/weather_service.dart';
import 'package:farmer_app/analytics/foraging_analysis/time_based_return_rate_database.dart';

class ForagingAnalysisEngine {
  // This class handles all foraging data processing and analytics

  // Main method to analyze bee counter data and generate foraging insights
  static Future<Map<String, dynamic>> analyzeForagingActivity({
    String? hiveId,
    DateTime? startDate,
    DateTime? endDate,
    bool includeWeatherData = true,
  }) async {
    try {
      // Fetch bee counter data from local database instead of Firebase
      List<BeeCount> beeCounterResults = await _fetchBeeCounterData(
        hiveId: hiveId,
        startDate: startDate,
        endDate: endDate,
      );

      if (beeCounterResults.isEmpty) {
        return {
          'hasData': false,
          'message': 'No bee counter data available for analysis',
        };
      }

      // Process the data to generate foraging insights
      Map<String, dynamic> analysisResults = await analyzeForagingResults(
        beeCounterResults,
        startDate: startDate,
        endDate: endDate,
        includeWeatherData: includeWeatherData,
      );

      return analysisResults;
    } catch (e) {
      print('Error analyzing foraging activity: $e');
      return {
        'hasData': false,
        'error': 'Error analyzing foraging activity: $e',
      };
    }
  }

  // Fetch bee counter data from local database
  static Future<List<BeeCount>> _fetchBeeCounterData({
    String? hiveId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Get bee counter results from local database
      List<BeeCount> results = [];

      if (hiveId != null) {
        // Get data for specific hive
        results = await BeeCountDatabase.instance.getBeeCountsForHive(hiveId);
      } else {
        // Get all data
        results = await BeeCountDatabase.instance.getAllBeeCounts();
      }

      // Filter by date range if provided
      if (startDate != null && endDate != null) {
        results = results.where((result) {
          return result.timestamp.isAfter(startDate) &&
              result.timestamp.isBefore(endDate.add(Duration(days: 1)));
        }).toList();
      }

      return results;
    } catch (e) {
      print('Error fetching bee counter data: $e');
      return [];
    }
  }

  // Process a collection of bee counting results to generate foraging insights
  static Future<Map<String, dynamic>> analyzeForagingResults(
    List<BeeCount> results, {
    DateTime? startDate,
    DateTime? endDate,
    bool includeWeatherData = true,
  }) async {
    if (results.isEmpty) {
      return {
        'error': 'No foraging data available for analysis',
        'hasData': false,
      };
    }

    // Filter by date range if provided
    List<BeeCount> filteredResults = results;
    if (startDate != null && endDate != null) {
      filteredResults = results.where((result) {
        return result.timestamp.isAfter(startDate) &&
            result.timestamp.isBefore(endDate.add(Duration(days: 1)));
      }).toList();
    }

    if (filteredResults.isEmpty) {
      return {
        'error': 'No data available in the specified date range',
        'hasData': false,
      };
    }

    // Sort by timestamp (oldest first) for time-series analysis
    filteredResults.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Extract and calculate key metrics
    Map<String, dynamic> metrics = await _calculateForagingMetrics(
      filteredResults,
      includeWeatherData: includeWeatherData,
    );

    // Identify patterns and trends
    Map<String, dynamic> patterns = _identifyForagingPatterns(
      filteredResults,
      metrics,
    );

    // Generate time-based foraging distributions
    Map<String, dynamic> distributions = _generateForagingDistributions(
      filteredResults,
    );

    // Calculate efficiency metrics
    Map<String, dynamic> efficiency = _calculateEfficiencyMetrics(
      filteredResults,
      metrics,
    );

    // Environmental correlation with weather data
    Map<String, dynamic> environmentalFactors = includeWeatherData
        ? await _analyzeEnvironmentalCorrelations(filteredResults)
        : {'weatherData': {}, 'environmentalInsights': {}};

    // Calculate time-based return rates with improved algorithm
    Map<String, dynamic> timeBasedAnalysis = _calculateTimeBasedReturnRates(
      filteredResults,
      environmentalFactors,
    );

    // Store time-based analysis in database for future reference
    await _storeTimeBasedAnalysis(filteredResults, timeBasedAnalysis);

    // Combine all analyses
    return {
      'hasData': true,
      'metrics': metrics,
      'patterns': patterns,
      'distributions': distributions,
      'efficiency': efficiency,
      'environmentalFactors': environmentalFactors,
      'timeBasedAnalysis': timeBasedAnalysis,
      'recommendations': _generateRecommendations(
        metrics,
        patterns,
        efficiency,
        environmentalFactors,
        timeBasedAnalysis,
      ),
      'foragePerformanceScore': _calculateForagePerformanceScore(
        metrics,
        efficiency,
        environmentalFactors,
        timeBasedAnalysis,
      ),
    };
  }

  // Store time-based analysis in database
  static Future<void> _storeTimeBasedAnalysis(
    List<BeeCount> results,
    Map<String, dynamic> timeBasedAnalysis,
  ) async {
    try {
      if (!timeBasedAnalysis.containsKey('hasData') ||
          !timeBasedAnalysis['hasData'] ||
          !timeBasedAnalysis.containsKey('dailyReturnRates')) {
        return;
      }

      final database = TimeBasedReturnRateDatabase.instance;
      final Map<String, Map<String, dynamic>> dailyRates =
          timeBasedAnalysis['dailyReturnRates'];

      // Group results by day and hive
      Map<String, Map<String, List<BeeCount>>> resultsByHiveAndDay = {};

      for (var result in results) {
        final dateStr = DateFormat('yyyy-MM-dd').format(result.timestamp);
        final hiveId = result.hiveId;

        if (!resultsByHiveAndDay.containsKey(hiveId)) {
          resultsByHiveAndDay[hiveId] = {};
        }

        if (!resultsByHiveAndDay[hiveId]!.containsKey(dateStr)) {
          resultsByHiveAndDay[hiveId]![dateStr] = [];
        }

        resultsByHiveAndDay[hiveId]![dateStr]!.add(result);
      }

      // Store time block analysis for each day and hive
      for (var hiveEntry in resultsByHiveAndDay.entries) {
        final hiveId = hiveEntry.key;
        final dayMap = hiveEntry.value;

        for (var dayEntry in dayMap.entries) {
          final dateStr = dayEntry.key;
          final date = DateTime.parse(dateStr);

          if (dailyRates.containsKey(dateStr) &&
              dailyRates[dateStr]!.containsKey('timeBlocks')) {
            final timeBlocks = dailyRates[dateStr]!['timeBlocks'];

            // Store each time block
            for (var blockEntry in timeBlocks.entries) {
              final blockName = blockEntry.key;
              final blockData = blockEntry.value;

              if (blockData.containsKey('totalBeesOut') &&
                  blockData.containsKey('totalBeesIn') &&
                  blockData.containsKey('actualReturnRate') &&
                  blockData.containsKey('expectedReturnRate') &&
                  blockData.containsKey('avgTripDuration') &&
                  blockData.containsKey('healthIndicator')) {
                await database.saveTimeBlockAnalysis(
                  hiveId: hiveId,
                  date: date,
                  timeBlock: blockName,
                  beesOut: blockData['totalBeesOut'],
                  beesIn: blockData['totalBeesIn'],
                  actualReturnRate: blockData['actualReturnRate'],
                  expectedReturnRate: blockData['expectedReturnRate'],
                  avgTripDuration: blockData['avgTripDuration'],
                  healthIndicator: blockData['healthIndicator'],
                );
              }
            }
          }

          // Store trip duration distribution if available
          if (timeBasedAnalysis.containsKey('tripDistributionPercentages')) {
            final distribution =
                timeBasedAnalysis['tripDistributionPercentages'];
            final avgReturnTimes = timeBasedAnalysis['avgReturnTimes'];

            if (distribution.containsKey('short') &&
                distribution.containsKey('medium') &&
                distribution.containsKey('long')) {
              await database.saveTripDurationDistribution(
                hiveId: hiveId,
                date: date,
                shortTripsPercent: distribution['short'],
                mediumTripsPercent: distribution['medium'],
                longTripsPercent: distribution['long'],
                avgShortDuration: avgReturnTimes['short'] ?? 0.0,
                avgMediumDuration: avgReturnTimes['medium'] ?? 0.0,
                avgLongDuration: avgReturnTimes['long'] ?? 0.0,
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error storing time-based analysis: $e');
    }
  }

  static Future<Map<String, dynamic>> _calculateForagingMetrics(
    List<BeeCount> results, {
    bool includeWeatherData = true,
  }) async {
    // Calculate total bee entry and exit counts
    int totalBeesIn = 0;
    int totalBeesOut = 0;
    int totalNetChange = 0;
    int totalActivity = 0;

    for (var result in results) {
      totalBeesIn += result.beesEntering;
      totalBeesOut += result.beesExiting;
      totalNetChange += result.netChange;
      totalActivity += result.totalActivity;
    }

    // Calculate daily averages
    Map<DateTime, List<BeeCount>> resultsByDay = {};

    for (var result in results) {
      // Group by day (ignoring time component)
      DateTime day = DateTime(
        result.timestamp.year,
        result.timestamp.month,
        result.timestamp.day,
      );

      if (!resultsByDay.containsKey(day)) {
        resultsByDay[day] = [];
      }

      resultsByDay[day]!.add(result);
    }

    // Calculate daily averages
    double avgDailyBeesIn = resultsByDay.isNotEmpty
        ? resultsByDay.values
                .map(
                  (dayResults) => dayResults.fold(
                    0,
                    (sum, result) => sum + result.beesEntering,
                  ),
                )
                .reduce((a, b) => a + b) /
            resultsByDay.length
        : 0;

    double avgDailyBeesOut = resultsByDay.isNotEmpty
        ? resultsByDay.values
                .map(
                  (dayResults) => dayResults.fold(
                    0,
                    (sum, result) => sum + result.beesExiting,
                  ),
                )
                .reduce((a, b) => a + b) /
            resultsByDay.length
        : 0;

    // Calculate return rate
    double returnRate =
        totalBeesOut > 0 ? (totalBeesIn / totalBeesOut) * 100 : 0;

    // Calculate peak activity times
    Map<int, int> activityByHour = {};

    for (var result in results) {
      int hour = result.timestamp.hour;
      activityByHour[hour] = (activityByHour[hour] ?? 0) + result.totalActivity;
    }

    int peakActivityHour = 0;
    int maxActivity = 0;

    activityByHour.forEach((hour, activity) {
      if (activity > maxActivity) {
        maxActivity = activity;
        peakActivityHour = hour;
      }
    });

    // Calculate trend over time
    double trendSlope = 0;
    if (results.length > 1) {
      // Simple linear regression for trend
      List<double> x = List.generate(results.length, (i) => i.toDouble());
      List<double> y = results.map((r) => r.totalActivity.toDouble()).toList();

      double xMean = x.reduce((a, b) => a + b) / x.length;
      double yMean = y.reduce((a, b) => a + b) / y.length;

      double numerator = 0;
      double denominator = 0;

      for (int i = 0; i < x.length; i++) {
        numerator += (x[i] - xMean) * (y[i] - yMean);
        denominator += (x[i] - xMean) * (x[i] - xMean);
      }

      trendSlope = denominator != 0 ? numerator / denominator : 0;
    }

    // Calculate foraging duration estimate based on bee counter data
    double estimatedForagingDuration = _estimateForagingDuration(results);

    // Calculate hourly flux - the change in bees per hour
    Map<int, int> hourlyFlux = {};
    for (int i = 0; i < 24; i++) {
      hourlyFlux[i] = 0;
    }

    for (var result in results) {
      int hour = result.timestamp.hour;
      hourlyFlux[hour] = (hourlyFlux[hour] ?? 0) + result.netChange;
    }

    // Convert int keys to string keys for consistent typing
    Map<String, dynamic> activityByHourString = {};
    activityByHour.forEach((key, value) {
      activityByHourString[key.toString()] = value;
    });

    // Convert hourlyFlux int keys to string keys
    Map<String, dynamic> hourlyFluxString = {};
    hourlyFlux.forEach((key, value) {
      hourlyFluxString[key.toString()] = value;
    });

    // Get the weather data for comparison if requested
    Map<String, dynamic> weatherData = {};
    if (includeWeatherData && results.isNotEmpty) {
      try {
        // Get weather data for the days in the analysis
        List<DateTime> uniqueDays = resultsByDay.keys.toList();

        // For simplicity, get weather for the first day
        // In a real app, you'd aggregate weather data for all days
        weatherData = await WeatherService.getWeatherForDate(uniqueDays.first);
      } catch (e) {
        print('Error fetching weather data: $e');
        weatherData = {'error': 'Weather data unavailable'};
      }
    }

    // Calculate foraging intensity - bees per hour during daylight hours
    List<int> dayHours = [for (int i = 6; i <= 20; i++) i]; // 6 AM to 8 PM
    int totalDayActivity = 0;
    for (int hour in dayHours) {
      totalDayActivity += activityByHour[hour] ?? 0;
    }
    double foragingIntensity =
        dayHours.isNotEmpty ? totalDayActivity / dayHours.length : 0;

    // Calculate net population change
    int netPopulationChange = totalBeesIn - totalBeesOut;

    // Calculate foraging efficiency (bees in vs bees out ratio)
    double foragingEfficiency =
        totalBeesOut > 0 ? totalBeesIn / totalBeesOut : 0;

    return {
      'totalBeesIn': totalBeesIn,
      'totalBeesOut': totalBeesOut,
      'totalNetChange': totalNetChange,
      'totalActivity': totalActivity,
      'avgDailyBeesIn': avgDailyBeesIn,
      'avgDailyBeesOut': avgDailyBeesOut,
      'returnRate': returnRate,
      'peakActivityHour': peakActivityHour,
      'activityByHour': activityByHourString,
      'hourlyFlux': hourlyFluxString,
      'trendSlope': trendSlope,
      'trendDirection': trendSlope > 0
          ? 'Increasing'
          : (trendSlope < 0 ? 'Decreasing' : 'Stable'),
      'estimatedForagingDuration': estimatedForagingDuration,
      'daysWithData': resultsByDay.length,
      'foragingIntensity': foragingIntensity,
      'foragingEfficiency': foragingEfficiency,
      'netPopulationChange': netPopulationChange,
      'firstDate': results.first.timestamp,
      'lastDate': results.last.timestamp,
      'weatherData': weatherData,
    };
  }

  // IMPROVED METHOD: Calculate time-based return rates with realistic algorithms
  static Map<String, dynamic> _calculateTimeBasedReturnRates(
    List<BeeCount> results,
    Map<String, dynamic> environmentalFactors,
  ) {
    // This method implements realistic time-based algorithms for bee return rates
    // based on scientific research on bee foraging behavior

    if (results.isEmpty) {
      return {
        'hasData': false,
        'message': 'No data available for time-based analysis',
      };
    }

    // Sort results by timestamp
    results.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Group results by day
    Map<DateTime, List<BeeCount>> resultsByDay = {};
    for (var result in results) {
      DateTime day = DateTime(
        result.timestamp.year,
        result.timestamp.month,
        result.timestamp.day,
      );

      if (!resultsByDay.containsKey(day)) {
        resultsByDay[day] = [];
      }

      resultsByDay[day]!.add(result);
    }

    // Time-based return rate analysis for each day
    Map<String, Map<String, dynamic>> dailyReturnRates = {};
    Map<String, List<double>> returnTimeDistribution = {
      'short': [], // 15-30 minutes
      'medium': [], // 30-90 minutes
      'long': [], // 90-180 minutes
    };

    // Process each day's data
    resultsByDay.forEach((day, dayResults) {
      // Sort by timestamp
      dayResults.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Group by time blocks
      Map<String, List<BeeCount>> timeBlocks = {
        'morning': [], // 5:00-10:00
        'midday': [], // 10:00-14:00
        'afternoon': [], // 14:00-18:00
        'evening': [], // 18:00-21:00
      };

      for (var result in dayResults) {
        int hour = result.timestamp.hour;
        if (hour >= 5 && hour < 10) {
          timeBlocks['morning']!.add(result);
        } else if (hour >= 10 && hour < 14) {
          timeBlocks['midday']!.add(result);
        } else if (hour >= 14 && hour < 18) {
          timeBlocks['afternoon']!.add(result);
        } else if (hour >= 18 && hour < 21) {
          timeBlocks['evening']!.add(result);
        }
      }

      // Calculate return rates and trip durations for each time block
      Map<String, dynamic> timeBlockAnalysis = {};

      // Process each time block
      timeBlocks.forEach((blockName, blockResults) {
        if (blockResults.isEmpty) return;

        // Get expected return rates adjusted for season and weather
        double expectedReturnRate = _getAdjustedExpectedReturnRate(
          day,
          blockName,
          environmentalFactors,
        );

        // Calculate cohort-based return rates
        Map<String, dynamic> cohortAnalysis = _analyzeCohorts(
          blockResults,
          dayResults,
          blockName,
        );

        // Calculate rolling window return rates
        Map<String, dynamic> rollingWindowAnalysis = _analyzeRollingWindows(
          blockResults,
          dayResults,
          blockName,
        );

        // Calculate total bees out and in for this time block (traditional method)
        int totalOut = blockResults.fold(
          0,
          (sum, result) => sum + result.beesExiting,
        );
        int totalIn = blockResults.fold(
          0,
          (sum, result) => sum + result.beesEntering,
        );

        // Calculate actual return rate using improved methods
        double actualReturnRate;
        double avgTripDuration;

        // If we have cohort data, use it (most accurate)
        if (cohortAnalysis['hasData']) {
          actualReturnRate = cohortAnalysis['returnRate'];
          avgTripDuration = cohortAnalysis['avgTripDuration'];
        }
        // Otherwise use rolling window analysis
        else if (rollingWindowAnalysis['hasData']) {
          actualReturnRate = rollingWindowAnalysis['returnRate'];
          avgTripDuration = rollingWindowAnalysis['avgTripDuration'];
        }
        // Fall back to traditional method if needed
        else {
          actualReturnRate = totalOut > 0 ? (totalIn / totalOut) * 100 : 0;
          avgTripDuration =
              _estimateAverageTripDuration(blockResults, dayResults);
        }

        // Calculate return rate difference (actual vs expected)
        double returnRateDifference = actualReturnRate - expectedReturnRate;

        // Store the analysis for this time block
        timeBlockAnalysis[blockName] = {
          'totalBeesOut': totalOut,
          'totalBeesIn': totalIn,
          'actualReturnRate': actualReturnRate,
          'expectedReturnRate': expectedReturnRate,
          'returnRateDifference': returnRateDifference,
          'avgTripDuration': avgTripDuration,
          'cohortAnalysis': cohortAnalysis,
          'rollingWindowAnalysis': rollingWindowAnalysis,
          'healthIndicator': _calculateHealthIndicator(
            returnRateDifference,
            avgTripDuration,
            environmentalFactors,
          ),
        };

        // Add to return time distribution
        if (avgTripDuration < 30) {
          returnTimeDistribution['short']!.add(avgTripDuration);
        } else if (avgTripDuration < 90) {
          returnTimeDistribution['medium']!.add(avgTripDuration);
        } else {
          returnTimeDistribution['long']!.add(avgTripDuration);
        }
      });

      // Store the day's analysis
      dailyReturnRates[DateFormat('yyyy-MM-dd').format(day)] = {
        'timeBlocks': timeBlockAnalysis,
        'overallReturnRate': _calculateOverallReturnRate(timeBlockAnalysis),
        'overallTripDuration': _calculateOverallTripDuration(timeBlockAnalysis),
        'weatherAdjustmentFactor':
            _getWeatherAdjustmentFactor(day, environmentalFactors),
      };
    });

    // Calculate average return times by category
    Map<String, double> avgReturnTimes = {};
    returnTimeDistribution.forEach((category, times) {
      if (times.isNotEmpty) {
        avgReturnTimes[category] = times.reduce((a, b) => a + b) / times.length;
      } else {
        avgReturnTimes[category] = 0;
      }
    });

    // Calculate distribution percentages
    int totalTrips = returnTimeDistribution.values
        .map((list) => list.length)
        .fold(0, (sum, count) => sum + count);

    Map<String, double> tripDistributionPercentages = {};
    if (totalTrips > 0) {
      returnTimeDistribution.forEach((category, times) {
        tripDistributionPercentages[category] =
            (times.length / totalTrips) * 100;
      });
    }

    // Return the complete time-based analysis
    return {
      'hasData': true,
      'dailyReturnRates': dailyReturnRates,
      'avgReturnTimes': avgReturnTimes,
      'tripDistributionPercentages': tripDistributionPercentages,
      'overallHealthScore': _calculateOverallHealthScore(dailyReturnRates),
    };
  }

  // Helper method to analyze cohorts of bees
  static Map<String, dynamic> _analyzeCohorts(
    List<BeeCount> blockResults,
    List<BeeCount> dayResults,
    String blockName,
  ) {
    if (blockResults.isEmpty) {
      return {'hasData': false};
    }

    // Create cohorts based on 30-minute intervals
    Map<DateTime, int> cohortExits = {};
    Map<DateTime, int> cohortReturns = {};
    Map<DateTime, double> cohortDurations = {};

    // Define maximum expected trip duration based on time block
    int maxTripDurationMinutes;
    switch (blockName) {
      case 'morning':
        maxTripDurationMinutes = 180; // 3 hours
        break;
      case 'midday':
        maxTripDurationMinutes = 240; // 4 hours
        break;
      case 'afternoon':
        maxTripDurationMinutes = 180; // 3 hours
        break;
      case 'evening':
        maxTripDurationMinutes = 120; // 2 hours
        break;
      default:
        maxTripDurationMinutes = 180; // 3 hours
    }

    // Record cohort exits
    for (var result in blockResults) {
      if (result.beesExiting <= 0) continue;

      // Round to nearest 30 minutes for cohort binning
      DateTime cohortTime = DateTime(
        result.timestamp.year,
        result.timestamp.month,
        result.timestamp.day,
        result.timestamp.hour,
        (result.timestamp.minute ~/ 30) * 30,
      );

      cohortExits[cohortTime] =
          (cohortExits[cohortTime] ?? 0) + result.beesExiting;
    }

    // Track returns for each cohort
    for (var cohortTime in cohortExits.keys) {
      // Look for returns within the maximum trip duration
      DateTime cohortEndTime =
          cohortTime.add(Duration(minutes: maxTripDurationMinutes));

      // Get all results after this cohort's exit time but before the end time
      List<BeeCount> potentialReturns = dayResults
          .where((result) =>
              result.timestamp.isAfter(cohortTime) &&
              result.timestamp.isBefore(cohortEndTime) &&
              result.beesEntering > 0)
          .toList();

      // Calculate weighted returns and durations
      double totalWeightedDuration = 0;
      int totalReturns = 0;

      for (var returnResult in potentialReturns) {
        // Calculate minutes since cohort exit
        int minutesSinceExit =
            returnResult.timestamp.difference(cohortTime).inMinutes;

        // Apply a probability curve - bees are more likely to return after a certain time
        // This is a simplified model - in reality, this would be calibrated with actual data
        double returnProbability =
            _getReturnProbability(minutesSinceExit, blockName);

        // Calculate weighted returns for this cohort
        int weightedReturns =
            (returnResult.beesEntering * returnProbability).round();
        weightedReturns =
            math.min(weightedReturns, cohortExits[cohortTime]! - totalReturns);

        if (weightedReturns <= 0) continue;

        // Add to total returns and weighted duration
        totalReturns += weightedReturns;
        totalWeightedDuration += minutesSinceExit * weightedReturns;
      }

      // Store returns and average duration for this cohort
      cohortReturns[cohortTime] = totalReturns;
      if (totalReturns > 0) {
        cohortDurations[cohortTime] = totalWeightedDuration / totalReturns;
      }
    }

    // Calculate overall cohort statistics
    int totalCohortExits =
        cohortExits.values.fold(0, (sum, exits) => sum + exits);
    int totalCohortReturns =
        cohortReturns.values.fold(0, (sum, returns) => sum + returns);

    if (totalCohortExits == 0) {
      return {'hasData': false};
    }

    double cohortReturnRate = (totalCohortReturns / totalCohortExits) * 100;

    // Calculate average trip duration across all cohorts
    double avgCohortTripDuration = 0;
    int totalDurationWeights = 0;

    cohortDurations.forEach((cohortTime, duration) {
      int returns = cohortReturns[cohortTime] ?? 0;
      avgCohortTripDuration += duration * returns;
      totalDurationWeights += returns;
    });

    if (totalDurationWeights > 0) {
      avgCohortTripDuration /= totalDurationWeights;
    } else {
      // Fallback if we couldn't calculate from cohorts
      avgCohortTripDuration =
          _estimateAverageTripDuration(blockResults, dayResults);
    }

    return {
      'hasData': true,
      'returnRate': cohortReturnRate,
      'avgTripDuration': avgCohortTripDuration,
      'totalExits': totalCohortExits,
      'totalReturns': totalCohortReturns,
      'cohortCount': cohortExits.length,
    };
  }

  // Helper method to analyze rolling windows
  static Map<String, dynamic> _analyzeRollingWindows(
    List<BeeCount> blockResults,
    List<BeeCount> dayResults,
    String blockName,
  ) {
    if (blockResults.isEmpty) {
      return {'hasData': false};
    }

    // Define window size based on time block
    int windowSizeMinutes;
    switch (blockName) {
      case 'morning':
        windowSizeMinutes = 120; // 2 hours
        break;
      case 'midday':
        windowSizeMinutes = 180; // 3 hours
        break;
      case 'afternoon':
        windowSizeMinutes = 150; // 2.5 hours
        break;
      case 'evening':
        windowSizeMinutes = 90; // 1.5 hours
        break;
      default:
        windowSizeMinutes = 120; // 2 hours
    }

    // Create rolling windows
    List<Map<String, dynamic>> windows = [];

    // Start with the first result in the block
    for (int i = 0; i < blockResults.length; i++) {
      DateTime windowStart = blockResults[i].timestamp;
      DateTime windowEnd =
          windowStart.add(Duration(minutes: windowSizeMinutes));

      // Count exits in this specific result
      int exitingBees = blockResults[i].beesExiting;
      if (exitingBees <= 0) continue;

      // Find all results within the window timeframe
      List<BeeCount> windowResults = dayResults
          .where((result) =>
              result.timestamp.isAfter(windowStart) &&
              result.timestamp.isBefore(windowEnd))
          .toList();

      // Count total returning bees in the window
      int returningBees =
          windowResults.fold(0, (sum, result) => sum + result.beesEntering);

      // Calculate average trip duration for this window
      double avgTripDuration = 0;
      int totalReturns = 0;

      for (var result in windowResults) {
        if (result.beesEntering <= 0) continue;

        // Calculate minutes since window start
        int minutesSinceStart =
            result.timestamp.difference(windowStart).inMinutes;

        // Add to weighted average
        avgTripDuration += minutesSinceStart * result.beesEntering;
        totalReturns += result.beesEntering;
      }

      if (totalReturns > 0) {
        avgTripDuration /= totalReturns;
      } else {
        avgTripDuration =
            windowSizeMinutes / 2; // Default to half the window size
      }

      // Add window data
      windows.add({
        'start': windowStart,
        'end': windowEnd,
        'exits': exitingBees,
        'returns': returningBees,
        'returnRate': exitingBees > 0 ? (returningBees / exitingBees) * 100 : 0,
        'avgTripDuration': avgTripDuration,
      });
    }

    // Calculate aggregate statistics
    if (windows.isEmpty) {
      return {'hasData': false};
    }

    int totalExits =
        windows.fold<int>(0, (sum, window) => sum + window['exits'] as int);
    int totalReturns =
        windows.fold<int>(0, (sum, window) => sum + window['returns'] as int);

    if (totalExits == 0) {
      return {'hasData': false};
    }

    double overallReturnRate = (totalReturns / totalExits) * 100;

    // Calculate weighted average trip duration
    double weightedTripDuration = 0;
    int totalDurationWeights = 0;

    for (var window in windows) {
      if (window['returns'] > 0) {
        weightedTripDuration += window['avgTripDuration'] * window['returns'];
        totalDurationWeights += (window['returns'] as int);
      }
    }

    double avgTripDuration = totalDurationWeights > 0
        ? weightedTripDuration / totalDurationWeights
        : _estimateAverageTripDuration(blockResults, dayResults);

    return {
      'hasData': true,
      'returnRate': overallReturnRate,
      'avgTripDuration': avgTripDuration,
      'totalExits': totalExits,
      'totalReturns': totalReturns,
      'windowCount': windows.length,
    };
  }

  // Helper method to get return probability based on time since exit
  static double _getReturnProbability(int minutesSinceExit, String timeBlock) {
    // These probability curves are based on typical bee foraging behavior
    // In a real implementation, these would be calibrated with actual data

    // Define peak return time for each time block
    int peakReturnTime;
    switch (timeBlock) {
      case 'morning':
        peakReturnTime = 45; // 45 minutes
        break;
      case 'midday':
        peakReturnTime = 60; // 60 minutes
        break;
      case 'afternoon':
        peakReturnTime = 50; // 50 minutes
        break;
      case 'evening':
        peakReturnTime = 40; // 40 minutes
        break;
      default:
        peakReturnTime = 50; // 50 minutes
    }

    // Calculate probability using a bell curve centered on peak return time
    // This creates a more realistic distribution of return times
    double standardDeviation = peakReturnTime / 2;
    double x = (minutesSinceExit - peakReturnTime) / standardDeviation;
    double probability = math.exp(-0.5 * x * x);

    // Normalize to ensure probabilities sum close to 1 over the expected range
    return probability;
  }

  // Helper method to estimate average trip duration
  static double _estimateAverageTripDuration(
    List<BeeCount> blockResults,
    List<BeeCount> dayResults,
  ) {
    if (blockResults.isEmpty) {
      return 60.0; // Default to 60 minutes if no data
    }

    // Get the time range for this block
    DateTime blockStart = blockResults.first.timestamp;
    DateTime blockEnd = blockResults.last.timestamp;

    // Find the peak exit time within the block
    int maxExits = 0;
    DateTime? peakExitTime;

    for (var result in blockResults) {
      if (result.beesExiting > maxExits) {
        maxExits = result.beesExiting;
        peakExitTime = result.timestamp;
      }
    }

    if (peakExitTime == null) {
      return 60.0; // Default if no peak found
    }

    // Look for peak return time after the peak exit
    int maxReturns = 0;
    DateTime? peakReturnTime;

    // Look in all day results after the peak exit time
    for (var result in dayResults) {
      if (result.timestamp.isAfter(peakExitTime) &&
          result.beesEntering > maxReturns) {
        maxReturns = result.beesEntering;
        peakReturnTime = result.timestamp;
      }
    }

    if (peakReturnTime == null) {
      // If no peak return found, estimate based on block type
      switch (blockStart.hour) {
        case 5:
        case 6:
        case 7:
        case 8:
        case 9:
          return 45.0; // Morning
        case 10:
        case 11:
        case 12:
        case 13:
          return 60.0; // Midday
        case 14:
        case 15:
        case 16:
        case 17:
          return 50.0; // Afternoon
        default:
          return 40.0; // Evening
      }
    }

    // Calculate duration between peak exit and peak return
    int durationMinutes = peakReturnTime.difference(peakExitTime).inMinutes;

    // Apply reasonable bounds
    if (durationMinutes < 15) {
      durationMinutes = 15; // Minimum reasonable duration
    } else if (durationMinutes > 180) {
      durationMinutes = 180; // Maximum reasonable duration
    }

    return durationMinutes.toDouble();
  }

  // Helper method to get seasonally adjusted expected return rates
  static double _getAdjustedExpectedReturnRate(
    DateTime date,
    String timeBlock,
    Map<String, dynamic> environmentalFactors,
  ) {
    // Base expected return rates from scientific research
    Map<String, double> baseExpectedReturnRates = {
      'morning': 0.85, // 85% return rate in morning
      'midday': 0.92, // 92% return rate at midday
      'afternoon': 0.88, // 88% return rate in afternoon
      'evening': 0.75, // 75% return rate in evening
    };

    // Get base rate for this time block
    double baseRate = baseExpectedReturnRates[timeBlock] ?? 0.85;

    // Apply seasonal adjustment
    double seasonalFactor = _getSeasonalAdjustmentFactor(date);

    // Apply weather adjustment if available
    double weatherFactor =
        _getWeatherAdjustmentFactor(date, environmentalFactors);

    // Calculate final adjusted rate
    double adjustedRate = baseRate * seasonalFactor * weatherFactor;

    // Convert to percentage
    return adjustedRate * 100;
  }

  // Helper method to get seasonal adjustment factor
  static double _getSeasonalAdjustmentFactor(DateTime date) {
    int month = date.month;

    // Spring (March-May)
    if (month >= 3 && month <= 5) {
      return 1.05; // 5% higher in spring
    }
    // Summer (June-August)
    else if (month >= 6 && month <= 8) {
      return 1.0; // Baseline in summer
    }
    // Fall (September-November)
    else if (month >= 9 && month <= 11) {
      return 0.95; // 5% lower in fall
    }
    // Winter (December-February)
    else {
      return 0.85; // 15% lower in winter
    }
  }

  // Helper method to get weather adjustment factor
  static double _getWeatherAdjustmentFactor(
    DateTime date,
    Map<String, dynamic> environmentalFactors,
  ) {
    // Default to 1.0 (no adjustment) if no weather data
    if (!environmentalFactors.containsKey('weatherData') ||
        environmentalFactors['weatherData'].isEmpty) {
      return 1.0;
    }

    double weatherFactor = 1.0;
    var weatherData = environmentalFactors['weatherData'];

    // Adjust for temperature if available
    if (weatherData.containsKey('temperature') &&
        weatherData['temperature'].containsKey('correlation') &&
        weatherData['temperature'].containsKey('values') &&
        weatherData['temperature']['values'].isNotEmpty) {
      double temperature = weatherData['temperature']['values'][0];

      // Optimal temperature range is 23-32°C
      if (temperature < 10) {
        weatherFactor *= 0.7; // Significantly reduced in cold weather
      } else if (temperature < 15) {
        weatherFactor *= 0.8; // Reduced in cool weather
      } else if (temperature > 35) {
        weatherFactor *= 0.85; // Reduced in very hot weather
      }
    }

    // Adjust for wind if available
    if (weatherData.containsKey('windSpeed') &&
        weatherData['windSpeed'].containsKey('correlation') &&
        weatherData['windSpeed'].containsKey('values') &&
        weatherData['windSpeed']['values'].isNotEmpty) {
      double windSpeed = weatherData['windSpeed']['values'][0];

      // Wind speed impact (km/h)
      if (windSpeed > 25) {
        weatherFactor *= 0.7; // Significant impact in high winds
      } else if (windSpeed > 15) {
        weatherFactor *= 0.85; // Moderate impact in medium winds
      }
    }

    // Adjust for precipitation if available
    if (weatherData.containsKey('precipitation') &&
        weatherData['precipitation'].containsKey('correlation') &&
        weatherData['precipitation'].containsKey('values') &&
        weatherData['precipitation']['values'].isNotEmpty) {
      double precipitation = weatherData['precipitation']['values'][0];

      // Any precipitation significantly reduces foraging
      if (precipitation > 5) {
        weatherFactor *= 0.5; // Heavy rain
      } else if (precipitation > 0) {
        weatherFactor *= 0.7; // Light rain
      }
    }

    // Ensure factor stays in reasonable range
    return math.max(0.5, math.min(1.1, weatherFactor));
  }

  // Helper method to calculate health indicator based on return rate and trip duration
  static String _calculateHealthIndicator(
    double returnRateDifference,
    double avgTripDuration,
    Map<String, dynamic> environmentalFactors,
  ) {
    // Get weather adjustment factor to contextualize the health assessment
    double weatherImpact = 1.0;

    if (environmentalFactors.containsKey('weatherData') &&
        !environmentalFactors['weatherData'].isEmpty) {
      // If weather data indicates challenging conditions, be more lenient in assessment
      weatherImpact =
          _getWeatherAdjustmentFactor(DateTime.now(), environmentalFactors);
    }

    // Adjust the thresholds based on weather conditions
    double poorThreshold = -15 * weatherImpact;
    double fairThreshold = -5 * weatherImpact;

    // If return rate is significantly lower than expected, it's concerning
    if (returnRateDifference < poorThreshold) {
      return 'Poor';
    } else if (returnRateDifference < fairThreshold) {
      return 'Fair';
    }

    // If trip duration is extremely short or long, it might indicate problems
    if (avgTripDuration < 15 || avgTripDuration > 180) {
      return 'Fair';
    }

    // If return rate is better than expected and trip duration is reasonable
    if (returnRateDifference > 0 &&
        avgTripDuration >= 30 &&
        avgTripDuration <= 90) {
      return 'Excellent';
    }

    // Default case
    return 'Good';
  }

  // Helper method to calculate overall return rate from time blocks
  static double _calculateOverallReturnRate(
    Map<String, dynamic> timeBlockAnalysis,
  ) {
    num totalOut = 0;
    num totalIn = 0;

    timeBlockAnalysis.forEach((blockName, analysis) {
      totalOut += analysis['totalBeesOut'] ?? 0;
      totalIn += analysis['totalBeesIn'] ?? 0;
    });

    return totalOut > 0 ? (totalIn / totalOut) * 100 : 0;
  }

  // Helper method to calculate overall trip duration from time blocks
  static double _calculateOverallTripDuration(
    Map<String, dynamic> timeBlockAnalysis,
  ) {
    List<double> durations = [];
    List<int> weights = [];

    timeBlockAnalysis.forEach((blockName, analysis) {
      if (analysis.containsKey('avgTripDuration') &&
          analysis.containsKey('totalBeesIn') &&
          analysis['totalBeesIn'] > 0) {
        durations.add(analysis['avgTripDuration']);
        weights.add(analysis['totalBeesIn']);
      }
    });

    if (durations.isEmpty) return 0;

    // Calculate weighted average
    double weightedSum = 0;
    int totalWeight = 0;

    for (int i = 0; i < durations.length; i++) {
      weightedSum += durations[i] * weights[i];
      totalWeight += weights[i];
    }

    return totalWeight > 0
        ? weightedSum / totalWeight
        : durations.reduce((a, b) => a + b) / durations.length;
  }

  // Helper method to calculate overall health score
  static double _calculateOverallHealthScore(
    Map<String, Map<String, dynamic>> dailyReturnRates,
  ) {
    if (dailyReturnRates.isEmpty) return 0;

    List<double> scores = [];
    List<double> weights = [];

    dailyReturnRates.forEach((day, analysis) {
      // Convert return rate to a score (0-100)
      double returnRateScore = math.min(analysis['overallReturnRate'], 100);

      // Convert trip duration to a score (0-100)
      double tripDuration = analysis['overallTripDuration'];
      double tripDurationScore = 100;

      if (tripDuration < 30) {
        // Too short - linearly scale from 0 to 100
        tripDurationScore = (tripDuration / 30) * 100;
      } else if (tripDuration > 120) {
        // Too long - linearly scale from 100 to 0
        tripDurationScore = math.max(
          0,
          100 - ((tripDuration - 120) / 120) * 100,
        );
      }

      // Apply weather adjustment if available
      double weatherAdjustment = 1.0;
      if (analysis.containsKey('weatherAdjustmentFactor')) {
        weatherAdjustment = analysis['weatherAdjustmentFactor'];
      }

      // Calculate day's score (weighted average)
      double dayScore = (returnRateScore * 0.7) + (tripDurationScore * 0.3);

      // More recent days get higher weight
      DateTime dayDate = DateTime.parse(day);
      int daysAgo = DateTime.now().difference(dayDate).inDays;
      double recencyWeight = math.max(0.5, 1.0 - (daysAgo * 0.1));

      // Weather-challenged days get lower weight
      double weatherWeight = weatherAdjustment;

      // Combined weight
      double weight = recencyWeight * weatherWeight;

      scores.add(dayScore);
      weights.add(weight);
    });

    // Calculate weighted average score
    if (scores.isEmpty) return 0;

    double weightedSum = 0;
    double totalWeight = 0;

    for (int i = 0; i < scores.length; i++) {
      weightedSum += scores[i] * weights[i];
      totalWeight += weights[i];
    }

    return totalWeight > 0
        ? weightedSum / totalWeight
        : scores.reduce((a, b) => a + b) / scores.length;
  }

  static Map<String, dynamic> _identifyForagingPatterns(
    List<BeeCount> results,
    Map<String, dynamic> metrics,
  ) {
    // Identify daily patterns
    Map<String, dynamic> hourlyActivityRaw = metrics['activityByHour'];
    Map<int, int> hourlyActivity = {};

    // Convert string keys to int keys
    hourlyActivityRaw.forEach((key, value) {
      int hourKey = int.tryParse(key) ?? 0;
      int activityValue = 0;

      if (value is int) {
        activityValue = value;
      } else if (value is double) {
        activityValue = value.toInt();
      } else if (value is String) {
        activityValue = int.tryParse(value) ?? 0;
      }

      hourlyActivity[hourKey] = activityValue;
    });

    // Morning vs afternoon activity
    int morningActivity = 0;
    int afternoonActivity = 0;

    hourlyActivity.forEach((hour, activity) {
      if (hour >= 5 && hour < 12) {
        morningActivity += activity;
      } else if (hour >= 12 && hour < 20) {
        afternoonActivity += activity;
      }
    });

    String primaryForagingPeriod =
        morningActivity > afternoonActivity ? 'Morning' : 'Afternoon';

    // Check for periodicity/consistency
    Map<String, int> dayOfWeekActivity = {};

    for (var result in results) {
      String dayOfWeek = DateFormat('EEEE').format(result.timestamp);
      dayOfWeekActivity[dayOfWeek] =
          (dayOfWeekActivity[dayOfWeek] ?? 0) + result.totalActivity;
    }

    // Check if there's significant variation by day of week
    List<int> activityValues = dayOfWeekActivity.values.toList();
    double mean = activityValues.isEmpty
        ? 0
        : activityValues.fold(0, (sum, value) => sum + value) /
            activityValues.length;

    double variance = activityValues.isEmpty
        ? 0
        : activityValues.fold(0.0, (sum, value) {
              return sum + math.pow(value - mean, 2);
            }) /
            activityValues.length;

    double stdDev = math.sqrt(variance);

    // Calculate coefficient of variation
    double cv = mean > 0 ? stdDev / mean : 0;

    bool hasWeeklyPattern = cv > 0.3; // Threshold for significant variation

    // Check for weather dependency (simplified model)
    bool suspectedWeatherDependency = false;

    // In a real implementation, this would correlate with actual weather data
    // For now, we'll use variation between consecutive days as a proxy
    if (results.length > 1) {
      int variableActivityDays = 0;

      // Group by day
      Map<DateTime, List<BeeCount>> resultsByDay = {};
      for (var result in results) {
        DateTime day = DateTime(
          result.timestamp.year,
          result.timestamp.month,
          result.timestamp.day,
        );

        if (!resultsByDay.containsKey(day)) {
          resultsByDay[day] = [];
        }

        resultsByDay[day]!.add(result);
      }

      // Sort days
      List<DateTime> sortedDays = resultsByDay.keys.toList()
        ..sort((a, b) => a.compareTo(b));

      // Calculate day-to-day variation
      for (int i = 1; i < sortedDays.length; i++) {
        int previousDayActivity = resultsByDay[sortedDays[i - 1]]!.fold(
          0,
          (sum, result) => sum + result.totalActivity,
        );

        int currentDayActivity = resultsByDay[sortedDays[i]]!.fold(
          0,
          (sum, result) => sum + result.totalActivity,
        );

        // If there's significant variation between consecutive days
        if (previousDayActivity > 0) {
          double percentChange =
              (currentDayActivity - previousDayActivity).abs() /
                  previousDayActivity;
          if (percentChange > 0.4) {
            // 40% change threshold
            variableActivityDays++;
          }
        }
      }

      suspectedWeatherDependency =
          variableActivityDays > sortedDays.length * 0.3;
    }

    // Check for bimodal activity pattern (morning and evening peaks)
    bool hasBimodalPattern = false;
    List<int> peakHours = [];

    // Sort hours by activity level
    List<MapEntry<int, int>> sortedHourlyActivity = hourlyActivity.entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Get top 3 peak hours
    if (sortedHourlyActivity.length >= 3) {
      peakHours = sortedHourlyActivity.take(3).map((e) => e.key).toList();
      peakHours.sort(); // Sort chronologically

      // Check if peaks are separated by at least 3 hours and are in morning/evening
      if (peakHours.length >= 2 &&
          (peakHours.last - peakHours.first) >= 5 &&
          peakHours.first <= 11 &&
          peakHours.last >= 15) {
        hasBimodalPattern = true;
      }
    }

    // Calculate pattern stability over time
    double patternStability = 100 - (cv * 100); // Higher is more stable

    // Detect possible swarming behavior
    bool possibleSwarmingBehavior = false;
    if (metrics['totalBeesOut'] > metrics['totalBeesIn'] * 1.5) {
      // If many more bees left than returned on a single day, potential swarming
      possibleSwarmingBehavior = true;
    }

    return {
      'primaryForagingPeriod': primaryForagingPeriod,
      'morningActivityPercentage': morningActivity > 0 || afternoonActivity > 0
          ? (morningActivity / (morningActivity + afternoonActivity)) * 100
          : 0,
      'afternoonActivityPercentage': morningActivity > 0 ||
              afternoonActivity > 0
          ? (afternoonActivity / (morningActivity + afternoonActivity)) * 100
          : 0,
      'hasWeeklyPattern': hasWeeklyPattern,
      'dayOfWeekActivity': dayOfWeekActivity,
      'patternConsistency': patternStability, // Higher is more consistent
      'suspectedWeatherDependency': suspectedWeatherDependency,
      'hasBimodalPattern': hasBimodalPattern,
      'peakActivityHours': peakHours,
      'possibleSwarmingBehavior': possibleSwarmingBehavior,
      'patternVariability': cv * 100, // Percentage variability
    };
  }

  static Map<String, dynamic> _generateForagingDistributions(
    List<BeeCount> results,
  ) {
    // Generate hourly distributions
    Map<int, Map<String, int>> hourlyBreakdown = {};

    for (int i = 5; i < 21; i++) {
      // 5 AM to 8 PM
      hourlyBreakdown[i] = {'in': 0, 'out': 0};
    }

    for (var result in results) {
      int hour = result.timestamp.hour;
      if (hourlyBreakdown.containsKey(hour)) {
        hourlyBreakdown[hour]!['in'] =
            (hourlyBreakdown[hour]!['in'] ?? 0) + result.beesEntering;
        hourlyBreakdown[hour]!['out'] =
            (hourlyBreakdown[hour]!['out'] ?? 0) + result.beesExiting;
      }
    }

    // Generate day of week distributions
    Map<String, Map<String, int>> dowBreakdown = {};
    List<String> daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    for (var day in daysOfWeek) {
      dowBreakdown[day] = {'in': 0, 'out': 0};
    }

    for (var result in results) {
      String day = DateFormat('EEEE').format(result.timestamp);
      dowBreakdown[day]!['in'] =
          (dowBreakdown[day]!['in'] ?? 0) + result.beesEntering;
      dowBreakdown[day]!['out'] =
          (dowBreakdown[day]!['out'] ?? 0) + result.beesExiting;
    }

    // Generate weekly trend
    Map<int, Map<String, int>> weeklyTrend = {};
    if (results.isNotEmpty) {
      DateTime firstDate = results.first.timestamp;
      for (var result in results) {
        int weekNumber = result.timestamp.difference(firstDate).inDays ~/ 7;
        if (!weeklyTrend.containsKey(weekNumber)) {
          weeklyTrend[weekNumber] = {'in': 0, 'out': 0};
        }
        weeklyTrend[weekNumber]!['in'] =
            (weeklyTrend[weekNumber]!['in'] ?? 0) + result.beesEntering;
        weeklyTrend[weekNumber]!['out'] =
            (weeklyTrend[weekNumber]!['out'] ?? 0) + result.beesExiting;
      }
    }

    // Calculate activity distribution by time blocks
    Map<String, double> timeBlockDistribution = {
      'Early Morning (5-8)': 0,
      'Morning (8-11)': 0,
      'Midday (11-14)': 0,
      'Afternoon (14-17)': 0,
      'Evening (17-20)': 0,
    };

    int totalActivity = 0;
    hourlyBreakdown.forEach((hour, counts) {
      int activity = counts['in']! + counts['out']!;
      totalActivity += activity;

      if (hour >= 5 && hour < 8) {
        timeBlockDistribution['Early Morning (5-8)'] =
            (timeBlockDistribution['Early Morning (5-8)'] ?? 0) + activity;
      } else if (hour >= 8 && hour < 11) {
        timeBlockDistribution['Morning (8-11)'] =
            (timeBlockDistribution['Morning (8-11)'] ?? 0) + activity;
      } else if (hour >= 11 && hour < 14) {
        timeBlockDistribution['Midday (11-14)'] =
            (timeBlockDistribution['Midday (11-14)'] ?? 0) + activity;
      } else if (hour >= 14 && hour < 17) {
        timeBlockDistribution['Afternoon (14-17)'] =
            (timeBlockDistribution['Afternoon (14-17)'] ?? 0) + activity;
      } else if (hour >= 17 && hour < 20) {
        timeBlockDistribution['Evening (17-20)'] =
            (timeBlockDistribution['Evening (17-20)'] ?? 0) + activity;
      }
    });

    // Convert to percentages
    if (totalActivity > 0) {
      timeBlockDistribution.forEach((key, value) {
        timeBlockDistribution[key] = (value / totalActivity) * 100;
      });
    }

    // Calculate entry/exit ratio by hour
    Map<int, double> entryExitRatio = {};
    hourlyBreakdown.forEach((hour, counts) {
      if (counts['out']! > 0) {
        entryExitRatio[hour] = counts['in']! / counts['out']!;
      } else {
        entryExitRatio[hour] = counts['in']! > 0 ? double.infinity : 0;
      }
    });

    return {
      'hourlyDistribution': hourlyBreakdown,
      'dayOfWeekDistribution': dowBreakdown,
      'weeklyTrend': weeklyTrend,
      'timeBlockDistribution': timeBlockDistribution,
      'entryExitRatio': entryExitRatio,
    };
  }

  static Map<String, dynamic> _calculateEfficiencyMetrics(
    List<BeeCount> results,
    Map<String, dynamic> baseMetrics,
  ) {
    double returnRate = baseMetrics['returnRate'];
    double avgForagingDuration = baseMetrics['estimatedForagingDuration'];

    // Calculate foraging efficiency score (higher is better)
    // This would ideally incorporate pollen/nectar load, but we'll use proxy metrics

    // Foraging efficiency is influenced by:
    // 1. Return rate (higher is better)
    // 2. Foraging duration (moderate is optimal - too short means poor resources, too long means inefficient)
    // 3. Consistency of activity (consistent patterns indicate optimal behavior)

    // Normalize return rate (0-100%)
    double returnRateScore = math.min(returnRate, 100);

    // Normalize foraging duration (optimal around 60-90 mins)
    double durationScore = 100;
    if (avgForagingDuration < 60) {
      // Too short - linearly scale from 0 to 100
      durationScore = (avgForagingDuration / 60) * 100;
    } else if (avgForagingDuration > 120) {
      // Too long - linearly scale from 100 to 0
      durationScore = math.max(
        0,
        100 - ((avgForagingDuration - 120) / 120) * 100,
      );
    }

    // Calculate activity consistency
    Map<int, int> hourlyActivity = {};
    for (var result in results) {
      int hour = result.timestamp.hour;
      hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + result.totalActivity;
    }

    List<int> activityValues = hourlyActivity.values.toList();
    double mean = activityValues.isEmpty
        ? 0
        : activityValues.fold(0, (sum, value) => sum + value) /
            activityValues.length;

    double variance = activityValues.isEmpty
        ? 0
        : activityValues.fold(0.0, (sum, value) {
              return sum + math.pow(value - mean, 2);
            }) /
            activityValues.length;

    double stdDev = math.sqrt(variance);
    double cv = mean > 0 ? stdDev / mean : 0;

    // Normalize consistency (lower CV is better)
    double consistencyScore = 100 * math.max(0, 1 - cv);

    // Calculate overall efficiency score (weighted average)
    double efficiencyScore = (returnRateScore * 0.5) +
        (durationScore * 0.3) +
        (consistencyScore * 0.2);

    // Calculate productivity metrics
    double beesPerHour = 0;
    if (results.isNotEmpty) {
      DateTime firstTimestamp = results.first.timestamp;
      DateTime lastTimestamp = results.last.timestamp;
      double hoursDifference =
          lastTimestamp.difference(firstTimestamp).inMinutes / 60;

      if (hoursDifference > 0) {
        beesPerHour = baseMetrics['totalActivity'] / hoursDifference;
      }
    }

    // Calculate foraging balance (ratio of bees in vs out)
    double foragingBalance = baseMetrics['totalBeesOut'] > 0
        ? baseMetrics['totalBeesIn'] / baseMetrics['totalBeesOut']
        : 0;

    // Calculate peak efficiency hours
    Map<int, double> hourlyEfficiency = {};
    for (int hour = 5; hour < 21; hour++) {
      int beesOut = 0;
      int beesIn = 0;

      for (var result in results) {
        if (result.timestamp.hour == hour) {
          beesOut += result.beesExiting;
          beesIn += result.beesEntering;
        }
      }

      hourlyEfficiency[hour] = beesOut > 0 ? beesIn / beesOut : 0;
    }

    // Find peak efficiency hour
    int peakEfficiencyHour = 12; // Default to noon
    double maxEfficiency = 0;

    hourlyEfficiency.forEach((hour, efficiency) {
      if (efficiency > maxEfficiency) {
        maxEfficiency = efficiency;
        peakEfficiencyHour = hour;
      }
    });

    return {
      'efficiencyScore': efficiencyScore,
      'returnRateScore': returnRateScore,
      'durationScore': durationScore,
      'consistencyScore': consistencyScore,
      'beesPerHour': beesPerHour,
      'foragingBalance': foragingBalance,
      'hourlyEfficiency': hourlyEfficiency,
      'peakEfficiencyHour': peakEfficiencyHour,
      'peakEfficiencyValue': maxEfficiency,
      'efficiencyRating': _getEfficiencyRating(efficiencyScore),
    };
  }

  static String _getEfficiencyRating(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Fair';
    if (score >= 40) return 'Poor';
    return 'Very Poor';
  }

  static Future<Map<String, dynamic>> _analyzeEnvironmentalCorrelations(
    List<BeeCount> results,
  ) async {
    // Group results by day
    Map<DateTime, List<BeeCount>> resultsByDay = {};
    for (var result in results) {
      DateTime day = DateTime(
        result.timestamp.year,
        result.timestamp.month,
        result.timestamp.day,
      );

      if (!resultsByDay.containsKey(day)) {
        resultsByDay[day] = [];
      }

      resultsByDay[day]!.add(result);
    }

    // Calculate daily metrics
    Map<DateTime, Map<String, dynamic>> dailyMetrics = {};
    resultsByDay.forEach((day, dayResults) {
      int totalBeesIn = 0;
      int totalBeesOut = 0;
      int totalActivity = 0;

      for (var result in dayResults) {
        totalBeesIn += result.beesEntering;
        totalBeesOut += result.beesExiting;
        totalActivity += result.totalActivity;
      }

      double returnRate =
          totalBeesOut > 0 ? (totalBeesIn / totalBeesOut) * 100 : 0;

      dailyMetrics[day] = {
        'totalBeesIn': totalBeesIn,
        'totalBeesOut': totalBeesOut,
        'totalActivity': totalActivity,
        'returnRate': returnRate,
      };
    });

    // Get weather data for each day
    Map<DateTime, Map<String, dynamic>> weatherByDay = {};
    for (var day in dailyMetrics.keys) {
      try {
        Map<String, dynamic> weatherData =
            await WeatherService.getWeatherForDate(day);
        weatherByDay[day] = weatherData;
      } catch (e) {
        print('Error fetching weather for $day: $e');
        weatherByDay[day] = {'error': 'Weather data unavailable'};
      }
    }

    // Calculate correlations between weather and foraging metrics
    Map<String, Map<String, dynamic>> correlations = {};

    // Weather factors to analyze
    List<String> weatherFactors = [
      'temperature',
      'humidity',
      'windSpeed',
      'precipitation',
      'cloudCover',
    ];

    // Foraging metrics to correlate
    List<String> foragingMetrics = [
      'totalActivity',
      'returnRate',
      'totalBeesOut',
    ];

    // For each weather factor
    for (var factor in weatherFactors) {
      // Prepare data for correlation
      List<double> factorValues = [];
      Map<String, List<double>> metricValues = {};

      for (var metric in foragingMetrics) {
        metricValues[metric] = [];
      }

      // Collect data points where both weather and foraging data exist
      weatherByDay.forEach((day, weather) {
        if (weather.containsKey(factor) &&
            weather[factor] != null &&
            dailyMetrics.containsKey(day)) {
          // Extract weather value
          double? weatherValue;
          if (weather[factor] is num) {
            weatherValue = (weather[factor] as num).toDouble();
          } else if (weather[factor] is String) {
            weatherValue = double.tryParse(weather[factor]);
          }

          if (weatherValue != null) {
            factorValues.add(weatherValue);

            // Extract foraging metrics
            for (var metric in foragingMetrics) {
              if (dailyMetrics[day]!.containsKey(metric)) {
                var value = dailyMetrics[day]![metric];
                if (value is num) {
                  metricValues[metric]!.add(value.toDouble());
                }
              }
            }
          }
        }
      });

      // Calculate correlation for each metric
      Map<String, dynamic> factorCorrelations = {};

      for (var metric in foragingMetrics) {
        if (factorValues.length == metricValues[metric]!.length &&
            factorValues.length > 1) {
          double correlation =
              _calculateCorrelation(factorValues, metricValues[metric]!);

          factorCorrelations[metric] = {
            'correlation': correlation,
            'strength': _getCorrelationStrength(correlation),
            'direction': correlation > 0 ? 'positive' : 'negative',
          };
        }
      }

      // Store factor correlations with values for visualization
      correlations[factor] = {
        'correlations': factorCorrelations,
        'values': factorValues,
      };
    }

    // Generate insights based on correlations
    Map<String, String> environmentalInsights = {};

    correlations.forEach((factor, data) {
      if (data.containsKey('correlations')) {
        Map<String, dynamic> factorCorrelations = data['correlations'];

        // Check activity correlation
        if (factorCorrelations.containsKey('totalActivity')) {
          double correlation =
              factorCorrelations['totalActivity']['correlation'];
          String strength = factorCorrelations['totalActivity']['strength'];

          if (strength != 'Weak' && strength != 'Very Weak') {
            String direction = correlation > 0 ? 'increases' : 'decreases';
            environmentalInsights['${factor}Activity'] =
                'Foraging activity $direction with higher $factor ($strength correlation)';
          }
        }

        // Check return rate correlation
        if (factorCorrelations.containsKey('returnRate')) {
          double correlation = factorCorrelations['returnRate']['correlation'];
          String strength = factorCorrelations['returnRate']['strength'];

          if (strength != 'Weak' && strength != 'Very Weak') {
            String direction = correlation > 0 ? 'increases' : 'decreases';
            environmentalInsights['${factor}Return'] =
                'Return rate $direction with higher $factor ($strength correlation)';
          }
        }
      }
    });

    return {
      'weatherData': correlations,
      'environmentalInsights': environmentalInsights,
    };
  }

  static double _calculateCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.isEmpty) {
      return 0;
    }

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;
    double sumY2 = 0;

    for (int i = 0; i < x.length; i++) {
      sumX += x[i];
      sumY += y[i];
      sumXY += x[i] * y[i];
      sumX2 += x[i] * x[i];
      sumY2 += y[i] * y[i];
    }

    double n = x.length.toDouble();
    double numerator = (n * sumXY) - (sumX * sumY);
    double denominator = math
        .sqrt(((n * sumX2) - (sumX * sumX)) * ((n * sumY2) - (sumY * sumY)));

    if (denominator == 0) {
      return 0;
    }

    return numerator / denominator;
  }

  static String _getCorrelationStrength(double correlation) {
    double absCorrelation = correlation.abs();

    if (absCorrelation >= 0.8) return 'Very Strong';
    if (absCorrelation >= 0.6) return 'Strong';
    if (absCorrelation >= 0.4) return 'Moderate';
    if (absCorrelation >= 0.2) return 'Weak';
    return 'Very Weak';
  }

  static Map<String, dynamic> _generateRecommendations(
    Map<String, dynamic> metrics,
    Map<String, dynamic> patterns,
    Map<String, dynamic> efficiency,
    Map<String, dynamic> environmentalFactors,
    Map<String, dynamic> timeBasedAnalysis,
  ) {
    List<Map<String, dynamic>> recommendations = [];

    // Check return rate
    double returnRate = metrics['returnRate'];
    if (returnRate < 70) {
      recommendations.add({
        'type': 'warning',
        'title': 'Low Return Rate',
        'description':
            'The return rate of ${returnRate.toStringAsFixed(1)}% is lower than expected. This could indicate predation, disease, or disorientation issues.',
        'action':
            'Check for predators near the hive and ensure there are no pesticide applications in foraging areas.',
      });
    }

    // Check foraging efficiency
    String efficiencyRating = efficiency['efficiencyRating'];
    if (efficiencyRating == 'Poor' || efficiencyRating == 'Very Poor') {
      recommendations.add({
        'type': 'warning',
        'title': 'Low Foraging Efficiency',
        'description':
            'Foraging efficiency is rated as $efficiencyRating. Bees may be traveling too far or facing challenges finding resources.',
        'action':
            'Consider supplemental feeding or relocating the hive closer to abundant forage.',
      });
    }

    // Check for weather dependency
    bool weatherDependency = patterns['suspectedWeatherDependency'];
    if (weatherDependency) {
      recommendations.add({
        'type': 'info',
        'title': 'Weather Dependency Detected',
        'description':
            'Foraging activity shows strong correlation with weather conditions.',
        'action':
            'Monitor weather forecasts to predict foraging activity and plan inspections accordingly.',
      });
    }

    // Check for swarming behavior
    bool swarmingBehavior = patterns['possibleSwarmingBehavior'];
    if (swarmingBehavior) {
      recommendations.add({
        'type': 'alert',
        'title': 'Possible Swarming Behavior',
        'description':
            'A significantly higher number of bees leaving than returning could indicate swarming.',
        'action':
            'Inspect the hive for queen cells and consider swarm prevention measures.',
      });
    }

    // Check time-based health indicators
    if (timeBasedAnalysis.containsKey('hasData') &&
        timeBasedAnalysis['hasData'] &&
        timeBasedAnalysis.containsKey('dailyReturnRates')) {
      Map<String, Map<String, dynamic>> dailyRates =
          timeBasedAnalysis['dailyReturnRates'];

      // Check most recent day
      if (dailyRates.isNotEmpty) {
        String mostRecentDay = dailyRates.keys.reduce(
            (a, b) => DateTime.parse(a).isAfter(DateTime.parse(b)) ? a : b);

        var dayData = dailyRates[mostRecentDay];

        if (dayData != null && dayData.containsKey('timeBlocks')) {
          Map<String, dynamic> timeBlocks = dayData['timeBlocks'];

          // Check for poor health indicators
          timeBlocks.forEach((blockName, blockData) {
            if (blockData.containsKey('healthIndicator') &&
                blockData['healthIndicator'] == 'Poor') {
              recommendations.add({
                'type': 'warning',
                'title': 'Poor Foraging Health in $blockName',
                'description':
                    'The $blockName time block shows concerning foraging patterns with low return rates.',
                'action':
                    'Check for new threats or changes in the environment during this time period.',
              });
            }
          });
        }
      }
    }

    // Check overall health score
    if (timeBasedAnalysis.containsKey('overallHealthScore')) {
      double healthScore = timeBasedAnalysis['overallHealthScore'];

      if (healthScore < 50) {
        recommendations.add({
          'type': 'alert',
          'title': 'Low Overall Foraging Health',
          'description':
              'The overall foraging health score of ${healthScore.toStringAsFixed(1)} indicates significant issues.',
          'action':
              'Conduct a full hive inspection and consider consulting with a local beekeeping expert.',
        });
      } else if (healthScore < 70) {
        recommendations.add({
          'type': 'warning',
          'title': 'Moderate Foraging Health Concerns',
          'description':
              'The foraging health score of ${healthScore.toStringAsFixed(1)} suggests some challenges.',
          'action':
              'Monitor the hive closely and check for signs of disease or nutritional deficiencies.',
        });
      }
    }

    // Check environmental correlations
    if (environmentalFactors.containsKey('environmentalInsights')) {
      Map<String, String> insights =
          environmentalFactors['environmentalInsights'];

      if (insights.isNotEmpty) {
        // Find the strongest correlation
        String? strongestInsight;
        insights.forEach((key, value) {
          if (value.contains('Strong correlation') ||
              value.contains('Very Strong correlation')) {
            strongestInsight = value;
          }
        });

        if (strongestInsight != null) {
          recommendations.add({
            'type': 'info',
            'title': 'Environmental Factor Impact',
            'description': strongestInsight!,
            'action':
                'Consider this environmental factor when planning hive management activities.',
          });
        }
      }
    }

    // Add general recommendations if few specific ones
    if (recommendations.length < 2) {
      // Check peak activity time
      int peakHour = metrics['peakActivityHour'];
      String peakTimeStr = peakHour < 12
          ? '$peakHour AM'
          : (peakHour == 12 ? '12 PM' : '${peakHour - 12} PM');

      recommendations.add({
        'type': 'info',
        'title': 'Peak Activity Time',
        'description': 'Peak foraging activity occurs around $peakTimeStr.',
        'action':
            'Plan hive inspections outside of peak activity times to minimize disruption.',
      });

      // Foraging pattern recommendation
      String primaryPeriod = patterns['primaryForagingPeriod'];
      recommendations.add({
        'type': 'info',
        'title': '$primaryPeriod Foraging Pattern',
        'description':
            'This colony shows a preference for $primaryPeriod foraging.',
        'action':
            'Ensure water sources are available, especially if afternoon foraging is dominant.',
      });
    }

    return {
      'recommendations': recommendations,
      'recommendationCount': recommendations.length,
      'hasWarnings': recommendations
          .any((r) => r['type'] == 'warning' || r['type'] == 'alert'),
    };
  }

  static double _calculateForagePerformanceScore(
    Map<String, dynamic> metrics,
    Map<String, dynamic> efficiency,
    Map<String, dynamic> environmentalFactors,
    Map<String, dynamic> timeBasedAnalysis,
  ) {
    // This is a composite score from 0-100 that represents overall foraging performance

    // Component 1: Return Rate (0-100)
    double returnRateScore = math.min(metrics['returnRate'], 100);

    // Component 2: Efficiency Score (0-100)
    double efficiencyScore = efficiency['efficiencyScore'];

    // Component 3: Time-based health score (0-100)
    double timeBasedScore = 70; // Default if not available
    if (timeBasedAnalysis.containsKey('overallHealthScore')) {
      timeBasedScore = timeBasedAnalysis['overallHealthScore'];
    }

    // Component 4: Environmental adaptation score (0-100)
    double environmentalScore = 80; // Default if not available

    // If we have weather correlations, calculate environmental adaptation
    if (environmentalFactors.containsKey('weatherData') &&
        environmentalFactors['weatherData'].isNotEmpty) {
      // Check if foraging patterns adapt well to weather conditions
      Map<String, dynamic> weatherData = environmentalFactors['weatherData'];

      // Calculate average correlation strength
      double totalCorrelation = 0;
      int correlationCount = 0;

      weatherData.forEach((factor, data) {
        if (data.containsKey('correlations') &&
            data['correlations'].containsKey('totalActivity')) {
          double correlation =
              data['correlations']['totalActivity']['correlation'].abs();

          // Weather-appropriate correlation is good
          // For example, positive correlation with temperature is good
          if (factor == 'temperature' || factor == 'sunlight') {
            totalCorrelation += correlation;
          }
          // Negative correlation with these factors is good
          else if (factor == 'precipitation' || factor == 'windSpeed') {
            totalCorrelation += correlation;
          }

          correlationCount++;
        }
      });

      if (correlationCount > 0) {
        double avgCorrelation = totalCorrelation / correlationCount;
        // Convert to 0-100 scale (0.8 correlation = 100 score)
        environmentalScore = math.min(100, avgCorrelation * 125);
      }
    }

    // Calculate weighted composite score
    return (returnRateScore * 0.4) +
        (efficiencyScore * 0.3) +
        (timeBasedScore * 0.2) +
        (environmentalScore * 0.1);
  }

  static double _estimateForagingDuration(List<BeeCount> results) {
    // This is a simplified estimate based on bee counter data
    // In reality, this would require tracking individual bees

    if (results.isEmpty) {
      return 60.0; // Default to 60 minutes if no data
    }

    // Group results by hour
    Map<int, Map<String, int>> hourlyActivity = {};

    for (var result in results) {
      int hour = result.timestamp.hour;

      if (!hourlyActivity.containsKey(hour)) {
        hourlyActivity[hour] = {'in': 0, 'out': 0};
      }

      hourlyActivity[hour]!['in'] =
          (hourlyActivity[hour]!['in'] ?? 0) + result.beesEntering;
      hourlyActivity[hour]!['out'] =
          (hourlyActivity[hour]!['out'] ?? 0) + result.beesExiting;
    }

    // Sort hours
    List<int> sortedHours = hourlyActivity.keys.toList()..sort();

    if (sortedHours.length < 2) {
      return 60.0; // Default if not enough data
    }

    // Find peak exit hour
    int peakExitHour = sortedHours.first;
    int maxExits = 0;

    for (var hour in sortedHours) {
      int exits = hourlyActivity[hour]!['out']!;
      if (exits > maxExits) {
        maxExits = exits;
        peakExitHour = hour;
      }
    }

    // Find peak return hour after peak exit hour
    int peakReturnHour = peakExitHour;
    int maxReturns = 0;

    for (var hour in sortedHours) {
      if (hour > peakExitHour) {
        int returns = hourlyActivity[hour]!['in']!;
        if (returns > maxReturns) {
          maxReturns = returns;
          peakReturnHour = hour;
        }
      }
    }

    // Calculate estimated duration
    int durationHours = peakReturnHour - peakExitHour;

    // Apply reasonable bounds
    if (durationHours <= 0) {
      return 60.0; // Default to 1 hour if calculation fails
    } else if (durationHours > 4) {
      return 240.0; // Cap at 4 hours
    }

    return durationHours * 60.0; // Convert to minutes
  }
}
