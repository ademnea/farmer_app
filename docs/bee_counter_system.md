# Bee Counter System Documentation

## Overview

The Bee Counter System is a core component of the Farmer App that provides comprehensive tracking and analysis of bee activity in hives. It utilizes computer vision techniques and data correlation to offer insights into bee behavior and hive health.

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Key Components](#key-components)
3. [Data Flow](#data-flow)
4. [Technical Implementation](#technical-implementation)
5. [Data Models](#data-models)
6. [Video Processing](#video-processing)
7. [Correlation Analysis](#correlation-analysis)
8. [Background Services](#background-services)
9. [Integration Points](#integration-points)
10. [Future Enhancements](#future-enhancements)

## System Architecture

The Bee Counter System follows a layered architecture:

```
┌─────────────────────────┐
│                         │
│ UI Layer                │
│ - Monitoring Screens    │
│ - Data Visualizations   │
│ - User Interactions     │
│                         │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│                         │
│ Business Logic Layer    │
│ - Correlation Analysis  │
│ - Insight Generation    │
│ - Data Processing       │
│                         │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│                         │
│ Data Layer              │
│ - Video Processing      │
│ - Bee Count Storage     │
│ - Environmental Data    │
│                         │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│                         │
│ Background Services     │
│ - Continuous Monitoring │
│ - Scheduled Processing  │
│                         │
└─────────────────────────┘
```

## Key Components

### 1. Bee Counting Module

The core component responsible for detecting and counting bees entering and exiting the hive:

- **Video Processing**: Analyzes video feeds to detect bee movement
- **Movement Classification**: Identifies the direction of movement (entry/exit)
- **Count Aggregation**: Consolidates counts over specified time periods

### 2. Correlation Repository

Analyzes relationships between bee activity and environmental factors:

- **Data Retrieval**: Gathers bee count and environmental data
- **Statistical Analysis**: Performs correlation calculations
- **Insight Generation**: Produces actionable recommendations

### 3. Integrated Monitoring UI

Presents bee activity data with environmental correlations:

- **Multi-parameter Charts**: Visualizes all metrics in unified views
- **Interactive Elements**: Supports date range selection and metric filtering
- **Insight Presentation**: Displays generated insights in user-friendly format

### 4. Background Monitoring Service

Enables continuous data collection even when the app is not in active use:

- **Scheduled Processing**: Processes videos at defined intervals
- **Battery Optimization**: Implements power-saving strategies
- **Notification System**: Alerts users about significant findings

## Data Flow

1. Video capture devices record bee activity at hive entrance
2. Videos are stored locally or uploaded to cloud storage
3. Video Processor analyzes footage to count bee entries and exits
4. Counts are stored in local database with timestamps
5. Correlation Repository retrieves environmental data for the same timeframes
6. Statistical analysis identifies correlations between bee activity and environmental factors
7. Insights are generated based on correlation strengths
8. UI components visualize the data and insights for user interaction

## Technical Implementation

### Bee Counter Model

The `BeeCount` model stores count data with the following properties:

```dart
class BeeCount {
  final String? id;
  final String hiveId;
  final String? videoId;
  final int beesEntering;
  final int beesExiting;
  final DateTime timestamp;
  final String? notes;
  final double confidence;
  
  // Constructor and methods...
}
```

### Video Processing

Video processing occurs in multiple stages:

1. **Preprocessing**: Converting video to appropriate format and resolution
2. **Frame Extraction**: Extracting key frames for analysis
3. **Object Detection**: Identifying bees in each frame
4. **Movement Tracking**: Tracking bee movement between frames
5. **Direction Classification**: Determining if movement is entry or exit
6. **Count Aggregation**: Combining counts across video duration

### Correlation Analysis

The correlation analysis uses Pearson correlation coefficients to identify relationships between:

- Temperature and bee activity
- Humidity and bee activity
- Hive weight and bee activity
- Time of day and bee activity
- Weather conditions and bee activity

### Database Structure

The system uses SQLite tables to store:

- Bee count data with timestamps
- Environmental readings with timestamps
- Video metadata
- Generated insights

## Integration Points

The Bee Counter System integrates with:

1. **Environmental Monitoring**: Temperature, humidity, and weight sensors
2. **Weather Service**: External API for weather data
3. **Notification Service**: For alerting users about significant changes
4. **Main App UI**: For displaying insights and visualizations

## Future Enhancements

1. **Machine Learning Improvements**:
   - Enhanced bee detection in diverse lighting conditions
   - Identification of different bee behaviors (not just entry/exit)
   - Anomaly detection for unusual activity patterns

2. **Advanced Analytics**:
   - Predictive analytics for future bee activity
   - Multi-hive correlation analysis
   - Seasonal pattern recognition

3. **Integration Enhancements**:
   - Direct integration with hive monitoring hardware
   - Real-time video processing
   - Cloud-based analysis for improved performance
