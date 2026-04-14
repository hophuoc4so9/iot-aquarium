import 'package:flutter/material.dart';
import '../models/telemetry.dart';

/// Status indicator widget for displaying device online/offline status
/// and other device health metrics
class DeviceStatusIndicator extends StatelessWidget {
  final AquariumTelemetry? telemetry;
  final bool isLoading;

  const DeviceStatusIndicator({
    super.key,
    required this.telemetry,
    this.isLoading = false,
  });

  /// Online when latest telemetry arrives within 10 seconds.
  bool get isOnline {
    if (telemetry?.timestamp == null) return false;
    try {
      final lastUpdate = DateTime.parse(telemetry!.timestamp!);
      final diff = DateTime.now().difference(lastUpdate);
      return diff.inSeconds < 10;
    } catch (_) {
      return false;
    }
  }

  String get lastUpdateText {
    if (telemetry?.timestamp == null) return 'Chưa cập nhật';
    try {
      final lastUpdate = DateTime.parse(telemetry!.timestamp!);
      final diff = DateTime.now().difference(lastUpdate);

      if (diff.inSeconds < 60) {
        return '${diff.inSeconds} giây trước';
      }
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes} phút trước';
      }
      return '${diff.inHours} giờ trước';
    } catch (_) {
      return 'N/A';
    }
  }

  String get dutyCyclePercent {
    if (telemetry?.duty == null) return 'N/A';
    final percentage = (telemetry!.duty! / 1023 * 100).toStringAsFixed(1);
    return '$percentage%';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildCard(
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (telemetry == null) {
      return _buildCard(
        child: const Center(child: Text('Chưa có dữ liệu trạng thái')),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOnline ? Colors.green : Colors.red,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isOnline ? Colors.green : Colors.red).withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isOnline
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOnline
                          ? 'Thiết bị đang kết nối và hoạt động bình thường'
                          : 'Mất kết nối, vui lòng kiểm tra thiết bị',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thông tin thiết bị',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildMetricRow(
                icon: Icons.schedule_rounded,
                label: 'Cập nhật lần cuối',
                value: lastUpdateText,
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildMetricRow(
                icon: Icons.pool_rounded,
                label: 'ID Ao',
                value: '# ${telemetry?.pondId ?? 'N/A'}',
                color: Colors.purple,
              ),
              const SizedBox(height: 12),
              _buildMetricRow(
                icon: Icons.electric_meter_rounded,
                label: 'Trạng thái motor',
                value: telemetry?.motorRunning == true ? 'Đang chạy' : 'Dừng',
                color:
                    telemetry?.motorRunning == true ? Colors.orange : Colors.grey,
              ),
              const SizedBox(height: 12),
              _buildMetricRow(
                icon: Icons.settings_rounded,
                label: 'Chế độ hoạt động',
                value: telemetry?.mode ?? 'UNKNOWN',
                color: telemetry?.mode == 'AUTO' ? Colors.blue : Colors.orange,
              ),
              if (telemetry?.duty != null) ...[
                const SizedBox(height: 12),
                _buildMetricRow(
                  icon: Icons.speed_rounded,
                  label: 'Duty Cycle',
                  value: dutyCyclePercent,
                  color: Colors.teal,
                ),
              ],
            ],
          ),
        ),
        if (telemetry?.duty != null) ...[
          const SizedBox(height: 16),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chi tiết Duty Cycle',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  dutyCyclePercent,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (telemetry!.duty! / 1023).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.teal.shade600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
