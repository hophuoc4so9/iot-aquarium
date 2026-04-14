import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertHistoryStore {
  static const String _storageKey = 'alert_history_v1';

  static Future<List<Map<String, dynamic>>> loadForPond(int pondId) async {
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } on MissingPluginException {
      // Fallback for cases where plugin registrant is not ready yet.
      return [];
    }
    final rawList = prefs.getStringList(_storageKey) ?? const [];

    final items = <Map<String, dynamic>>[];
    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final value = decoded['pondId'];
          final normalizedPondId = _asInt(value);
          if (normalizedPondId == pondId) {
            items.add(decoded);
          }
        }
      } catch (_) {
        // Skip malformed entries.
      }
    }

    items.sort((a, b) {
      final at = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return items;
  }

  static Future<void> recordEvents(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) return;

    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } on MissingPluginException {
      // Avoid crashing UI when storage plugin is unavailable in current runtime.
      return;
    }
    final rawList = prefs.getStringList(_storageKey) ?? const [];
    final existing = <Map<String, dynamic>>[];

    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          existing.add(decoded);
        }
      } catch (_) {
        // Skip malformed entries.
      }
    }

    final now = DateTime.now();
    const dedupeWindow = Duration(minutes: 2);

    for (final event in events) {
      final pondId = _asInt(event['pondId']);
      final message = (event['message'] ?? '').toString().trim();
      if (pondId == null || message.isEmpty) continue;

      final level = (event['level'] ?? 'WARNING').toString();
      final source = (event['source'] ?? 'AI').toString();
      final dedupeKey = (event['dedupeKey'] ?? '$pondId|$source|$level|$message').toString();
      final createdAt = event['createdAt']?.toString() ?? now.toIso8601String();

      final isDuplicate = existing.any((item) {
        if (item['dedupeKey']?.toString() != dedupeKey) return false;
        final itemTime = DateTime.tryParse(item['createdAt']?.toString() ?? '');
        if (itemTime == null) return false;
        return now.difference(itemTime).abs() <= dedupeWindow;
      });

      if (isDuplicate) continue;

      existing.insert(0, {
        'pondId': pondId,
        'pondName': (event['pondName'] ?? '').toString(),
        'source': source,
        'level': level,
        'title': (event['title'] ?? 'Cảnh báo').toString(),
        'message': message,
        'createdAt': createdAt,
        'dedupeKey': dedupeKey,
      });
    }

    final trimmed = existing.take(300).map(jsonEncode).toList();
    await prefs.setStringList(_storageKey, trimmed);
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}