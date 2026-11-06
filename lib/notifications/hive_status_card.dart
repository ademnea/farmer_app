import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:farmer_app/hive_model.dart';
import 'package:farmer_app/notifications/weather_data_service.dart';

class HiveStatusCard extends StatelessWidget {
  final Hive hive;
  final WeatherData? weatherData;

  const HiveStatusCard({
    Key? key,
    required this.hive,
    this.weatherData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');
    final lastUpdated = hive.lastUpdated != null
        ? dateFormat.format(DateTime.parse(hive.lastUpdated!))
        : 'Unknown';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last Updated: $lastUpdated',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 16),
                _buildStatusGrid(context),
                const SizedBox(height: 16),
                if (weatherData != null) _buildWeatherSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[700],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.hive, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hive ${hive.id}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: hive.isConnected ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hive.isConnected ? 'Connected' : 'Disconnected',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: hive.isColonized ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hive.isColonized ? 'Colonized' : 'Not Colonized',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatusItem(
          context,
          'Interior Temperature',
          '${hive.temperature?.toStringAsFixed(1) ?? 'N/A'}°C',
          Icons.thermostat,
          _getTemperatureColor(hive.temperature),
          _getStatusText(
            hive.temperature,
            {'min': 20.0, 'max': 35.0, 'critical_min': 15.0, 'critical_max': 40.0},
          ),
        ),
        _buildStatusItem(
          context,
          'Interior Humidity',
          '${hive.humidity?.toStringAsFixed(1) ?? 'N/A'}%',
          Icons.water_drop,
          _getHumidityColor(hive.humidity),
          _getStatusText(
            hive.humidity,
            {'min': 40.0, 'max': 80.0, 'critical_min': 30.0, 'critical_max': 90.0},
          ),
        ),
        _buildStatusItem(
          context,
          'Hive Weight',
          '${hive.weight?.toStringAsFixed(2) ?? 'N/A'} kg',
          Icons.scale,
          _getWeightColor(hive.weight),
          _getStatusText(
            hive.weight,
            {'min': 10.0, 'max': 30.0, 'critical_min': 5.0, 'critical_max': 35.0},
          ),
        ),
        _buildStatusItem(
          context,
          'Carbon Dioxide',
          '${hive.carbonDioxide ?? 'N/A'} ppm',
          Icons.co2,
          _getCO2Color(hive.carbonDioxide),
          _getStatusText(
            hive.carbonDioxide?.toDouble(),
            {'min': 400.0, 'max': 5000.0, 'critical_min': 300.0, 'critical_max': 8000.0},
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    String status,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weather Conditions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Row(
            children: [
              Icon(
                _getWeatherIcon(weatherData!.condition),
                color: Colors.blue[700],
                size: 40,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weatherData!.condition,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Temperature: ${weatherData!.temperature.toStringAsFixed(1)}°C',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Humidity: ${weatherData!.humidity.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Wind Speed: ${weatherData!.windSpeed.toStringAsFixed(1)} km/h',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getWeatherIcon(String condition) {
    final lowerCondition = condition.toLowerCase();
    if (lowerCondition.contains('rain')) {
      return Icons.water_drop;
    } else if (lowerCondition.contains('cloud')) {
      return Icons.cloud;
    } else if (lowerCondition.contains('sun') || lowerCondition.contains('clear')) {
      return Icons.wb_sunny;
    } else if (lowerCondition.contains('snow')) {
      return Icons.ac_unit;
    } else if (lowerCondition.contains('thunder') || lowerCondition.contains('storm')) {
      return Icons.flash_on;
    } else if (lowerCondition.contains('fog') || lowerCondition.contains('mist')) {
      return Icons.cloud;
    } else {
      return Icons.wb_sunny_outlined;
    }
  }

  Color _getTemperatureColor(double? temperature) {
    if (temperature == null) return Colors.grey;
    
    if (temperature < 15.0 || temperature > 40.0) {
      return Colors.red;
    } else if (temperature < 20.0 || temperature > 35.0) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  Color _getHumidityColor(double? humidity) {
    if (humidity == null) return Colors.grey;
    
    if (humidity < 30.0 || humidity > 90.0) {
      return Colors.red;
    } else if (humidity < 40.0 || humidity > 80.0) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }

  Color _getWeightColor(double? weight) {
    if (weight == null) return Colors.grey;
    
    if (weight < 5.0 || weight > 35.0) {
      return Colors.red;
    } else if (weight < 10.0 || weight > 30.0) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  Color _getCO2Color(int? co2) {
    if (co2 == null) return Colors.grey;
    
    if (co2 < 300 || co2 > 8000) {
      return Colors.red;
    } else if (co2 < 400 || co2 > 5000) {
      return Colors.orange;
    } else {
      return Colors.purple;
    }
  }

  String _getStatusText(double? value, Map<String, double> thresholds) {
    if (value == null) return 'No Data';
    
    if (value < thresholds['critical_min']! || value > thresholds['critical_max']!) {
      return 'Critical';
    } else if (value < thresholds['min']! || value > thresholds['max']!) {
      return 'Warning';
    } else {
      return 'Normal';
    }
  }
}
