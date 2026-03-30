import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaterLevelWidget extends StatefulWidget {
  final double level; // 0–100

  const WaterLevelWidget({super.key, required this.level});

  @override
  State<WaterLevelWidget> createState() => _WaterLevelWidgetState();
}

class _WaterLevelWidgetState extends State<WaterLevelWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color getWaterColor(double level) {
    if (level < 30) return Colors.blueAccent.shade100;
    if (level < 70) return Colors.blueAccent;
    return Colors.blue.shade800;
  }

  String getStatusText(double level) {
    if (level < 30) return "Thấp";
    if (level < 70) return "Vừa";
    return "Cao";
  }

  @override
  Widget build(BuildContext context) {
    final color = getWaterColor(widget.level);
    final status = getStatusText(widget.level);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 2),
              blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Mực nước",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              height: 180,
              width: double.infinity,              
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _WavePainter(
                        animation: _controller.value,
                        level: widget.level,
                        color: color),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
              child: Text(
                  "${widget.level.toStringAsFixed(0)}%  •  $status",
                  style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animation;
  final double level;
  final Color color;

  _WavePainter({required this.animation, required this.level, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.7);
    final path = Path();

    double waveHeight = 6;
    double baseHeight = size.height * (1 - level / 100);

    path.moveTo(0, baseHeight);
    for (double x = 0; x <= size.width; x++) {
      double y = baseHeight +
          math.sin((x / size.width * 2 * math.pi) + animation * 2 * math.pi) *
              waveHeight;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => true;
}
