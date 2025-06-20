# IntegratedHiveMonitoring Component Documentation

## Overview

The `IntegratedHiveMonitoring` component is a core feature of the Farmer App's bee activity analysis system. It provides a comprehensive view of the relationships between environmental factors (temperature, humidity, weight) and bee activity. This component combines data visualization, correlation analysis, and actionable insights to help beekeepers make informed decisions about hive management.

## Table of Contents

1. [Component Structure](#component-structure)
2. [Data Flow](#data-flow)
3. [Key Features](#key-features)
4. [Technical Implementation](#technical-implementation)
5. [UI Elements](#ui-elements)
6. [Data Visualization](#data-visualization)
7. [Correlation Analysis](#correlation-analysis)
8. [Usage Examples](#usage-examples)
9. [Extension Points](#extension-points)

## Component Structure

The `IntegratedHiveMonitoring` component consists of:

1. **StatefulWidget**: The main widget class that manages state
2. **State Class**: Handles UI rendering and data management
3. **Data Repository**: `BeeCountCorrelationRepository` for data retrieval and analysis
4. **Chart Components**: Multiple visualization components for different metrics
5. **Insight Generation**: Logic to generate actionable insights from correlations

## Data Flow

```
┌───────────────────────┐     ┌────────────────────────────┐     ┌───────────────────┐
│                       │     │                            │     │                   │
│  Environmental Data   │────▶│ BeeCountCorrelationRepo   │────▶│  Data Processing  │
│  (Temp, Humidity,     │     │ (Caching, Data Retrieval)  │     │  (Correlation     │
│   Weight, Weather)    │     │                            │     │   Calculation)    │
│                       │     │                            │     │                   │
└───────────────────────┘     └────────────────────────────┘     └─────────┬─────────┘
                                                                           │
                                                                           ▼
```

The data flows from environmental sensors and bee counters through the correlation repository, which then processes this data to calculate correlations and generate insights. These insights are then visualized in the UI.

## Key Features
│                       │     │                            │     │                   │
│  User Interface       │◀────│  Visualization Components  │◀────│  Insight         │
│  (Interactive Charts, │     │  (Charts, Tooltips,        │     │  Generation      │
│   Insights Display)   │     │   Correlation Display)     │     │  (Smart Analysis) │
│                       │     │                            │     │                   │
└───────────────────────┘     └────────────────────────────┘     └───────────────────┘
```

## Key Features

### 1. Multi-Parameter Visualization

The component combines multiple environmental parameters and bee activity metrics in a unified view:

- **Temperature Charts**: Line charts showing temperature trends
- **Humidity Charts**: Line charts showing humidity levels
- **Weight Charts**: Line charts showing hive weight changes
- **Bee Activity Charts**: Bar charts showing bee entries and exits
- **Combined View**: Overlay chart showing all parameters in a single view

### 2. Correlation Analysis

Calculates and visualizes correlations between environmental factors and bee activity:

- **Correlation Coefficients**: Pearson correlation calculations
- **Heatmap Display**: Visual representation of correlation strengths
- **Scatter Plots**: Showing relationships between metrics
- **Trend Indicators**: Visual cues showing correlation direction

### 3. Smart Insights

Generates actionable insights based on correlation analysis:

- **Automated Recommendations**: Suggestions based on correlation strengths
- **Threshold Alerts**: Notifications when correlations exceed thresholds
- **Historical Comparison**: Comparison with historical correlation patterns
- **Behavioral Predictions**: Predictive insights based on current trends

### 4. Interactive Features

Provides user interaction capabilities:

- **Date Range Selection**: Adjustable time periods for analysis
- **Parameter Toggling**: Show/hide specific metrics
- **Detail Exploration**: Zoom and pan functionality
- **Export Options**: Data and visualization export capabilities

## Technical Implementation

### Widget Structure

The `IntegratedHiveMonitoring` widget is structured as:

```dart
class IntegratedHiveMonitoring extends StatefulWidget {
  final String hiveId;
  final DateTime startDate;
  final DateTime endDate;
  final bool showTemperature;
  final bool showHumidity;
  final bool showWeight;
  
  // Constructor and other code...
  
  @override
  _IntegratedHiveMonitoringState createState() => _IntegratedHiveMonitoringState();
}

class _IntegratedHiveMonitoringState extends State<IntegratedHiveMonitoring> {
  // State variables
  late BeeCountCorrelationRepository _repository;
  Map<DateTime, Map<String, dynamic>> _combinedData = {};
  Map<String, double> _correlations = {};
  Map<String, String> _insights = {};
  bool _isLoading = true;
  
  // Lifecycle methods, build method, helper methods...
}
```

### Data Retrieval and Processing

Data is retrieved and processed through these main methods:

```dart
Future<void> _loadData() async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Fetch bee count data
    final beeCountData = await _repository.getBeeCountsForPeriod(
      widget.hiveId,
      widget.startDate,
      widget.endDate,
    );
    
    // Fetch environmental data
    final temperatureData = widget.showTemperature ? 
      await _repository.getTemperatureDataForPeriod(widget.hiveId, widget.startDate, widget.endDate) : 
      {};
    
    // Similar for humidity and weight...
    
    // Combine all data by timestamp
    _combinedData = _combineDataByTimestamp(beeCountData, temperatureData, humidityData, weightData);
    
    // Calculate correlations
    _correlations = _calculateCorrelations(_combinedData);
    
    // Generate insights
    _insights = _generateInsights(_correlations);
  } catch (e) {
    // Error handling
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
```

### Visualization Components

The component uses multiple visualization methods:

```dart
Widget _buildTemperatureChart() {
  // Implementation for temperature chart
}

Widget _buildHumidityChart() {
  // Implementation for humidity chart
}

Widget _buildWeightChart() {
  // Implementation for weight chart
}

Widget _buildBeeActivityChart() {
  // Implementation for bee activity chart
}

Widget _buildCombinedChart() {
  // Implementation for combined metrics chart
}

Widget _buildCorrelationHeatmap() {
  // Implementation for correlation heatmap
}
```

### Correlation Calculation

Correlations are calculated using the Pearson correlation coefficient:

```dart
Map<String, double> _calculateCorrelations(Map<DateTime, Map<String, dynamic>> combinedData) {
  final Map<String, double> correlations = {};
  
  // Extract data series
  final List<double> beeActivity = [];
  final Map<String, List<double>> environmentalFactors = {
    'Temperature': [],
    'Humidity': [],
    'Weight': []
  };
  
  // Populate data series from combined data
  combinedData.forEach((timestamp, data) {
    if (data.containsKey('beeActivity') && data['beeActivity'] != null) {
      beeActivity.add(data['beeActivity'].toDouble());
      
      if (data.containsKey('temperature') && data['temperature'] != null) {
        environmentalFactors['Temperature']!.add(data['temperature'].toDouble());
      }
      // Similar for humidity and weight...
    }
  });
  
  // Calculate correlation for each factor
  environmentalFactors.forEach((factor, values) {
    if (values.length == beeActivity.length && values.isNotEmpty) {
      correlations[factor] = _calculatePearsonCorrelation(beeActivity, values);
    }
  });
  
  return correlations;
}

double _calculatePearsonCorrelation(List<double> x, List<double> y) {
  // Implementation of Pearson correlation formula
  // ...
}
```

### Insight Generation

Insights are generated based on correlation strengths:

```dart
Map<String, String> _generateInsights(Map<String, double> correlations) {
  final Map<String, String> insights = {};
  
  correlations.forEach((factor, correlation) {
    final absValue = correlation.abs();
    String insight = '';
    
    // Generate insight based on correlation strength
    if (absValue < 0.2) {
      insight = 'No significant relationship detected between bee activity and $factor.';
    } else if (absValue < 0.4) {
      insight = correlation > 0 
        ? 'Weak positive relationship: Bee activity tends to increase slightly with higher $factor.'
        : 'Weak negative relationship: Bee activity tends to decrease slightly with higher $factor.';
    } else if (absValue < 0.6) {
      insight = correlation > 0
        ? 'Moderate positive relationship: Bee activity shows notable increase with higher $factor.'
        : 'Moderate negative relationship: Bee activity shows notable decrease with higher $factor.';
    } else {
      insight = correlation > 0
        ? 'Strong positive relationship: Bee activity strongly increases with higher $factor.'
        : 'Strong negative relationship: Bee activity strongly decreases with higher $factor.';
    }
    
    // Add specific advice based on the factor
    switch (factor) {
      case 'Temperature':
        if (correlation > 0.4) {
          insight += ' Consider monitoring hive ventilation during high temperatures.';
        } else if (correlation < -0.4) {
          insight += ' Consider additional insulation during cooler periods.';
        }
        break;
      
      // Similar for other factors...
    }
    
    insights[factor] = insight;
  });
  
  return insights;
}
```

## UI Elements

### Main Layout Structure

The component follows this layout structure:

```
┌─────────────────────────────────────────────┐
│ Header (Title, Date Range Selector)         │
├─────────────────────────────────────────────┤
│ Tabs (All, Temperature, Humidity, Weight)   │
├─────────────────────────────────────────────┤
│                                             │
│ Selected Chart View                         │
│ (Based on selected tab)                     │
│                                             │
├─────────────────────────────────────────────┤
│ Correlation Analysis Section                │
│ ┌─────────────────┐  ┌─────────────────┐   │
│ │ Correlation     │  │ Insights        │   │
│ │ Heatmap/Chart   │  │ & Suggestions   │   │
│ └─────────────────┘  └─────────────────┘   │
├─────────────────────────────────────────────┤
│ Action Buttons                              │
└─────────────────────────────────────────────┘
```

### Interactive Elements

- **Date Range Selector**: Calendar-based date range picker
- **Tab Navigation**: Tab bar for switching between views
- **Chart Interactions**: Zoom, pan, and tooltip interactions
- **Toggle Switches**: Controls for showing/hiding metrics
- **Export Button**: Option to export data or visualizations

## Usage Examples

### Basic Implementation

```dart
IntegratedHiveMonitoring(
  hiveId: '123',
  startDate: DateTime.now().subtract(Duration(days: 7)),
  endDate: DateTime.now(),
  showTemperature: true,
  showHumidity: true,
  showWeight: true,
)
```

### With Custom Configuration

```dart
IntegratedHiveMonitoring(
  hiveId: '123',
  startDate: startDate,
  endDate: endDate,
  showTemperature: showTemp,
  showHumidity: showHumidity,
  showWeight: showWeight,
  onInsightGenerated: (insights) {
    // Custom handling of generated insights
  },
  theme: ThemeData(
    // Custom theme for charts
  ),
)
```

## Extension Points

The component is designed to be extensible in several ways:

1. **Additional Environmental Factors**: The architecture supports adding new environmental factors beyond temperature, humidity, and weight
2. **Custom Visualization Styles**: The chart rendering can be customized with different styles and themes
3. **Alternative Correlation Methods**: The correlation calculation can be replaced with different statistical methods
4. **Custom Insight Generators**: The insight generation logic can be extended or replaced

## Best Practices for Use

1. **Date Range Selection**: Use reasonable date ranges (1-4 weeks) for optimal visualization
2. **Data Quality**: Ensure regular data collection for meaningful correlations
3. **Context Consideration**: Interpret correlations in the context of seasonal variations
4. **Complementary Analysis**: Use alongside other monitoring tools for comprehensive hive management

## Known Limitations

1. **Data Density Requirement**: Reliable correlations require sufficient data points
2. **Causation vs. Correlation**: Correlations do not necessarily indicate causation
3. **Performance Considerations**: Large datasets may impact rendering performance on lower-end devices
4. **Environmental Context**: Local environmental factors beyond measured parameters may influence results

## Future Enhancements

1. **Machine Learning Integration**: Incorporate predictive models for bee behavior
2. **Additional Correlation Factors**: Include external factors like pollen availability and flowering schedules
3. **Real-time Monitoring**: Support for live data updates from connected sensors
4. **Advanced Visualization**: Incorporate 3D visualizations of hive conditions
│                       │     │                            │     │                   │
│   User Interaction    │◀────│    UI Rendering            │◀────│  Visualization    │
│   (Date Selection,    │     │    (Charts, Insights,      │     │  Preparation      │
│    Tab Navigation)    │     │     Tab Views)             │     │                   │
│                       │     │                            │     │                   │
└───────────────────────┘     └────────────────────────────┘     └───────────────────┘
```

## Key Features

### 1. Integrated Data Visualization

The component provides unified visualizations for:
- Temperature data with bee activity overlay
- Humidity data with bee activity overlay
- Weight data with bee activity overlay
- Combined view of all metrics

### 2. Correlation Analysis

- Calculates Pearson correlation coefficients between:
  - Temperature and bee activity
  - Humidity and bee activity
  - Hive weight and bee activity
  - Time of day and bee activity
  - Weather conditions and bee activity

### 3. Smart Insights

- Generates actionable insights based on correlation strengths
- Provides specific recommendations for each environmental factor
- Adapts recommendations based on correlation values

### 4. Data Caching

- Implements efficient caching mechanism to improve performance
- Reduces redundant API calls and database queries
- Automatically refreshes data when needed

### 5. Interactive UI

- Date range selection for customized analysis periods
- Tab-based navigation between different metrics
- Interactive charts with tooltips and click events
- Visual indicators of correlation strengths

## Technical Implementation

### Widget Initialization

```dart
class IntegratedHiveMonitoring extends StatefulWidget {
  final String hiveId;
  final String token;

  const IntegratedHiveMonitoring({
    Key? key,
    required this.hiveId,
    required this.token,
  }) : super(key: key);

  @override
  _IntegratedHiveMonitoringState createState() => _IntegratedHiveMonitoringState();
}
```

### State Management

The component maintains several state variables:
- Date range (`_startDate`, `_endDate`)
- Loading state (`_isLoading`)
- Error messages (`_errorMessage`)
- Metric values (`_metricValues`)
- Correlation values (`_correlations`)
- Generated insights (`_insights`)

### Data Loading Process

The data loading process occurs in the `_loadData` method:

1. Set loading state
2. Calculate correlations using repository
3. Generate insights based on correlations
4. Prepare chart data from multiple sources
5. Update state with loaded data

```dart
Future<void> _loadData() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });
  
  try {
    // Calculate correlations
    final timeRangeDays = _endDate.difference(_startDate).inDays;
    final correlations = await _repository.calculateCorrelations(
      widget.hiveId,
      timeRangeDays,
    );
    
    // Generate insights
    final insights = _repository.generateDataInsights(correlations);
    
    // Prepare data for charts
    await _prepareChartData();
    
    setState(() {
      _correlations = correlations;
      _insights = insights;
      _isLoading = false;
    });
  } catch (e) {
    setState(() {
      _isLoading = false;
      _errorMessage = 'Error loading data: $e';
    });
  }
}
```

### Chart Data Preparation

The chart data preparation involves fetching data from multiple sources:

```dart
Future<void> _prepareChartData() async {
  try {
    // Clear previous data
    _dates.clear();
    _metricValues.forEach((key, value) => value.clear());
    
    // Fetch temperature data from API
    await _fetchTemperatureData();
    
    // Fetch humidity data from API
    await _fetchHumidityData();
    
    // Fetch weight data from API
    await _fetchWeightData();
    
    // Fetch bee count data from local database
    await _fetchBeeCountData();
    
    // Sort dates to ensure chronological order
    _dates.sort();
  } catch (e) {
    print('Error preparing chart data: $e');
    rethrow;
  }
}
```

## UI Elements

### Main Layout Structure

The component's UI is structured with a tab-based interface:

```
┌────────────────────────────────────────────────────┐
│ Header with Date Selector                          │
├────────────────────────────────────────────────────┤
│ Insights Card                                      │
├────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌────────┐ ┌───────────┐  │
│ │ Temp Tab │ │Humidity │ │Weight  │ │ Combined  │  │
│ └─────────┘ └─────────┘ └────────┘ └───────────┘  │
├────────────────────────────────────────────────────┤
│                                                    │
│                                                    │
│                 Tab Content                        │
│                                                    │
│                                                    │
└────────────────────────────────────────────────────┘
```

### Tab Views

1. **Temperature Tab**:
   - Correlation information
   - Temperature chart with bee activity overlay

2. **Humidity Tab**:
   - Correlation information
   - Humidity chart with bee activity overlay

3. **Weight Tab**:
   - Correlation information
   - Weight chart with bee activity overlay

4. **Combined Tab**:
   - Combined visualization of all metrics

## Data Visualization

### Chart Implementation

The component uses the Flutter ECharts library for advanced visualizations. Each chart is created with a similar pattern:

1. Prepare data for chart (dates, values)
2. Create options configuration
3. Render chart with JSON-encoded options

```dart
Widget _buildTemperatureChart() {
  // Skip if no data
  if (_dates.isEmpty || _metricValues['temperature']!.isEmpty) {
    return const Center(child: Text('No temperature data available'));
  }
  
  // Prepare data for ECharts
  final List<String> dateLabels = _dates.map((date) => DateFormat('MM/dd').format(date)).toList();
  final List<double> temperatures = _metricValues['temperature']!;
  final List<double> beeCounts = _metricValues['beeCount']!;
  
  // Convert to JSON format for ECharts
  final tempSeries = temperatures.map((temp) => temp).toList();
  final beeCountSeries = beeCounts.map((count) => count).toList();
  
  // Create options object
  final options = {
    'tooltip': { /* ... */ },
    'legend': { /* ... */ },
    'xAxis': [ /* ... */ ],
    'yAxis': [ /* ... */ ],
    'series': [ /* ... */ ],
    'grid': { /* ... */ }
  };
  
  // Render chart
  return Container(
    height: 400,
    child: Echarts(
      option: '''${json.encode(options)}''',
      extraScript: '''
        chart.on('click', function(params) {
          if(window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('chartClick', params.name, params.value);
          }
        });
      ''',
    ),
  );
}
```

## Correlation Analysis

### Correlation Calculation

The correlation analysis is performed in the `BeeCountCorrelationRepository` class:

1. Bee count data is retrieved for the specified hive and date range
2. Environmental data is retrieved for the same period
3. Data points are matched by timestamp
4. Pearson correlation coefficients are calculated between bee activity and each environmental factor

### Insight Generation

Based on correlation values, the component generates actionable insights:

```dart
Map<String, String> generateDataInsights(Map<String, double> correlations) {
  final Map<String, String> insights = {};

  // Generate insights for each factor
  correlations.forEach((factor, correlation) {
    final absValue = correlation.abs();
    String insight = '';

    // Determine basic insight based on correlation strength
    if (absValue < 0.1) {
      insight = 'No significant relationship found...';
    } else if (absValue < 0.3) {
      // Weak correlation insights
    } else if (absValue < 0.5) {
      // Moderate correlation insights
    } else if (absValue < 0.7) {
      // Strong correlation insights
    } else {
      // Very strong correlation insights
    }

    // Add specific advice for each factor
    switch (factor) {
      case 'Temperature':
        // Temperature-specific advice
        break;
      case 'Humidity':
        // Humidity-specific advice
        break;
      // Other factors...
    }

    insights[factor] = insight;
  });

  return insights;
}
```

## Usage Examples

### Integration in Parameter Tab View

```dart
Tab(text: 'Bee Activity'),
// ...
Center(
  child: IntegratedHiveMonitoring(
    hiveId: widget.hiveId.toString(),
    token: widget.token,
  ),
),
```

### Integration in Hive Details

```dart
ElevatedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IntegratedHiveMonitoring(
          hiveId: widget.hiveId.toString(),
          token: widget.token,
        ),
      ),
    );
  },
  icon: const Icon(Icons.analytics),
  label: const Text('Bee Activity Monitoring'),
),
```

## Extension Points

The `IntegratedHiveMonitoring` component is designed to be extensible:

### 1. Additional Environmental Factors

To add new environmental factors:
- Add the factor to the `_metricValues` map
- Create a data fetching method
- Add correlation calculation in the repository
- Create a visualization method
- Add the factor to the insights generation

### 2. Enhanced Visualizations

The chart visualizations can be enhanced with:
- Additional chart types (scatter plots, heat maps)
- Interactive elements for drill-down analysis
- Animation effects for better data comprehension

### 3. Advanced Analytics

The correlation analysis can be extended with:
- Multiple regression analysis
- Time-series forecasting
- Anomaly detection
- Machine learning models for predictive analytics

### 4. Integration with External Systems

The component can be integrated with:
- Weather forecast APIs for predictive planning
- IoT sensor systems for real-time data
- Community data sharing for comparative analysis
