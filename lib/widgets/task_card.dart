// lib/widgets/task_card.dart
import 'package:flutter/material.dart';

class TaskCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final String location;
  final String tag1Text;
  final Color tag1Color;
  final String tag2Text;
  final Color tag2Color;
  final IconData icon;
  final Color borderColor;
  final bool isTask;

  const TaskCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.location,
    required this.tag1Text,
    required this.tag1Color,
    required this.tag2Text,
    required this.tag2Color,
    required this.icon,
    required this.borderColor,
    this.isTask = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: borderColor, width: 5),
          ),
        ),
        child: Row(
          children: [
            if (isTask)
              Checkbox(value: false, onChanged: (val) {}, visualDensity: VisualDensity.compact)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(icon, color: Colors.grey[700]),
              ),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(time, style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(width: 12),
                      Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(location, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),

            Column(
              children: [
                _buildTag(tag1Text, tag1Color),
                const SizedBox(height: 4),
                _buildTag(tag2Text, tag2Color),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}