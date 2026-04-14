import 'package:flutter/material.dart';

class ControlButtons extends StatelessWidget {
  final String currentMode;
  final bool isMotorRunning;
  final bool isBusy;
  final Future<void> Function(String mode) onSetMode;
  final Future<void> Function(String command) onControlMotor;

  const ControlButtons({
    super.key,
    required this.currentMode,
    required this.isMotorRunning,
    required this.isBusy,
    required this.onSetMode,
    required this.onControlMotor,
  });

  @override
  Widget build(BuildContext context) {
    final isManual = currentMode.toUpperCase() == 'MANUAL';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Điều khiển bơm',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildModeButton(
              label: 'AUTO',
              isSelected: !isManual,
              color: Colors.blue,
              onPressed: isBusy ? null : () => onSetMode('AUTO'),
            ),
            _buildModeButton(
              label: 'MANUAL',
              isSelected: isManual,
              color: Colors.orange,
              onPressed: isBusy ? null : () => onSetMode('MANUAL'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildButton(
              Icons.sync,
              'FORWARD',
              Colors.green,
              onPressed: isBusy || !isManual ? null : () => onControlMotor('FORWARD'),
            ),
            _buildButton(
              Icons.stop,
              isMotorRunning ? 'STOP' : 'STOP',
              Colors.red,
              onPressed: isBusy ? null : () => onControlMotor('STOP'),
            ),
            _buildButton(
              Icons.water_drop,
              'BACKWARD',
              Colors.blue,
              onPressed: isBusy || !isManual ? null : () => onControlMotor('BACKWARD'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isManual
              ? 'Đang ở MANUAL: bạn có thể điều khiển bơm thủ công.'
              : 'Đang ở AUTO: ESP32 tự bật/tắt bơm theo phao nước.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 20,
      ),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.white,
        foregroundColor: isSelected ? Colors.white : color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildButton(
    IconData icon,
    String label,
    Color color, {
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
