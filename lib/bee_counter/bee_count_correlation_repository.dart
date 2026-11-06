// File: lib/bee_counter/bee_count_correlation_repository.dart
import 'dart:math';
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/bee_counter/bee_count_database.dart';
import 'package:farmer_app/bee_counter/weatherdata.dart';
import 'package:farmer_app/Services/weather_service.dart';
import 'package:farmer_app/hive_model.dart';

/// A repository for handling and caching bee count correlations
/// This improves performance by minimizing redundant calculations and database operations
class BeeCountCorrelationRepository {
  static final BeeCountCorrelationRepository _instance =
      BeeCountCorrelationRepository._internal();

  factory BeeCountCorrelationRepository() {
    return _instance;
  }

  BeeCountCorrelationRepository._internal();

  // Cache for bee counts by hive ID
  final Map<String, List<BeeCount>> _beeCountCache = {};

  // Cache for weather data
  Map<DateTime, WeatherData>? _weatherDataCache;

  // Cache for correlations by hive ID and time range
  final Map<String, Map<String, double>> _correlationCache = {};

  // Cache for HiveData
  final Map<String, List<HiveData>> _hiveDataCache = {};

  // Cache timestamp to track when data was last fetched
  final Map<String, DateTime> _lastFetchTime = {};

  /// Get bee counts for a specific hive, with caching
  Future<List<BeeCount>> getBeeCountsForHive(String hiveId,
      {bool forceRefresh = false}) async {
    final cacheKey = 'hive_$hiveId';

    // Check if we need to refresh the cache
    final shouldRefresh = forceRefresh ||
        !_beeCountCache.containsKey(cacheKey) ||
        _isCacheExpired(cacheKey);

    if (shouldRefresh) {
      final counts =
          await BeeCountDatabase.instance.getBeeCountsForHive(hiveId);
      _beeCountCache[cacheKey] = counts;
      _lastFetchTime[cacheKey] = DateTime.now();
      return counts;
    }

    return _beeCountCache[cacheKey] ?? [];
  }

