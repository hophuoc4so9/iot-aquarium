import 'package:flutter/material.dart';
import '../widgets/sensor_chart.dart';

class ChartScreen extends StatelessWidget {
  const ChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SensorChart(),
      ),
    );
  }
}
