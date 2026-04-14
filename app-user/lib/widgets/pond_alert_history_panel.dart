import 'package:flutter/material.dart';

import '../services/alert_history_store.dart';

class PondAlertHistoryPanel extends StatefulWidget {
  final int pondId;
  final String pondName;

  const PondAlertHistoryPanel({
    super.key,
    required this.pondId,
    required this.pondName,
  });

  @override
  State<PondAlertHistoryPanel> createState() => _PondAlertHistoryPanelState();
}

class _PondAlertHistoryPanelState extends State<PondAlertHistoryPanel> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didUpdateWidget(covariant PondAlertHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pondId != widget.pondId) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AlertHistoryStore.loadForPond(widget.pondId);
      if (!mounted) return;
      setState(() {
        _history = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _history = [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Color _levelColor(String level) {
    switch (level.toUpperCase()) {
      case 'DANGER':
        return Colors.red;
      case 'WARNING':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _formatTime(String? raw) {
    final value = DateTime.tryParse(raw ?? '');
    if (value == null) return '--:--';
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Lịch sử cảnh báo - ${widget.pondName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Làm mới',
              onPressed: _loading ? null : _loadHistory,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Text('Lỗi tải lịch sử: $_error', style: const TextStyle(color: Colors.red))
        else if (_history.isEmpty)
          const Text(
            'Chưa có cảnh báo nào được lưu cho ao này.',
            style: TextStyle(fontSize: 14),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: _history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _history[index];
                final level = (item['level'] ?? 'WARNING').toString();
                final color = _levelColor(level);
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notification_important_rounded, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['title'] ?? 'Cảnh báo'} • $level',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(item['message']?.toString() ?? ''),
                            const SizedBox(height: 6),
                            Text(
                              '${item['source'] ?? 'AI'} • ${_formatTime(item['createdAt']?.toString())}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}