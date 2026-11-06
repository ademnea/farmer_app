import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:farmer_app/notifications/notification_model.dart';
import 'package:farmer_app/hive_model.dart';
import 'package:farmer_app/notifications/weather_data_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<HiveNotification> _notifications = [];
  final _notificationsController =
      StreamController<List<HiveNotification>>.broadcast();
  Stream<List<HiveNotification>> get notificationsStream =>
      _notificationsController.stream;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Thresholds for different parameters
  final Map<String, Map<String, dynamic>> _thresholds = {
    'temperature': {
      'min': 20.0,
      'max': 35.0,
      'critical_min': 15.0,
      'critical_max': 40.0,
    },
    'humidity': {
      'min': 40.0,
      'max': 80.0,
      'critical_min': 30.0,
      'critical_max': 90.0,
    },
    'weight': {
      'min': 10.0,
      'max': 30.0,
      'critical_min': 5.0,
      'critical_max': 35.0,
    },
    'carbon_dioxide': {
      'min': 400,
      'max': 5000,
      'critical_min': 300,
      'critical_max': 8000,
    },
  };

  // Weather thresholds
  final Map<String, Map<String, dynamic>> _weatherThresholds = {
    'temperature': {
      'min': 5.0,
      'max': 35.0,
    },
    'humidity': {
      'min': 30.0,
      'max': 90.0,
    },
    'wind_speed': {
      'max': 30.0, // km/h
    },
  };

  Future<void> init() async {
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  List<HiveNotification> get notifications => List.unmodifiable(_notifications);

  void addNotification(HiveNotification notification) {
    _notifications.insert(0, notification);
    _notificationsController.add(_notifications);
    _showLocalNotification(notification);
  }

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _notificationsController.add(_notifications);
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    _notificationsController.add(_notifications);
  }

  void clearNotifications() {
    _notifications.clear();
    _notificationsController.add(_notifications);
  }

  Future<void> _showLocalNotification(HiveNotification notification) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'beehive_monitoring_channel',
      'Beehive Monitoring',
      channelDescription: 'Notifications for beehive monitoring',
      importance: Importance.high,
      priority: Priority.high,
      color: notification.color,
      icon: '@drawable/app_icon', // Use drawable icon for notifications
    );

    DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.message,
      platformChannelSpecifics,
    );
  }

  // Check hive data against thresholds and generate notifications
  void checkHiveData(Hive hive) {
    if (hive.id != 1) return; // Only focus on Hive 1 as requested

    // Check temperature
    if (hive.temperature != null) {
      _checkParameter(
        hive.id,
        'temperature',
        hive.temperature!,
        NotificationType.temperature,
        'Interior Temperature',
        '°C',
      );
    }

    // Check humidity
    if (hive.humidity != null) {
      _checkParameter(
        hive.id,
        'humidity',
        hive.humidity!,
        NotificationType.humidity,
        'Interior Humidity',
        '%',
      );
    }

    // Check weight
    if (hive.weight != null) {
      _checkParameter(
        hive.id,
        'weight',
        hive.weight!,
        NotificationType.weight,
        'Hive Weight',
        'kg',
      );
    }

    // Check carbon dioxide
    if (hive.carbonDioxide != null) {
      _checkParameter(
        hive.id,
        'carbon_dioxide',
        hive.carbonDioxide!.toDouble(),
        NotificationType.carbonDioxide,
        'Carbon Dioxide',
        'ppm',
      );
    }

    // Check connection status
    if (!hive.isConnected) {
      _addConnectionNotification(hive.id);
    }

    // Check colonization status
    if (!hive.isColonized) {
      _addColonizationNotification(hive.id);
    }
  }

  void _checkParameter(
    int hiveId,
    String paramName,
    double value,
    NotificationType type,
    String displayName,
    String unit,
  ) {
    final thresholds = _thresholds[paramName]!;

    // Check critical thresholds first
    if (value < thresholds['critical_min']) {
      _addParameterNotification(
        hiveId,
        type,
        NotificationSeverity.high,
        'Critical Low $displayName',
        'Hive $hiveId has critically low $displayName: $value$unit (below ${thresholds['critical_min']}$unit)',
        value,
        unit,
      );
    } else if (value > thresholds['critical_max']) {
      _addParameterNotification(
        hiveId,
        type,
        NotificationSeverity.high,
        'Critical High $displayName',
        'Hive $hiveId has critically high $displayName: $value$unit (above ${thresholds['critical_max']}$unit)',
        value,
        unit,
      );
    }
    // Check warning thresholds
    else if (value < thresholds['min']) {
      _addParameterNotification(
        hiveId,
        type,
        NotificationSeverity.medium,
        'Low $displayName',
        'Hive $hiveId has low $displayName: $value$unit (below ${thresholds['min']}$unit)',
        value,
        unit,
      );
    } else if (value > thresholds['max']) {
      _addParameterNotification(
        hiveId,
        type,
        NotificationSeverity.medium,
        'High $displayName',
        'Hive $hiveId has high $displayName: $value$unit (above ${thresholds['max']}$unit)',
        value,
        unit,
      );
    }
  }

  void _addParameterNotification(
    int hiveId,
    NotificationType type,
    NotificationSeverity severity,
    String title,
    String message,
    double value,
    String unit,
  ) {
    // Check if a similar notification already exists
    final existingNotification = _notifications.firstWhere(
      (n) => n.type == type && n.severity == severity && !n.isRead,
      orElse: () => HiveNotification(
        id: '',
        title: '',
        message: '',
        timestamp: DateTime.now(),
        type: type,
        severity: severity,
        hiveId: hiveId,
      ),
    );

    if (existingNotification.id.isEmpty) {
      final notification = HiveNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        message: message,
        timestamp: DateTime.now(),
        type: type,
        severity: severity,
        hiveId: hiveId,
        data: {
          'value': value,
          'unit': unit,
        },
      );

      addNotification(notification);
    }
  }

  void _addConnectionNotification(int hiveId) {
    final existingNotification = _notifications.firstWhere(
      (n) => n.type == NotificationType.connection && !n.isRead,
      orElse: () => HiveNotification(
        id: '',
        title: '',
        message: '',
        timestamp: DateTime.now(),
        type: NotificationType.connection,
        severity: NotificationSeverity.high,
        hiveId: hiveId,
      ),
    );

    if (existingNotification.id.isEmpty) {
      final notification = HiveNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Connection Lost',
        message: 'Hive $hiveId has lost connection. Please check the device.',
        timestamp: DateTime.now(),
        type: NotificationType.connection,
        severity: NotificationSeverity.high,
        hiveId: hiveId,
      );

      addNotification(notification);
    }
  }

  void _addColonizationNotification(int hiveId) {
    final existingNotification = _notifications.firstWhere(
      (n) => n.type == NotificationType.colonization && !n.isRead,
      orElse: () => HiveNotification(
        id: '',
        title: '',
        message: '',
        timestamp: DateTime.now(),
        type: NotificationType.colonization,
        severity: NotificationSeverity.medium,
        hiveId: hiveId,
      ),
    );

    if (existingNotification.id.isEmpty) {
      final notification = HiveNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Hive Not Colonized',
        message: 'Hive $hiveId is not colonized. Consider checking for issues.',
        timestamp: DateTime.now(),
        type: NotificationType.colonization,
        severity: NotificationSeverity.medium,
        hiveId: hiveId,
      );

      addNotification(notification);
    }
  }

  // Check weather data against thresholds
  void checkWeatherData(WeatherData weatherData) {
    // Check temperature
    if (weatherData.temperature < _weatherThresholds['temperature']!['min']) {
      _addWeatherNotification(
        'Low External Temperature',
        'External temperature is ${weatherData.temperature}°C, which may affect your hives.',
        NotificationSeverity.medium,
        weatherData,
      );
    } else if (weatherData.temperature >
        _weatherThresholds['temperature']!['max']) {
      _addWeatherNotification(
        'High External Temperature',
        'External temperature is ${weatherData.temperature}°C, which may affect your hives.',
        NotificationSeverity.medium,
        weatherData,
      );
    }

    // Check humidity
    if (weatherData.humidity < _weatherThresholds['humidity']!['min']) {
      _addWeatherNotification(
        'Low External Humidity',
        'External humidity is ${weatherData.humidity}%, which may affect your hives.',
        NotificationSeverity.low,
        weatherData,
      );
    } else if (weatherData.humidity > _weatherThresholds['humidity']!['max']) {
      _addWeatherNotification(
        'High External Humidity',
        'External humidity is ${weatherData.humidity}%, which may affect your hives.',
        NotificationSeverity.medium,
        weatherData,
      );
    }

    // Check wind speed
    if (weatherData.windSpeed > _weatherThresholds['wind_speed']!['max']) {
      _addWeatherNotification(
        'High Wind Speed',
        'Wind speed is ${weatherData.windSpeed} km/h, which may affect your hives.',
        NotificationSeverity.high,
        weatherData,
      );
    }

    // Check for rain
    if (weatherData.isRaining) {
      _addWeatherNotification(
        'Rain Detected',
        'Rain has been detected in your area. Consider checking your hives.',
        NotificationSeverity.medium,
        weatherData,
      );
    }
  }

  void _addWeatherNotification(
    String title,
    String message,
    NotificationSeverity severity,
    WeatherData weatherData,
  ) {
    final existingNotification = _notifications.firstWhere(
      (n) => n.title == title && !n.isRead,
      orElse: () => HiveNotification(
        id: '',
        title: '',
        message: '',
        timestamp: DateTime.now(),
        type: NotificationType.weather,
        severity: severity,
        hiveId: 1, // Default to Hive 1
      ),
    );

    if (existingNotification.id.isEmpty) {
      final notification = HiveNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        message: message,
        timestamp: DateTime.now(),
        type: NotificationType.weather,
        severity: severity,
        hiveId: 1, // Default to Hive 1
        data: weatherData.toJson(),
      );

      addNotification(notification);
    }
  }

  void dispose() {
    _notificationsController.close();
  }
}
