import 'package:flutter/material.dart';
import '../models/alert.dart';

class AlertsPanel extends StatelessWidget {
  final List<Alert> alerts;
  const AlertsPanel({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // full ngang
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Cảnh báo gần đây",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...alerts.map((alert) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(alert.message,
                          style: const TextStyle(fontSize: 16)),
                    ),
                    Text(alert.time,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
