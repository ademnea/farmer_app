import 'package:farmer_app/bee_counter/weatherdata.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WeatherService {
  // Weather API base URL - replace with your actual weather API
  final String baseUrl = 'https://www.meteosource.com/api/v1/free/point';
  final String apiKey = 'pk5l7f3uii8c19rkzyr20z5b8liieenq1boytiqi';

  // HTTP client
  final http.Client _client = http.Client();

  // Cache for weather data to reduce API calls
  final Map<String, WeatherData> _cache = {};

  // Get weather data for a specific date and time
  Future<WeatherData?> getWeatherData(DateTime dateTime) async {
    final cacheKey = dateTime.toIso8601String();

    // Check cache first
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      // Try loading from preferences first (to reduce API calls)
      final cachedData = await _loadFromPreferences(cacheKey);
      if (cachedData != null) {
        _cache[cacheKey] = cachedData;
        return cachedData;
      }

      // If not in cache, fetch from API
      final weatherData = await _fetchFromApi(dateTime);

      if (weatherData != null) {
        // Save to cache
        _cache[cacheKey] = weatherData;

        // Save to preferences
        await _saveToPreferences(cacheKey, weatherData);

        return weatherData;
      }

      return null;
    } catch (e) {
      print('Error getting weather data: $e');

      // For demo purposes, return mock data if API fails
      return _getMockWeatherData(dateTime);
    }
  }

  // Get weather data for a date range
  Future<Map<DateTime, WeatherData>> getWeatherDataForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final Map<DateTime, WeatherData> result = {};

    // Clone start date to avoid modifying the original
    DateTime current = DateTime(startDate.year, startDate.month, startDate.day);

    // Get hourly data for each day in the range
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      for (int hour = 0; hour < 24; hour++) {
        final dateTime = DateTime(
          current.year,
          current.month,
          current.day,
          hour,
        );

        final weatherData = await getWeatherData(dateTime);
        if (weatherData != null) {
          result[dateTime] = weatherData;
        }
      }

      // Move to next day
      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  // Fetch weather data from API
  Future<WeatherData?> _fetchFromApi(DateTime dateTime) async {
    try {
      final url = Uri.parse(
        '$baseUrl/historical?lat=LATITUDE&lon=LONGITUDE&dt=${dateTime.millisecondsSinceEpoch ~/ 1000}&appid=$apiKey',
      );

      final response = await _client.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Parse API response to WeatherData
        // This parsing depends on your specific API format
        final weatherData = WeatherData(
          timestamp: dateTime,
          temperature: data['main']['temp'].toDouble(),
          humidity: data['main']['humidity'].toDouble(),
          windSpeed: data['wind']['speed'].toDouble(),
          rainfall: data['rain']?['1h']?.toDouble() ?? 0.0,
          solarRadiation: data['solar_radiation']?.toDouble() ?? 0.0,
        );

        return weatherData;
      } else {
        print('Error fetching weather data: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error in API request: $e');
      return null;
    }
  }

  // Load weather data from shared preferences
  Future<WeatherData?> _loadFromPreferences(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('weather_$key');

      if (json != null) {
        return WeatherData.fromJson(jsonDecode(json));
      }

      return null;
    } catch (e) {
      print('Error loading weather data from preferences: $e');
      return null;
    }
  }

  // Save weather data to shared preferences
  Future<void> _saveToPreferences(String key, WeatherData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(data.toJson());

      await prefs.setString('weather_$key', json);
    } catch (e) {
      print('Error saving weather data to preferences: $e');
    }
  }

  // Generate mock weather data for demo purposes
  WeatherData _getMockWeatherData(DateTime dateTime) {
    // Generate somewhat realistic values based on date and time
    // This is just for demonstration - in a real app, use actual API data

    // Temperature peaks in afternoon, lowest at night
    final hour = dateTime.hour;
    final month = dateTime.month;

    // Base temperature depends on month (Northern Hemisphere seasons)
    double baseTemp;
    if (month >= 3 && month <= 5) {
      // Spring
      baseTemp = 15.0;
    } else if (month >= 6 && month <= 8) {
      // Summer
      baseTemp = 25.0;
    } else if (month >= 9 && month <= 11) {
      // Fall
      baseTemp = 15.0;
    } else {
      // Winter
      baseTemp = 5.0;
    }

    // Daily temperature curve
    double tempVariation;
    if (hour >= 0 && hour < 6) {
      // Early morning - coolest
      tempVariation = -3.0;
    } else if (hour >= 6 && hour < 12) {
      // Morning - warming
      tempVariation = 0.0;
    } else if (hour >= 12 && hour < 15) {
      // Afternoon - warmest
      tempVariation = 5.0;
    } else if (hour >= 15 && hour < 20) {
      // Evening - cooling
      tempVariation = 2.0;
    } else {
      // Night - cool
      tempVariation = -2.0;
    }

    // Add some randomness
    final random = DateTime.now().millisecondsSinceEpoch % 100 / 100;
    tempVariation += (random * 2) - 1; // -1 to +1

    final temperature = baseTemp + tempVariation;

    // Humidity is often inverse to temperature
    double humidity = 70.0 - (tempVariation * 2);
    humidity = humidity.clamp(30.0, 95.0);

    // Wind often peaks in afternoon
    double windSpeed = 2.0;
    if (hour >= 10 && hour <= 16) {
      windSpeed += 2.0 + random;
    }

    // Solar radiation peaks at noon
    double solarRadiation = 0.0;
    if (hour >= 6 && hour <= 18) {
      solarRadiation = 600.0 * (1 - ((hour - 12).abs() / 6));

      // Lower in winter, higher in summer
      if (month >= 11 || month <= 2) {
        solarRadiation *= 0.7;
      } else if (month >= 5 && month <= 8) {
        solarRadiation *= 1.2;
      }
    }

    return WeatherData(
      timestamp: dateTime,
      temperature: temperature,
      humidity: humidity,
      windSpeed: windSpeed,
      rainfall: random > 0.8 ? random * 2 : 0.0, // 20% chance of rain
      solarRadiation: solarRadiation,
    );
  }

  // Clean up resources
  void dispose() {
    _client.close();
  }
}

