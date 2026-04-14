import 'package:flutter/material.dart';
import '../models/telemetry.dart';
import '../services/api_service.dart';
import '../widgets/water_level_widget.dart';
import '../widgets/pond_alert_history_panel.dart';
import '../widgets/control_buttons.dart';
import '../widgets/sensor_trend_chart.dart';
import '../widgets/device_status_indicator.dart';
import '../models/alert.dart';

/// Tabbed dashboard view with 4 tabs: Monitor, Alerts, Control, Status
class DashboardTabbedView extends StatefulWidget {
  final AquariumTelemetry? telemetry;
  final List<Alert> telemetryAlerts;
  final List<Map<String, dynamic>> aiAlerts;
  final bool isLoading;
  final String mode;
  final int pondId;
  final String pondName;
  final bool aiAlertsLoading;
  final bool aiAlertsFallback;
  final VoidCallback onSetMode;
  final VoidCallback onControlMotor;
  final VoidCallback onRefreshAiAlerts;

  const DashboardTabbedView({
    super.key,
    required this.telemetry,
    required this.telemetryAlerts,
    required this.aiAlerts,
    required this.isLoading,
    required this.mode,
    required this.pondId,
    required this.pondName,
    required this.aiAlertsLoading,
    required this.aiAlertsFallback,
    required this.onSetMode,
    required this.onControlMotor,
    required this.onRefreshAiAlerts,
  });

  @override
  State<DashboardTabbedView> createState() => _DashboardTabbedViewState();
}

class _DashboardTabbedViewState extends State<DashboardTabbedView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AquariumTelemetry> _recentTelemetry = [];
  bool _recentTelemetryLoading = false;
  String? _recentTelemetryError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Fetch recent telemetry on tab switch to Monitor tab
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // Only fetch when Monitor tab (index 0) is selected
    if (_tabController.index == 0 && _recentTelemetry.isEmpty) {
      _fetchRecentTelemetry();
    }
  }

  Future<void> _fetchRecentTelemetry() async {
    setState(() {
      _recentTelemetryLoading = true;
      _recentTelemetryError = null;
    });
    try {
      final data = await ApiService.fetchRecentTelemetry(pondId: widget.pondId);
      setState(() {
        _recentTelemetry = data;
        _recentTelemetryLoading = false;
      });
    } catch (e) {
      setState(() {
        _recentTelemetryError = e.toString();
        _recentTelemetryLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.analytics_outlined),
                text: 'Theo dõi',
              ),
              Tab(
                icon: Icon(Icons.warning_amber_rounded),
                text: 'Cảnh báo',
              ),
              Tab(
                icon: Icon(Icons.gamepad_rounded),
                text: 'Điều khiển',
              ),
              Tab(
                icon: Icon(Icons.info_rounded),
                text: 'Trạng thái',
              ),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // ========== MONITOR TAB ==========
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Water Level Widget
                    if (widget.telemetry != null)
                      WaterLevelWidget(
                        level: widget.telemetry!.waterLevelPercent.toDouble(),
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('Chưa có dữ liệu'),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Float switches
                    if (widget.telemetry != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: widget.telemetry?.floatHigh == true
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
                                    widget.telemetry!.floatHigh == true
                                        ? '🌊 FULL'
                                        : '○ Open',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: widget.telemetry!.floatHigh == true
                                          ? Colors.blue
                                          : Colors.grey,
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
                                color: widget.telemetry?.floatLow == true
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
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
                                    widget.telemetry!.floatLow == true
                                        ? '✓ OK'
                                        : '⚠ LOW',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: widget.telemetry!.floatLow == true
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Temperature Trend Chart
                    SensorTrendChart(
                      title: 'Nhiệt độ',
                      unit: '°C',
                      dataPoints: _recentTelemetry,
                      lineColor: Colors.orange,
                      isLoading: _recentTelemetryLoading,
                    ),

                    const SizedBox(height: 16),

                    // pH Trend Chart
                    SensorTrendChart(
                      title: 'pH',
                      unit: '',
                      dataPoints: _recentTelemetry,
                      lineColor: Colors.green,
                      minValue: 0,
                      maxValue: 14,
                      isLoading: _recentTelemetryLoading,
                    ),

                    if (_recentTelemetryError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lỗi tải lịch sử: $_recentTelemetryError',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ========== ALERTS TAB ==========
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show telemetry alerts
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cảnh báo từ cảm biến',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (widget.telemetryAlerts.isEmpty)
                            const Text('✅ Tất cả chỉ số bình thường')
                          else
                            Column(
                              children: widget.telemetryAlerts.map((alert) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.08),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    alert.message,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Show AI alerts
                    if (!widget.aiAlertsFallback)
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Cảnh báo từ AI',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Tải lại',
                                  onPressed: widget.aiAlertsLoading
                                      ? null
                                      : widget.onRefreshAiAlerts,
                                  icon: widget.aiAlertsLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.refresh_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (widget.aiAlerts.isEmpty)
                              const Text('✅ Không có cảnh báo từ AI')
                            else
                              Column(
                                children: widget.aiAlerts.map((alert) {
                                  final metric = alert['metric']?.toString() ?? '';
                                  final level = alert['level']?.toString() ?? 'OK';
                                  final message = alert['message']?.toString() ?? '';
                                  final color = level == 'DANGER'
                                      ? Colors.red
                                      : level == 'WARNING'
                                          ? Colors.orange
                                          : Colors.green;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.08),
                                      border: Border.all(
                                        color: color.withOpacity(0.35),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$metric - $level',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(message),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ========== CONTROL TAB ==========
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode indicator
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chế độ hiện tại',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: widget.mode == 'AUTO'
                                  ? Colors.blue.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: widget.mode == 'AUTO'
                                    ? Colors.blue
                                    : Colors.orange,
                              ),
                            ),
                            child: Text(
                              widget.mode,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: widget.mode == 'AUTO'
                                    ? Colors.blue.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Control buttons - simplified version without the wrapper
                    if (widget.telemetry != null)
                      _buildControlPanel(),
                  ],
                ),
              ),

              // ========== STATUS TAB ==========
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: DeviceStatusIndicator(
                  telemetry: widget.telemetry,
                  isLoading: widget.isLoading,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build control panel UI
  Widget _buildControlPanel() {
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
          const Text(
            'Điều khiển bơm',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          const Text(
            'Chế độ AUTO: Bơm tự động dựa trên mực nước\nChế độ MANUAL: Điều khiển thủ công bơm',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          
          ControlButtons(
            currentMode: widget.mode,
            isMotorRunning: widget.telemetry?.motorRunning ?? false,
            isBusy: false,
            onSetMode: (mode) async => widget.onSetMode(),
            onControlMotor: (cmd) async => widget.onControlMotor(),
          ),
        ],
      ),
    );
  }
}
