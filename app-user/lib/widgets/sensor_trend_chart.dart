import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/telemetry.dart';

/// Simple line chart widget for displaying sensor trends (temperature, pH)
/// Shows historical data points over time
class SensorTrendChart extends StatelessWidget {
  final String title;
  final String unit;
  final List<AquariumTelemetry> dataPoints;
  final Color lineColor;
  final double minValue;
  final double maxValue;
  final bool isLoading;

  const SensorTrendChart({
    super.key,
    required this.title,
    required this.unit,
    required this.dataPoints,
    required this.lineColor,
    this.minValue = 0,
    this.maxValue = 100,
    this.isLoading = false,
  });

  double? _getValue(AquariumTelemetry data) {
    if (title == 'Nhiệt độ') return data.temperature;
    if (title == 'pH') return data.ph;
    if (title == 'Mực nước') return data.waterLevelPercent.toDouble();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title ($unit)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                height: 150,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (dataPoints.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title ($unit)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                height: 150,
                child: Center(
                  child: Text('Chưa có dữ liệu lịch sử'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Filter out null values
    final validPoints = dataPoints
        .where((p) => _getValue(p) != null)
        .toList();

    if (validPoints.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title ($unit)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                height: 150,
                child: Center(
                  child: Text('Chưa có dữ liệu $title'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Calculate stats
    final values = validPoints.map((p) => _getValue(p)!).toList();
    final currentValue = values.last;
    final minValueData = values.reduce((a, b) => a < b ? a : b);
    final maxValueData = values.reduce((a, b) => a > b ? a : b);
    final avgValue = values.reduce((a, b) => a + b) / values.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title ($unit)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          // Current value display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hiện tại',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  Text(
                    '${currentValue.toStringAsFixed(1)} $unit',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: lineColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Cao nhất',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    Text(
                      '${maxValueData.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: lineColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thấp nhất',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    Text(
                      '${minValueData.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: lineColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Line chart visualization
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: _buildLineChart(validPoints),
          ),
          
          const SizedBox(height: 8),
          
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'Trung bình',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Text(
                    avgValue.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'Điểm dữ liệu',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Text(
                    '${validPoints.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'Biến thiên',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Text(
                    '${(maxValueData - minValueData).toStringAsFixed(1)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<AquariumTelemetry> points) {
    final values = points.map((p) => _getValue(p)!).toList();
    final maxData = values.reduce((a, b) => a > b ? a : b);
    final minData = values.reduce((a, b) => a < b ? a : b);
    final padding = ((maxData - minData).abs() * 0.1).clamp(0.5, 5.0);
    final minY = minData - padding;
    final maxY = maxData + padding;

    // Take last 20 datapoints for display
    final displayPoints = values.length > 20
        ? values.sublist(values.length - 20)
        : values;

    final spots = displayPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 4).clamp(0.5, 10.0),
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade300,
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 2.5,
            dotData: FlDotData(show: spots.length <= 12),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }
}
