import 'package:flutter/material.dart';
import '../widgets/sensor_chart.dart';

class ChartScreen extends StatelessWidget {
  final int? pondId;

  const ChartScreen({super.key, this.pondId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SensorChart(pondId: pondId),
      ),
    );
  }
}
