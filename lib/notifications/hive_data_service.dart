import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:farmer_app/Services/auth_services.dart';
import 'package:farmer_app/hive_model.dart';

class HiveDataService {
  static final HiveDataService _instance = HiveDataService._internal();
  factory HiveDataService() => _instance;
  HiveDataService._internal();

  final String _baseUrl = 'http://196.43.168.57/api/v1';

  Hive? _currentHive;
  Timer? _timer;

  final _hiveController = StreamController<Hive>.broadcast();
  Stream<Hive> get hiveStream => _hiveController.stream;

  void startMonitoring(
      {Duration refreshInterval = const Duration(minutes: 5)}) {
    // Cancel existing timer if any
    _timer?.cancel();

    // Set up periodic fetching
    _timer = Timer.periodic(refreshInterval, (timer) async {
      await fetchHiveData(1); // Assuming we're focused on Hive 1
    });
  }

  Future<Hive?> fetchHiveData(int hiveId) async {
    try {
      // Get token from AuthService
      final token = AuthService.getToken();

      if (token.isEmpty) {
        // Check if we can restore token from storage
        final isLoggedIn = await AuthService.isLoggedIn();
        if (!isLoggedIn) {
          throw Exception('User not authenticated');
        }
      }

      // Now get the token again (it may have been restored by isLoggedIn)
      final authToken = AuthService.getToken();

      // Use a short timeout to ensure quick loading or failure
      final response = await http.get(
        Uri.parse('$_baseUrl/farms/1/hives'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> hives = json.decode(response.body);

        for (final hiveData in hives) {
          if (hiveData['id'] == hiveId) {
            final hive = Hive.fromJson(hiveData);
            _currentHive = hive;
            _hiveController.add(hive);
            return hive;
          }
        }

        throw Exception('Hive with ID $hiveId not found');
      } else if (response.statusCode == 401) {
        // Token might be expired
        throw Exception('Authentication failed. Please log in again.');
      } else {
        throw Exception('Failed to load hive data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching hive data: $e');

      // If we have a cached hive, keep using it
      if (_currentHive != null) {
        return _currentHive;
      }

      // Re-throw the error so it can be handled by the caller
      rethrow;
    }
  }

  // Method to handle refresh explicitly
  Future<Hive?> refreshHiveData(int hiveId) async {
    // Clear cache first to ensure fresh data
    _currentHive = null;
    return fetchHiveData(hiveId);
  }

  void dispose() {
    _timer?.cancel();
    _hiveController.close();
  }
}
