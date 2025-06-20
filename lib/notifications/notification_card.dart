import 'package:flutter/material.dart';
import 'package:farmer_app/notifications/notification_model.dart';

class NotificationCard extends StatelessWidget {
  final HiveNotification notification;
  final VoidCallback? onTap;

  const NotificationCard({
    Key? key,
    required this.notification,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: notification.isRead ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: notification.isRead
              ? Colors.transparent
              : notification.color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSeverityIndicator(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              notification.timeAgo,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityIndicator() {
    IconData iconData;
    String severityText;

    switch (notification.severity) {
      case NotificationSeverity.high:
        severityText = 'High';
        break;
      case NotificationSeverity.medium:
        severityText = 'Medium';
        break;
      case NotificationSeverity.low:
        severityText = 'Low';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: notification.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            notification.icon,
            color: notification.color,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            severityText,
            style: TextStyle(
              color: notification.color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    // Different action buttons based on notification type
    switch (notification.type) {
      case NotificationType.temperature:
      case NotificationType.humidity:
      case NotificationType.weight:
      case NotificationType.carbonDioxide:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildActionButton('View Details', Icons.visibility),
            const SizedBox(width: 8),
            _buildActionButton('Adjust Thresholds', Icons.settings),
          ],
        );
      case NotificationType.weather:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildActionButton('View Forecast', Icons.cloud),
          ],
        );
      case NotificationType.connection:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildActionButton('Troubleshoot', Icons.build),
            const SizedBox(width: 8),
            _buildActionButton('Check Device', Icons.devices),
          ],
        );
      case NotificationType.colonization:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildActionButton('Inspect Hive', Icons.search),
          ],
        );
    }
  }

  Widget _buildActionButton(String label, IconData icon) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey[700],
        side: BorderSide(color: Colors.grey[300]!),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
