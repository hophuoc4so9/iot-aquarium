import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../models/telemetry.dart';

class SensorChart extends StatefulWidget {
  const SensorChart({super.key});

  @override
  State<SensorChart> createState() => _SensorChartState();
}

class _SensorChartState extends State<SensorChart> {
  bool _loading = true;
  String? _error;
  List<AquariumTelemetry> _history = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchRecentTelemetry();
      setState(() {
        _history = data.reversed.toList(); // hiển thị theo thời gian tăng dần
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<FlSpot> _buildSpots(double? Function(AquariumTelemetry t) pick) {
    final spots = <FlSpot>[];
    for (var i = 0; i < _history.length; i++) {
      final v = pick(_history[i]);
      if (v != null) {
        spots.add(FlSpot(i.toDouble(), v));
      }
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final tempSpots = _buildSpots((t) => t.temperature);
    final phSpots = _buildSpots((t) => t.ph);
    final levelSpots =
        _buildSpots((t) => t.waterLevelPercent.toDouble());

    return Container(
      padding: const EdgeInsets.all(12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Biểu đồ cảm biến (gần đây)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loading ? null : _loadHistory,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Lỗi tải dữ liệu: $_error",
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Chưa có dữ liệu lịch sử."),
            )
          else
            SizedBox(
              height: 260,
              child: LineChart(
                LineChartData(
                  titlesData: FlTitlesData(show: false),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    if (levelSpots.isNotEmpty)
                      LineChartBarData(
                        spots: levelSpots,
                        isCurved: true,
                        color: Colors.blue,
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blue.withOpacity(0.15),
                        ),
                        dotData: FlDotData(show: false),
                      ),
                    if (tempSpots.isNotEmpty)
                      LineChartBarData(
                        spots: tempSpots,
                        isCurved: true,
                        color: Colors.orange,
                        belowBarData: BarAreaData(show: false),
                        dotData: FlDotData(show: false),
                      ),
                    if (phSpots.isNotEmpty)
                      LineChartBarData(
                        spots: phSpots,
                        isCurved: true,
                        color: Colors.green,
                        belowBarData: BarAreaData(show: false),
                        dotData: FlDotData(show: false),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 12,
            children: [
              _LegendDot(color: Colors.blue, label: "Mực nước (%)"),
              _LegendDot(color: Colors.orange, label: "Nhiệt độ (°C)"),
              _LegendDot(color: Colors.green, label: "pH"),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
