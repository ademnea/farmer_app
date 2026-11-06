import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:HPGM/notifications/weather_model.dart';

class WeatherService {
  static const String _apiKey = 'pk5l7f3uii8c19rkzyr20z5b8liieenq1boytiqi';
  static const String _baseUrl =
      'https://www.meteosource.com/api/v1/free/point';

  // Get current weather data
  static Future<Map<String, dynamic>> getCurrentWeather({
    String location = 'auto:ip', // Default to IP-based location
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/current.json?key=$_apiKey&q=$location'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error fetching weather: ${response.statusCode}');
        return {'error': 'Failed to load weather data: ${response.statusCode}'};
      }
    } catch (e) {
      print('Exception when fetching weather: $e');
      return {'error': 'Exception when fetching weather: $e'};
    }
  }

  // Get weather data for a specific date (historical data)
  static Future<Map<String, dynamic>> getWeatherForDate(
    DateTime date, {
    String location = 'auto:ip',
  }) async {
    // If date is today or in the future, use forecast API
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (date.isAfter(today) || date.isAtSameMomentAs(today)) {
      return _getForecast(date, location: location);
    } else {
      // For past dates, use historical API
      return _getHistoricalWeather(date, location: location);
    }
  }

  // Get historical weather data
  static Future<Map<String, dynamic>> _getHistoricalWeather(
    DateTime date, {
    String location = 'auto:ip',
  }) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/history.json?key=$_apiKey&q=$location&dt=$dateStr',
        ),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error fetching historical weather: ${response.statusCode}');
        return {
          'error':
              'Failed to load historical weather data: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Exception when fetching historical weather: $e');
      return {'error': 'Exception when fetching historical weather: $e'};
    }
  }

  // Get forecast weather data
  static Future<Map<String, dynamic>> _getForecast(
    DateTime date, {
    String location = 'auto:ip',
  }) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Calculate days ahead (0 for today, 1 for tomorrow, etc.)
      final daysAhead = date.difference(today).inDays;

      // Weather API allows forecasts up to 14 days
      if (daysAhead > 14) {
        return {'error': 'Cannot forecast more than 14 days ahead'};
      }

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/forecast.json?key=$_apiKey&q=$location&days=${daysAhead + 1}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract the forecast for the specific date
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final forecastDays = data['forecast']['forecastday'] as List;

        for (var day in forecastDays) {
          if (day['date'] == dateStr) {
            // Format the data to match the structure expected by the app
            return {
              'location': data['location'],
              'current': day['day'],
              'forecast': {
                'forecastday': [day],
              },
            };
          }
        }

        return {'error': 'No forecast data available for the specified date'};
      } else {
        print('Error fetching forecast: ${response.statusCode}');
        return {
          'error': 'Failed to load forecast data: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Exception when fetching forecast: $e');
      return {'error': 'Exception when fetching forecast: $e'};
    }
  }

  // Get weather data for a date range
  static Future<List<Map<String, dynamic>>> getWeatherForDateRange(
    DateTime startDate,
    DateTime endDate, {
    String location = 'auto:ip',
  }) async {
    List<Map<String, dynamic>> results = [];

    // Clone the start date to avoid modifying the original
    DateTime currentDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    // Fetch weather data for each day in the range
    while (!currentDate.isAfter(endDate)) {
      final weatherData = await getWeatherForDate(
        currentDate,
        location: location,
      );
      results.add(weatherData);

      // Move to the next day
      currentDate = currentDate.add(Duration(days: 1));
    }

    return results;
  }

  // Get weather data for a date range
  static Future<Map<DateTime, dynamic>> getWeatherDataForDateRange(
    DateTime startDate,
    DateTime endDate, {
    String location = 'auto:ip',
  }) async {
    // Create a map of DateTime -> WeatherData
    Map<DateTime, dynamic> weatherByDate = {};

    // Clone the start date to avoid modifying the original
    DateTime currentDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    // For each day in the range, get weather summary
    while (!currentDate.isAfter(endDate)) {
      final weatherSummary = await getWeatherSummary(
        currentDate,
        location: location,
      );

      // Store data by date
      weatherByDate[DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
      )] = weatherSummary;

      // Move to next day
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return weatherByDate;
  }

  // Get weather summary for a specific date
  static Future<Map<String, dynamic>> getWeatherSummary(
    DateTime date, {
    String location = 'auto:ip',
  }) async {
    final weatherData = await getWeatherForDate(date, location: location);

    if (weatherData.containsKey('error')) {
      return weatherData;
    }

    // Extract key weather metrics for bee foraging analysis
    try {
      Map<String, dynamic> summary = {};

      if (weatherData.containsKey('current')) {
        final current = weatherData['current'];

        // Temperature
        if (current.containsKey('temp_c')) {
          summary['temperature'] = current['temp_c'];
        } else if (current.containsKey('avgtemp_c')) {
          summary['temperature'] = current['avgtemp_c'];
        }

        // Humidity
        if (current.containsKey('humidity')) {
          summary['humidity'] = current['humidity'];
        } else if (current.containsKey('avghumidity')) {
          summary['humidity'] = current['avghumidity'];
        }

        // Wind speed
        if (current.containsKey('wind_kph')) {
          summary['windSpeed'] = current['wind_kph'];
        } else if (current.containsKey('maxwind_kph')) {
          summary['windSpeed'] = current['maxwind_kph'];
        }

        // Precipitation
        if (current.containsKey('precip_mm')) {
          summary['precipitation'] = current['precip_mm'];
        } else if (current.containsKey('totalprecip_mm')) {
          summary['precipitation'] = current['totalprecip_mm'];
        }

        // UV index
        if (current.containsKey('uv')) {
          summary['uvIndex'] = current['uv'];
        }

        // Condition
        if (current.containsKey('condition')) {
          summary['condition'] = current['condition'];
        }
      }

      // Add location information
      if (weatherData.containsKey('location')) {
        summary['location'] = weatherData['location'];
      }

      return summary;
    } catch (e) {
      print('Error extracting weather summary: $e');
      return {'error': 'Error extracting weather summary: $e'};
    }
  }

  Future<WeatherData> getWeatherData(double latitude, double longitude) async {
    // TODO: Implement the logic to fetch weather data using latitude and longitude.
    // For now, return a dummy WeatherData object or fetch from your API.
    // Replace the following line with your actual implementation.
    return WeatherData(
      temperature: 25.0,
      humidity: 60.0,
      windSpeed: 12.0,
      condition: 'Sunny',
      timestamp: DateTime.now(),
      // Add other required fields as per your WeatherData model
    );
  }
}