  /// Get bee counts for a specific hive filtered by date range
  Future<List<BeeCount>> getBeeCountsForHiveInRange(
      String hiveId, DateTime startDate, DateTime endDate,
      {bool forceRefresh = false}) async {
    final counts =
        await getBeeCountsForHive(hiveId, forceRefresh: forceRefresh);

    return counts.where((count) {
      return count.timestamp.isAfter(startDate) &&
          count.timestamp.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  /// Get weather data with caching
  Future<Map<DateTime, WeatherData>> getWeatherData(
      {bool forceRefresh = false}) async {
    final cacheKey = 'weather_data';

    // Check if we need to refresh the cache
    final shouldRefresh =
        forceRefresh || _weatherDataCache == null || _isCacheExpired(cacheKey);      if (shouldRefresh) {        try {
          final data = await WeatherService.getWeatherDataForDateRange(
            DateTime.now().subtract(const Duration(days: 30)),
            DateTime.now(),
          );

          // Convert to our WeatherData format
          final Map<DateTime, WeatherData> convertedData = {};
          data.forEach((date, weatherInfo) {
            try {
              convertedData[date] = WeatherData(
                timestamp: date,
                temperature: (weatherInfo['temperature'] as num?)?.toDouble() ?? 0.0,
                humidity: (weatherInfo['humidity'] as num?)?.toDouble() ?? 0.0,
                windSpeed: (weatherInfo['windSpeed'] as num?)?.toDouble() ?? 0.0,
                rainfall: (weatherInfo['precipitation'] as num?)?.toDouble() ?? 0.0,
                solarRadiation: 0.0,
              );
            } catch (e) {
              print('Error converting weather data: $e');
            }
          });

        _weatherDataCache = convertedData;
        _lastFetchTime[cacheKey] = DateTime.now();
      } catch (e) {
        print('Error fetching weather data: $e');
        // Return cached data if available, otherwise empty map
        return _weatherDataCache ?? {};
      }
    }

    return _weatherDataCache ?? {};
  }

  /// Get hive data with caching
  Future<List<HiveData>> getHiveData(String hiveId,
      {bool forceRefresh = false}) async {
    final cacheKey = 'hive_data_$hiveId';

    // Check if we need to refresh the cache
    final shouldRefresh = forceRefresh ||
        !_hiveDataCache.containsKey(cacheKey) ||
        _isCacheExpired(cacheKey);

    if (shouldRefresh) {
      try {
        // Instead of generating sample data, we should fetch real data here
        // For now, we'll use the sample data approach from the correlation screen
        final beeCounts = await getBeeCountsForHive(hiveId);
        final hiveData = _generateHiveDataFromBeeCounts(beeCounts);

        _hiveDataCache[cacheKey] = hiveData;
        _lastFetchTime[cacheKey] = DateTime.now();
      } catch (e) {
        print('Error fetching hive data: $e');
        // Return cached data if available, otherwise empty list
        return _hiveDataCache[cacheKey] ?? [];
      }
    }

    return _hiveDataCache[cacheKey] ?? [];
  }

  /// Calculate correlations between bee activity and environmental factors
  /// with improved caching strategy to boost performance
  Future<Map<String, double>> calculateCorrelations(
      String hiveId, int timeRange,
      {bool forceRefresh = false}) async {
    final cacheKey = 'correlations_${hiveId}_$timeRange';

    // Check if we need to refresh the cache
    final shouldRefresh = forceRefresh ||
        !_correlationCache.containsKey(cacheKey) ||
        _isCacheExpired(cacheKey);

    if (!shouldRefresh) {
      return _correlationCache[cacheKey] ?? {};
    }

    Map<String, double> correlations = {
      'Temperature': 0.0,
      'Humidity': 0.0,
      'Wind Speed': 0.0,
      'Time of Day': 0.0,
      'Hive Weight': 0.0,
    };

    try {
      // Define the date range for our data
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: timeRange));

      // Get the data we need
      final beeCounts =
          await getBeeCountsForHiveInRange(hiveId, startDate, endDate);
      final weatherData = await getWeatherData();
      final hiveData = await getHiveData(hiveId);

      // Prepare data points for correlation
      final dataPoints = <_DataPoint>[];

      // For each bee count, find the closest weather and hive data
      for (final count in beeCounts) {
        // Find closest weather data
        WeatherData? nearestWeather;
        Duration smallestDiff = const Duration(days: 1);

        for (final entry in weatherData.entries) {
          final diff = (entry.key.difference(count.timestamp)).abs();
          if (diff < smallestDiff) {
            smallestDiff = diff;
            nearestWeather = entry.value;
          }
        }

        // Find the closest hive data point
        HiveData? nearestHiveData;
        smallestDiff = const Duration(days: 1);

        for (final data in hiveData) {
          try {
            final timestamp = DateTime.parse(data.lastChecked);
            final diff = (timestamp.difference(count.timestamp)).abs();
            if (diff < smallestDiff) {
              smallestDiff = diff;
              nearestHiveData = data;
            }
          } catch (e) {
            print('Error parsing date: $e');
          }
        }        // Only add if we have all the data
        if (nearestWeather != null && nearestHiveData != null) {
          dataPoints.add(
            _DataPoint(
              activity: count.beesEntering + count.beesExiting,
              temperature: nearestWeather.temperature,
              humidity: nearestWeather.humidity,
              windSpeed: nearestWeather.windSpeed,
              timeOfDay: count.timestamp.hour.toDouble(),
              weight: nearestHiveData.weight ?? 0.0,
            ),
          );
        }
      }

      if (dataPoints.isEmpty) {
        _correlationCache[cacheKey] = correlations;
        _lastFetchTime[cacheKey] = DateTime.now();
        return correlations;
      }

      // Calculate correlation coefficients
      correlations['Temperature'] = _calculatePearsonCorrelation(
        dataPoints.map((p) => p.temperature).toList(),
        dataPoints.map((p) => p.activity.toDouble()).toList(),
      );

      correlations['Humidity'] = _calculatePearsonCorrelation(
        dataPoints.map((p) => p.humidity).toList(),
        dataPoints.map((p) => p.activity.toDouble()).toList(),
      );

      correlations['Wind Speed'] = _calculatePearsonCorrelation(
        dataPoints.map((p) => p.windSpeed).toList(),
        dataPoints.map((p) => p.activity.toDouble()).toList(),
      );

      // For time of day, we use a circular correlation approach
      correlations['Time of Day'] = _calculatePearsonCorrelation(
        dataPoints.map((p) => _normalizeTimeOfDay(p.timeOfDay)).toList(),
        dataPoints.map((p) => p.activity.toDouble()).toList(),
      );

      correlations['Hive Weight'] = _calculatePearsonCorrelation(
        dataPoints.map((p) => p.weight).toList(),
        dataPoints.map((p) => p.activity.toDouble()).toList(),
      );

      // Cache the results
      _correlationCache[cacheKey] = correlations;
      _lastFetchTime[cacheKey] = DateTime.now();
    } catch (e) {
      print('Error calculating correlations: $e');
    }

    return correlations;
  }

  /// Generate data insights based on correlation values
  Map<String, String> generateDataInsights(Map<String, double> correlations) {
    final Map<String, String> insights = {};

    // Generate insights for each factor
    correlations.forEach((factor, correlation) {
      final absValue = correlation.abs();
      String insight = '';

      if (absValue < 0.1) {
        insight =
            'No significant relationship found between bee activity and $factor.';
      } else if (absValue < 0.3) {
        if (correlation > 0) {
          insight = 'Slight increase in bee activity with higher $factor.';
        } else {
          insight = 'Slight decrease in bee activity with higher $factor.';
        }
      } else if (absValue < 0.5) {
        if (correlation > 0) {
          insight = 'Moderate increase in bee activity with higher $factor.';
        } else {
          insight = 'Moderate decrease in bee activity with higher $factor.';
        }
      } else if (absValue < 0.7) {
        if (correlation > 0) {
          insight =
              'Strong positive relationship between bee activity and $factor.';
        } else {
          insight =
              'Strong negative relationship between bee activity and $factor.';
        }
      } else {
        if (correlation > 0) {
          insight =
              'Very strong positive relationship between bee activity and $factor.';
        } else {
          insight =
              'Very strong negative relationship between bee activity and $factor.';
        }
      }

      // Add specific advice for each factor
      switch (factor) {
        case 'Temperature':
          if (correlation > 0.3) {
            insight +=
                ' Consider monitoring on cooler days to reduce stress on colonies.';
          } else if (correlation < -0.3) {
            insight +=
                ' Consider providing additional insulation during colder periods.';
          }
          break;

        case 'Humidity':
          if (correlation > 0.3) {
            insight +=
                ' Ensure adequate ventilation in high humidity conditions.';
          } else if (correlation < -0.3) {
            insight +=
                ' Consider providing additional water sources during dry periods.';
          }
          break;

        case 'Hive Weight':
          if (correlation > 0.5) {
            insight +=
                ' High activity with increasing weight suggests good nectar flow.';
          } else if (correlation < -0.3) {
            insight +=
                ' Activity decreasing with weight may indicate issues with colony health.';
          }
          break;

        case 'Time of Day':
          if (absValue > 0.3) {
            insight +=
                ' Consider timing inspections when activity is naturally lower.';
          }
          break;
      }

      insights[factor] = insight;
    });

    return insights;
  }

  /// Check if the cache for a given key is expired (older than 30 minutes)
  bool _isCacheExpired(String cacheKey) {
    final lastFetch = _lastFetchTime[cacheKey];
    if (lastFetch == null) return true;

    final now = DateTime.now();
    return now.difference(lastFetch).inMinutes > 30;
  }

  /// Helper function to normalize time of day (converts hours to a continuous cycle)
  double _normalizeTimeOfDay(double hour) {
    return sin((hour / 24) * 2 * pi); // Convert to sine wave on a 24-hour cycle
  }

  /// Calculate Pearson correlation coefficient
  double _calculatePearsonCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.isEmpty) return 0.0;

