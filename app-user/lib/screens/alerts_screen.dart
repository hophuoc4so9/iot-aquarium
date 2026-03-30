import 'package:flutter/material.dart';
import '../widgets/alerts_panel.dart';
import '../models/alert.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class AlertsScreen extends StatefulWidget {
  final int pondId;

  const AlertsScreen({super.key, required this.pondId});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Alert> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  String _formatTime(DateTime dt) {
    return DateFormat('HH:mm:ss').format(dt);
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await ApiService.fetchAiAlertsForPond(widget.pondId);

      final ts = DateTime.tryParse(resp['timestamp'] as String? ?? '') ??
          DateTime.now();
      final timeStr = _formatTime(ts);

      final List<dynamic> list = resp['alerts'] ?? [];
      final alerts = list.map((e) {
        final m = e as Map<String, dynamic>;
        final metric = m['metric'] as String? ?? '';
        final msg = m['message'] as String? ?? '';
        final level = m['level'] as String? ?? 'OK';
        final prefix = switch (level) {
          'DANGER' => '🚨',
          'WARNING' => '⚠️',
          _ => '✅',
        };
        return Alert(
          message: '$prefix [$metric] $msg',
          time: timeStr,
        );
      }).toList();

      if (alerts.isEmpty) {
        alerts.add(
          Alert(
            message: "✅ Hệ thống hoạt động bình thường",
            time: _formatTime(DateTime.now()),
          ),
        );
      }

      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cảnh báo AI"),
        backgroundColor: Colors.blue,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text('Lỗi: $_error'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: AlertsPanel(alerts: _alerts),
            ),
    );
  }
}
