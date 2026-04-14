import 'package:flutter/material.dart';
import '../widgets/water_level_widget.dart';
import '../widgets/control_buttons.dart';
import '../widgets/alerts_panel.dart';
import '../widgets/sensor_trend_chart.dart';
import '../models/alert.dart';
import '../models/telemetry.dart';
import '../services/alert_history_store.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  /// pondId dùng cho việc lấy cảnh báo AI theo ao nuôi.
  /// Telemetry hiện tại vẫn đang lấy cho 1 hệ thống duy nhất.
  final int pondId;
  final String pondName;
  final String? fishType;
  final String? area;

  const DashboardScreen({
    super.key,
    this.pondId = 1,
    this.pondName = 'Ao đang chọn',
    this.fishType,
    this.area,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AquariumTelemetry? _telemetry;
  List<AquariumTelemetry> _recentTelemetry = [];
  bool _isLoading = true;
  bool _recentTelemetryLoading = true;
  String? _error;
  Timer? _timer;
  bool _isControlBusy = false;

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
      final telemetry = await ApiService.fetchLatestTelemetry(pondId: widget.pondId);
      final recentTelemetry = await ApiService.fetchRecentTelemetry(pondId: widget.pondId);
      setState(() {
        _telemetry = telemetry;
        _recentTelemetry = recentTelemetry;
        _isLoading = false;
        _recentTelemetryLoading = false;
        _error = null;
      });
      await _recordTelemetryAlertHistory();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _recentTelemetryLoading = false;
      });
    }
  }

  // Hàm lấy thời gian hiện tại dạng "HH:mm:ss"
  String _getCurrentTime() {
    return DateFormat('HH:mm:ss').format(DateTime.now());
  }

  String _formatAge(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'Chưa có dữ liệu';
    final parsed = DateTime.tryParse(timestamp);
    if (parsed == null) return timestamp;
    final diff = DateTime.now().difference(parsed);
    if (diff.inSeconds < 60) return '${diff.inSeconds} giây trước';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    return '${diff.inHours} giờ trước';
  }

  Future<void> _recordTelemetryAlertHistory() async {
    if (_telemetry == null) return;

    final events = <Map<String, dynamic>>[];

    void addEvent(String title, String message, String level) {
      events.add({
        'pondId': widget.pondId,
        'pondName': widget.pondName,
        'source': 'TELEMETRY',
        'title': title,
        'message': message,
        'level': level,
        'createdAt': DateTime.now().toIso8601String(),
        'dedupeKey': '${widget.pondId}|TELEMETRY|$title|$message|$level',
      });
    }

    if (_telemetry!.temperature != null) {
      if (_telemetry!.temperature! < 18) {
        addEvent('Nhiệt độ', 'Nhiệt độ quá thấp: ${_telemetry!.temperature!.toStringAsFixed(1)}°C', 'WARNING');
      } else if (_telemetry!.temperature! > 30) {
        addEvent('Nhiệt độ', 'Nhiệt độ quá cao: ${_telemetry!.temperature!.toStringAsFixed(1)}°C', 'WARNING');
      }
    }

    if (_telemetry!.ph != null) {
      if (_telemetry!.ph! < 6.0) {
        addEvent('pH', 'pH quá thấp: ${_telemetry!.ph!.toStringAsFixed(1)}', 'WARNING');
      } else if (_telemetry!.ph! > 8.5) {
        addEvent('pH', 'pH quá cao: ${_telemetry!.ph!.toStringAsFixed(1)}', 'WARNING');
      }
    }

    if (_telemetry!.floatLow == false && _telemetry!.floatHigh == false) {
      addEvent('Mực nước', 'Mực nước CỰC THẤP - Cần châm nước ngay!', 'DANGER');
    } else if (_telemetry!.floatLow == false) {
      addEvent('Mực nước', 'Mực nước dưới mức tối thiểu', 'WARNING');
    } else if (_telemetry!.floatHigh == true && _telemetry!.floatLow == false) {
      addEvent('Mực nước', 'Trạng thái BẤT THƯỜNG - Kiểm tra phao!', 'DANGER');
    }

    if (events.isNotEmpty) {
      await AlertHistoryStore.recordEvents(events);
    }
  }

  Future<void> _setMode(String mode) async {
    setState(() {
      _isControlBusy = true;
    });
    try {
      await ApiService.setMode(mode, pondId: widget.pondId);
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể đổi mode: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isControlBusy = false;
        });
      }
    }
  }

  Future<void> _controlMotor(String command) async {
    setState(() {
      _isControlBusy = true;
    });
    try {
      await ApiService.controlMotor(command, pondId: widget.pondId);
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể điều khiển bơm: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isControlBusy = false;
        });
      }
    }
  }

  Widget _buildCurrentMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Generate alerts based on real telemetry data for direct display
    List<Alert> telemetryAlerts = [];

    if (_telemetry != null) {
      // Temperature alerts
      if (_telemetry!.temperature != null) {
        if (_telemetry!.temperature! < 18) {
          telemetryAlerts.add(
            Alert(
              message:
                  "⚠️ Nhiệt độ quá thấp: ${_telemetry!.temperature!.toStringAsFixed(1)}°C",
              time: _getCurrentTime(),
            ),
          );
        } else if (_telemetry!.temperature! > 30) {
          telemetryAlerts.add(
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
          telemetryAlerts.add(
            Alert(
              message:
                  "⚠️ pH quá thấp (acidic): ${_telemetry!.ph!.toStringAsFixed(1)}",
              time: _getCurrentTime(),
            ),
          );
        } else if (_telemetry!.ph! > 8.5) {
          telemetryAlerts.add(
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
        telemetryAlerts.add(
          Alert(
            message: "🚨 Mực nước CỰC THẤP - Cần châm nước ngay!",
            time: _getCurrentTime(),
          ),
        );
      } else if (_telemetry!.floatLow == false) {
        telemetryAlerts.add(
          Alert(
            message: "⚠️ Mực nước dưới mức tối thiểu",
            time: _getCurrentTime(),
          ),
        );
      } else if (_telemetry!.floatHigh == true &&
          _telemetry!.floatLow == true) {
        telemetryAlerts.add(
          Alert(
            message: "💧 Bể đầy - Có thể tự động xả nước",
            time: _getCurrentTime(),
          ),
        );
      } else if (_telemetry!.floatHigh == true &&
          _telemetry!.floatLow == false) {
        telemetryAlerts.add(
          Alert(
            message: "⚠️ Trạng thái BẤT THƯỜNG - Kiểm tra phao!",
            time: _getCurrentTime(),
          ),
        );
      }

      // Motor running alert
      if (_telemetry!.motorRunning == true) {
        telemetryAlerts.add(
          Alert(message: "🔄 Motor đang hoạt động", time: _getCurrentTime()),
        );
      }

      // Mode alert
      if (_telemetry!.mode == 'MANUAL') {
        telemetryAlerts.add(
          Alert(
            message: "✋ Đang ở chế độ MANUAL - Điều khiển thủ công",
            time: _getCurrentTime(),
          ),
        );
      }
    }

    // Add default message if no alerts
    if (telemetryAlerts.isEmpty) {
      telemetryAlerts.add(
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

    final mode = _telemetry?.mode ?? 'UNKNOWN';
    final latestUpdatedText = _formatAge(_telemetry?.timestamp);

    return Column(
      children: [
        // Header with pond info (top section)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.cyan.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.pool_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.pondName}  •  Ao #${widget.pondId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.fishType != null && widget.fishType!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.fishType!,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Dashboard content (merged from previous sub-tabs)
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                        Row(
                          children: [
                            const Icon(Icons.insights_rounded, size: 18, color: Colors.blue),
                            const SizedBox(width: 6),
                            const Text(
                              'Chỉ số hiện tại',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              'Cập nhật: $latestUpdatedText',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildCurrentMetricCard(
                              label: 'Nhiệt độ',
                              value: _telemetry?.temperature != null
                                  ? '${_telemetry!.temperature!.toStringAsFixed(1)}°C'
                                  : '--',
                              icon: Icons.thermostat_rounded,
                              color: Colors.deepOrange,
                            ),
                            const SizedBox(width: 10),
                            _buildCurrentMetricCard(
                              label: 'pH',
                              value: _telemetry?.ph != null
                                  ? _telemetry!.ph!.toStringAsFixed(2)
                                  : '--',
                              icon: Icons.science_rounded,
                              color: Colors.teal,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildCurrentMetricCard(
                              label: 'Mực nước',
                              value: '${_telemetry?.waterLevelPercent ?? 0}%',
                              icon: Icons.water_drop_rounded,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 10),
                            _buildCurrentMetricCard(
                              label: 'Tín hiệu',
                              value: latestUpdatedText,
                              icon: Icons.wifi_tethering_rounded,
                              color: (_telemetry != null) ? Colors.green : Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  WaterLevelWidget(
                    level: (_telemetry?.waterLevelPercent ?? 0).toDouble(),
                  ),
                  const SizedBox(height: 12),
                  AlertsPanel(alerts: telemetryAlerts.take(4).toList()),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ControlButtons(
                      currentMode: mode,
                      isMotorRunning: _telemetry?.motorRunning == true,
                      isBusy: _isControlBusy,
                      onSetMode: _setMode,
                      onControlMotor: _controlMotor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                        Row(
                          children: [
                            const Icon(Icons.query_stats_rounded, size: 18, color: Colors.indigo),
                            const SizedBox(width: 6),
                            const Text(
                              'Biểu đồ theo thời gian',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              _recentTelemetry.isNotEmpty
                                  ? '${_recentTelemetry.length} mẫu'
                                  : '0 mẫu',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SensorTrendChart(
                          title: 'Nhiệt độ',
                          unit: '°C',
                          dataPoints: _recentTelemetry,
                          lineColor: Colors.deepOrange,
                          minValue: 0,
                          maxValue: 40,
                          isLoading: _recentTelemetryLoading,
                        ),
                        const SizedBox(height: 12),
                        SensorTrendChart(
                          title: 'pH',
                          unit: '',
                          dataPoints: _recentTelemetry,
                          lineColor: Colors.teal,
                          minValue: 0,
                          maxValue: 14,
                          isLoading: _recentTelemetryLoading,
                        ),
                        const SizedBox(height: 12),
                        SensorTrendChart(
                          title: 'Mực nước',
                          unit: '%',
                          dataPoints: _recentTelemetry
                              .map((item) => AquariumTelemetry(
                                    pondId: item.pondId,
                                    temperature: item.waterLevelPercent.toDouble(),
                                    ph: item.ph,
                                    floatHigh: item.floatHigh,
                                    floatLow: item.floatLow,
                                    motorRunning: item.motorRunning,
                                    duty: item.duty,
                                    mode: item.mode,
                                    timestamp: item.timestamp,
                                  ))
                              .toList(),
                          lineColor: Colors.blue,
                          minValue: 0,
                          maxValue: 100,
                          isLoading: _recentTelemetryLoading,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