    final n = x.length;

    // Calculate means
    final xMean = x.reduce((a, b) => a + b) / n;
    final yMean = y.reduce((a, b) => a + b) / n;

    // Calculate sums of squares
    double numerator = 0.0;
    double xSumSquares = 0.0;
    double ySumSquares = 0.0;

    for (int i = 0; i < n; i++) {
      final xDiff = x[i] - xMean;
      final yDiff = y[i] - yMean;

      numerator += xDiff * yDiff;
      xSumSquares += xDiff * xDiff;
      ySumSquares += yDiff * yDiff;
    }

    // Avoid division by zero
    if (xSumSquares == 0.0 || ySumSquares == 0.0) return 0.0;

    return numerator / (sqrt(xSumSquares) * sqrt(ySumSquares));
  }

  /// Generate sample hive data based on bee counts
  List<HiveData> _generateHiveDataFromBeeCounts(List<BeeCount> beeCounts) {
    // Group bee counts by day
    final Map<DateTime, List<BeeCount>> countsByDay = {};

    for (final count in beeCounts) {
      final day = DateTime(
        count.timestamp.year,
        count.timestamp.month,
        count.timestamp.day,
      );

      if (!countsByDay.containsKey(day)) {
        countsByDay[day] = [];
      }

      countsByDay[day]!.add(count);
    }

    // Create one hive data point per day
    final hiveData = <HiveData>[];
    double baseWeight = 50.0; // Start with 50kg

    // Sort days
    final sortedDays = countsByDay.keys.toList()..sort();

    for (final day in sortedDays) {
      // Calculate daily activity
      final dayCounts = countsByDay[day]!;
      int totalIn = 0;
      int totalOut = 0;

      for (final count in dayCounts) {
        totalIn += count.beesEntering;
        totalOut += count.beesExiting;
      }

      // Adjust weight based on net bee entries (more entries generally means more nectar/honey)
      // This is a simplified model - in a real system, you'd use actual weight measurements
      final netChange = totalIn - totalOut;
      baseWeight +=
          (netChange * 0.001); // Each bee contributes a small amount to weight

      // Ensure weight stays in a reasonable range
      baseWeight = baseWeight.clamp(30.0, 100.0);

      // Create a HiveData instance for this day
      hiveData.add(HiveData(
        id: '1', // Placeholder ID
        name: 'Hive 1', // Placeholder name
        status: 'Active',
        healthStatus: 'Healthy',
        lastChecked: day.toIso8601String(),
        weight: baseWeight,
        temperature: 25.0 +
            (Random().nextDouble() * 10 - 5), // Random temperature around 25°C
        honeyLevel: (baseWeight - 30) /
            70 *
            100, // Simple conversion from weight to honey level
        isConnected: true,
        isColonized: true,
        autoProcessingEnabled: true,
      ));
    }

    return hiveData;
  }

  /// Clear all caches
  void clearAllCaches() {
    _beeCountCache.clear();
    _weatherDataCache = null;
    _correlationCache.clear();
    _hiveDataCache.clear();
    _lastFetchTime.clear();
  }

  /// Clear specific cache
  void clearCache(String cacheKey) {
    if (_beeCountCache.containsKey(cacheKey)) {
      _beeCountCache.remove(cacheKey);
    }
    if (_correlationCache.containsKey(cacheKey)) {
      _correlationCache.remove(cacheKey);
    }
    if (_hiveDataCache.containsKey(cacheKey)) {
      _hiveDataCache.remove(cacheKey);
    }
    _lastFetchTime.remove(cacheKey);
  }
}

/// Helper class for data points
class _DataPoint {
  final int activity;
  final double temperature;
  final double humidity;
  final double windSpeed;
  final double timeOfDay;
  final double weight;

  _DataPoint({
    required this.activity,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.timeOfDay,
    required this.weight,
  });
}
