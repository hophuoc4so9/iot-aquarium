import 'package:flutter/material.dart';
import '../widgets/water_level_widget.dart';
import '../widgets/control_buttons.dart';
import '../widgets/alerts_panel.dart';
import '../models/alert.dart';
import '../models/telemetry.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'alerts_screen.dart';

class DashboardScreen extends StatefulWidget {
  /// pondId dùng cho việc lấy cảnh báo AI theo ao nuôi.
  /// Telemetry hiện tại vẫn đang lấy cho 1 hệ thống duy nhất.
  final int pondId;

  const DashboardScreen({super.key, this.pondId = 1});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AquariumTelemetry? _telemetry;
  bool _isLoading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Auto refresh every 2 seconds
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final telemetry = await ApiService.fetchLatestTelemetry();
      setState(() {
        _telemetry = telemetry;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Hàm lấy thời gian hiện tại dạng "HH:mm:ss"
  String _getCurrentTime() {
    return DateFormat('HH:mm:ss').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    // Generate alerts based on real telemetry data
    List<Alert> alerts = [];

    if (_telemetry != null) {
      // Temperature alerts
      if (_telemetry!.temperature != null) {
        if (_telemetry!.temperature! < 18) {
          alerts.add(
            Alert(
              message:
                  "⚠️ Nhiệt độ quá thấp: ${_telemetry!.temperature!.toStringAsFixed(1)}°C",
              time: _getCurrentTime(),
            ),
          );
        } else if (_telemetry!.temperature! > 30) {
          alerts.add(
            Alert(
              message:
                  "🔥 Nhiệt độ quá cao: ${_telemetry!.temperature!.toStringAsFixed(1)}°C",
              time: _getCurrentTime(),
            ),
          );
        }
      }

      // pH alerts
      if (_telemetry!.ph != null) {
        if (_telemetry!.ph! < 6.0) {
          alerts.add(
            Alert(
              message:
                  "⚠️ pH quá thấp (acidic): ${_telemetry!.ph!.toStringAsFixed(1)}",
              time: _getCurrentTime(),
            ),
          );
        } else if (_telemetry!.ph! > 8.5) {
          alerts.add(
            Alert(
              message:
                  "⚠️ pH quá cao (alkaline): ${_telemetry!.ph!.toStringAsFixed(1)}",
              time: _getCurrentTime(),
            ),
          );
        }
      }

      // Water level alerts
      if (_telemetry!.floatLow == false && _telemetry!.floatHigh == false) {
        alerts.add(
          Alert(
            message: "🚨 Mực nước CỰC THẤP - Cần châm nước ngay!",
            time: _getCurrentTime(),
          ),
        );
      } else if (_telemetry!.floatLow == false) {
        alerts.add(
          Alert(
            message: "⚠️ Mực nước dưới mức tối thiểu",
            time: _getCurrentTime(),
          ),
        );
      } else if (_telemetry!.floatHigh == true &&
          _telemetry!.floatLow == true) {
        alerts.add(
          Alert(
            message: "💧 Bể đầy - Có thể tự động xả nước",
            time: _getCurrentTime(),
          ),
        );
      } else if (_telemetry!.floatHigh == true &&
          _telemetry!.floatLow == false) {
        alerts.add(
          Alert(
            message: "⚠️ Trạng thái BẤT THƯỜNG - Kiểm tra phao!",
            time: _getCurrentTime(),
          ),
        );
      }

      // Motor running alert
      if (_telemetry!.motorRunning == true) {
        alerts.add(
          Alert(message: "🔄 Motor đang hoạt động", time: _getCurrentTime()),
        );
      }

      // Mode alert
      if (_telemetry!.mode == 'MANUAL') {
        alerts.add(
          Alert(
            message: "✋ Đang ở chế độ MANUAL - Điều khiển thủ công",
            time: _getCurrentTime(),
          ),
        );
      }
    }

    // Add default message if no alerts
    if (alerts.isEmpty) {
      alerts.add(
        Alert(
          message: "✅ Hệ thống hoạt động bình thường",
          time: _getCurrentTime(),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Lỗi kết nối: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchData, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    final waterLevel = _telemetry?.waterLevelPercent.toDouble() ?? 0;
    final floatHigh = _telemetry?.floatHigh ?? false;
    final floatLow = _telemetry?.floatLow ?? false;
    final temp = _telemetry?.temperature ?? 0;
    final ph = _telemetry?.ph ?? 7.0;
    final mode = _telemetry?.mode ?? 'UNKNOWN';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Smart Aquarium — Dashboard",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mode: $mode',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: mode == 'AUTO' ? Colors.blue : Colors.orange,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.notifications_active_rounded),
                color: Colors.redAccent,
                tooltip: 'Xem cảnh báo AI cho ao đang chọn',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AlertsScreen(pondId: widget.pondId),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ✅ Mực nước với dữ liệu thực từ API
          WaterLevelWidget(level: waterLevel),

          const SizedBox(height: 16),

          // Float switches status
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: floatHigh
                        ? Colors.blue.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Float HIGH',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        floatHigh ? '🌊 FULL' : '○ Open',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: floatHigh ? Colors.blue : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: floatLow ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Float LOW',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        floatLow ? '✓ OK' : '⚠ LOW',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: floatLow ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Temperature card
          Container(
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
            child: Row(
              children: [
                const Icon(Icons.thermostat, size: 40, color: Colors.orange),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhiệt độ',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      '${temp.toStringAsFixed(1)}°C',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // pH card
          Container(
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
            child: Row(
              children: [
                Icon(
                  Icons.water_drop,
                  size: 40,
                  color: ph < 6.0
                      ? Colors.yellow.shade700
                      : ph > 8.5
                      ? Colors.purple
                      : Colors.green,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'pH Level',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      ph.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ph < 6.5
                          ? 'Acidic'
                          : ph > 8.0
                          ? 'Alkaline'
                          : 'Ideal',
                      style: TextStyle(
                        fontSize: 12,
                        color: ph < 6.5
                            ? Colors.yellow.shade700
                            : ph > 8.0
                            ? Colors.purple
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ✅ Cảnh báo gần đây full chiều ngang
          AlertsPanel(alerts: alerts),

          const SizedBox(height: 24),

          // ✅ Các nút điều khiển ở cuối
          const ControlButtons(),
        ],
      ),
    );
  }
}
