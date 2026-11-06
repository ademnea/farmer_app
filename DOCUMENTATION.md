# Farmer App - Technical Documentation

## Table of Contents

1. [Project Structure](#project-structure)
2. [Core Functionalities](#core-functionalities)
3. [Key Components](#key-components)
4. [Bee Counter System](#bee-counter-system)
5. [Analytics and Correlations](#analytics-and-correlations)
6. [Background Services](#background-services)
7. [Data Flow](#data-flow)
8. [UI Components](#ui-components)
9. [Models and Data Structures](#models-and-data-structures)
10. [API Integration](#api-integration)
11. [Security Considerations](#security-considerations)
12. [Troubleshooting](#troubleshooting)
13. [Future Development](#future-development)

## Project Structure

The Farmer App follows a feature-based organization pattern with specialized folders for each functional area. Here's an overview of the main directories:

```
lib/
├── analytics/               # Analytics-related screens and components
├── api/                     # API client and request/response handlers
├── apiary_overview_cards/   # UI components for apiary overview
├── bee_advisory/            # Bee health and advisory screens
├── bee_counter/             # Bee counting system and correlation analysis
├── components/              # Reusable UI components
├── images/                  # Static images used in the app
├── notifications/           # Notification-related components
├── Services/                # Backend services (weather, data processing)
├── utilities/               # Helper utilities and common functions
└── [Root files]             # Main screens and entry points
```

### Key Files Overview

- **main.dart**: Application entry point, initializes services
- **splashscreen.dart**: Initial loading screen
- **login.dart/register.dart**: Authentication screens
- **home.dart**: Main dashboard after login
- **hivedetails.dart**: Detailed view of a specific hive
- **parameter_tab_view.dart**: Tab-based view for hive parameters

## Core Functionalities

### 1. User Authentication

The app provides user registration and login functionality. Authentication is managed through API calls and secure token storage using Flutter Secure Storage.

**Key Files**:
- `login.dart`
- `register.dart`
- `forgot_password.dart`

### 2. Hive Management

The app allows users to manage multiple hives and apiaries, view detailed information, and track various parameters.

**Key Files**:
- `hives.dart`
- `hivedetails.dart`
- `hive_model.dart`
- `apiaries.dart`

### 3. Environmental Monitoring

Real-time monitoring of environmental parameters:

**Key Files**:
- `temperature.dart`
- `humidity.dart`
- `weight.dart`
- `parameter_tab_view.dart`

### 4. Media Management

Capture, store, and view photos and videos of hives:

**Key Files**:
- `media.dart`
- `mediamenu.dart`
- `hivevideos.dart`
- `photo_view_page.dart`

### 5. Bee Activity Analytics

Advanced bee counting and activity correlation:

**Key Files**:
- `bee_counter/bee_monitoring_screen.dart`
- `bee_counter/bee_activity_correlation_screen.dart`
- `bee_counter/integrated_hive_monitoring.dart`

## Key Components

### Bee Counter System

The bee counter system is one of the core functionalities of the app. It utilizes computer vision techniques to count bees entering and exiting the hive, providing valuable data on hive activity.

#### Bee Counter Process Flow:

1. Video capture of hive entrance
2. Frame extraction from video
3. Object detection using TFLite model
4. Bee tracking and counting
5. Data storage in local database
6. Analytics and correlation processing

**Key Components**:

- **bee_counter_model.dart**: Data model for bee counts
- **bee_count_database.dart**: SQLite interface for bee count data
- **bee_monitoring_background_service.dart**: Background service for continuous monitoring
- **bee_count_correlation_repository.dart**: Repository for calculating correlations

### Analytics and Correlations

The analytics system analyzes relationships between bee activity and environmental factors:

- Temperature correlation with bee activity
- Humidity correlation with bee activity
- Weight changes correlation with bee activity
- Time of day correlation with bee activity

The **IntegratedHiveMonitoring** component is central to this functionality, providing visualizations and insights.

**Correlation Calculation Flow**:

1. Collect bee count data for specified period
2. Collect environmental data for same period
3. Calculate Pearson correlation coefficients
4. Generate insights based on correlation strengths
5. Present visualizations with correlated data

### Background Services

The app uses Flutter Background Service to continue monitoring and data collection even when the app is not in the foreground.

**Key Files**:
- `bee_counter/bee_monitoring_background_service.dart`
- `Services/notifi_service.dart`

**Service Initialization**:
```dart
// Initialized in main.dart
final monitoringService = BeeMonitoringService();
await monitoringService.initializeService();
```

## Data Flow

### 1. Data Collection

- Environmental sensors collect temperature, humidity, and weight data
- Bee counter system collects bee activity data
- Weather API provides external weather data

### 2. Data Processing

- Raw data is processed and normalized
- Data is stored in local SQLite database
- Correlations and statistics are calculated

### 3. Data Presentation

- Charts and visualizations display processed data
- Insights are generated based on correlation analysis
- Alerts and notifications are triggered based on conditions

## UI Components

### Main Screens

1. **Splash Screen**: Initial loading screen
2. **Login/Register**: Authentication screens
3. **Home Dashboard**: Overview of all apiaries and hives
4. **Hive Details**: Detailed view of a specific hive
5. **Parameter Views**: Specialized views for temperature, humidity, weight
6. **Bee Activity**: Bee count and correlation screens
7. **Media Gallery**: Photos and videos of hives

### Charts and Visualizations

The app uses multiple charting libraries:

- **FL Chart**: Used for line and bar charts
- **Flutter ECharts**: Used for more complex visualizations and correlations

**Example of ECharts usage in IntegratedHiveMonitoring**:

```dart
Widget _buildTemperatureChart() {
  // Data preparation
  final options = {
    'tooltip': { /* ... */ },
    'legend': { /* ... */ },
    'xAxis': [ /* ... */ ],
    'yAxis': [ /* ... */ ],
    'series': [ /* ... */ ]
  };
  
  return Container(
    height: 400,
    child: Echarts(
      option: '''${json.encode(options)}''',
      extraScript: '/* ... */'
    ),
  );
}
```

## Models and Data Structures

### Key Models

1. **HiveModel**: Represents a beehive with all its properties
2. **BeeCount**: Represents a single bee count data point
3. **WeatherData**: Represents weather data for correlation analysis

**Example of BeeCount Model**:

```dart
class BeeCount {
  final int id;
  final String hiveId;
  final DateTime timestamp;
  final int beesEntering;
  final int beesExiting;
  final int totalActivity;
  
  BeeCount({
    this.id = 0,
    required this.hiveId,
    required this.timestamp,
    required this.beesEntering,
    required this.beesExiting,
  }) : totalActivity = beesEntering + beesExiting;
  
  // Factory methods and conversion utilities
  // ...
}
```

## Bee Counter and Correlation Features

### Integrated Hive Monitoring

The `IntegratedHiveMonitoring` component is a central feature that combines:

1. Temperature data visualization
2. Humidity data visualization
3. Weight data visualization
4. Bee count data visualization
5. Correlation analysis between metrics
6. Smart insights based on correlations

**Key Features**:

- **Correlation Calculation**: Calculates Pearson correlation coefficients between environmental factors and bee activity
- **Data Caching**: Implements caching to improve performance
- **Dynamic Insights**: Generates actionable insights based on correlation strengths
- **Interactive Charts**: Provides interactive visualizations of related data

**Correlation Repository**:

The `BeeCountCorrelationRepository` handles:

1. Data retrieval and caching
2. Correlation calculations
3. Insight generation
4. Weather data integration

**Sample Insight Generation**:

```dart
Map<String, String> generateDataInsights(Map<String, double> correlations) {
  final Map<String, String> insights = {};

  correlations.forEach((factor, correlation) {
    final absValue = correlation.abs();
    String insight = '';
    
    // Determine insight based on correlation strength
    if (absValue < 0.1) {
      insight = 'No significant relationship found...';
    } else if (absValue < 0.3) {
      insight = correlation > 0 
        ? 'Slight increase in bee activity with higher $factor.'
        : 'Slight decrease in bee activity with higher $factor.';
    }
    // More correlation levels...
    
    // Add specific advice for each factor
    switch (factor) {
      case 'Temperature':
        if (correlation > 0.3) {
          insight += ' Consider monitoring on cooler days to reduce stress on colonies.';
        }
        // More specific advice...
        break;
      // Other factors...
    }
    
    insights[factor] = insight;
  });

  return insights;
}
```

## API Integration

The app integrates with external APIs for:

1. Weather data retrieval
2. Possible future integration with IoT devices

**Weather Service**:

```dart
class WeatherService {
  static const String _apiKey = '...';
  static const String _baseUrl = '...';
  
  // Get current weather data
  static Future<Map<String, dynamic>> getCurrentWeather({
    String location = 'auto:ip',
  }) async {
    // API call implementation
  }
  
  // Get weather data for date range
  static Future<Map<DateTime, dynamic>> getWeatherDataForDateRange(
    DateTime startDate,
    DateTime endDate, {
    String location = 'auto:ip',
  }) async {
    // Implementation
  }
}
```

## Security Considerations

The app implements several security measures:

1. **Secure Storage**: Sensitive data like authentication tokens are stored using Flutter Secure Storage
2. **HTTPS**: All API communications use HTTPS
3. **Input Validation**: User inputs are validated before processing

## Troubleshooting

Common issues and solutions:

1. **Bee Counter Not Working**:
   - Check camera permissions
   - Verify TFLite model is correctly loaded
   - Ensure device has sufficient processing power

2. **Charts Not Displaying Data**:
   - Check database connection
   - Verify data retrieval process
   - Check date range selection

3. **Background Service Issues**:
   - Verify background permissions
   - Check battery optimization settings
   - Restart the service in app settings

## Future Development

Planned features and improvements:

1. **Enhanced AI Analytics**:
   - More advanced correlation models
   - Predictive analytics for honey production
   - Anomaly detection for early problem identification

2. **Integration with More IoT Devices**:
   - Direct connection to commercial hive monitoring sensors
   - Support for custom Arduino/Raspberry Pi sensor setups

3. **Expanded Visualization**:
   - 3D visualization of hive data
   - Time-series forecasting
   - Comparative analysis between hives

4. **Community Features**:
   - Data sharing between beekeepers
   - Community insights and recommendations

## Development Guidelines

For developers continuing work on this project:

1. **Code Style**:
   - Follow Flutter's style guide
   - Use meaningful variable and function names
   - Document complex functions and components

2. **Architecture**:
   - Maintain separation of concerns
   - Use repositories for data access
   - Keep UI and business logic separate

3. **Testing**:
   - Write unit tests for business logic
   - Create widget tests for UI components
   - Perform integration tests for key workflows

4. **Performance**:
   - Implement caching where appropriate
   - Optimize database queries
   - Be mindful of memory usage with large datasets
