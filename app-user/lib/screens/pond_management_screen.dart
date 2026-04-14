import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import '../models/telemetry.dart';
import '../widgets/pond_alert_history_panel.dart';

class PondInfo {
  final int id;
  final int? deviceId;
  final String name;
  final String? fishType;
  final String? area;
  final double? customTempMin;
  final double? customTempMax;
  final double? customPhMin;
  final double? customPhMax;

  PondInfo({
    required this.id,
    this.deviceId,
    required this.name,
    this.fishType,
    this.area,
    this.customTempMin,
    this.customTempMax,
    this.customPhMin,
    this.customPhMax,
  });
}

/// Màn hình quản lý danh sách ao nuôi.
/// - Đồng bộ danh sách ao từ backend (/api/ponds).
/// - (Tuỳ chọn) cho phép thêm ao cục bộ bằng cách nhập mã / thông tin.
/// - Chọn 1 ao để xem dashboard/AI alerts tương ứng.
class PondManagementScreen extends StatefulWidget {
  const PondManagementScreen({super.key});

  @override
  State<PondManagementScreen> createState() => _PondManagementScreenState();
}

class _PondManagementScreenState extends State<PondManagementScreen> {
  static const int _onlineThresholdSeconds = 15 * 60;

  final List<PondInfo> _ponds = [];
  int? _selectedIndex;
  int? _editingPondId;
  bool _isLoading = false;
  bool _isSavingPondInfo = false;
  bool _isLoadingFishTypes = false;
  bool _isLoadingThresholds = false;
  bool _isSavingThresholds = false;
  bool _isResettingThresholds = false;
  String? _error;
  String? _thresholdError;
  String? _thresholdSourceLabel;
  int _aiTabReloadToken = 0;
  Map<int, bool>? _onlineByPond;
  final Map<int, String> _lastSeenByPond = {};
  TextEditingController? _pondNameController;
  TextEditingController? _tempMinController;
  TextEditingController? _tempMaxController;
  TextEditingController? _phMinController;
  TextEditingController? _phMaxController;
  List<Map<String, dynamic>>? _fishCatalog;
  Map<String, dynamic>? _selectedFish;
  final List<String> _fishTypeOptions = [];
  String? _selectedFishType;
  Timer? _statusTimer;

  Map<int, bool> get _safeOnlineByPond {
    _onlineByPond ??= <int, bool>{};
    return _onlineByPond!;
  }

  TextEditingController get _safePondNameController {
    _pondNameController ??= TextEditingController();
    return _pondNameController!;
  }

  TextEditingController get _safeTempMinController {
    _tempMinController ??= TextEditingController();
    return _tempMinController!;
  }

  TextEditingController get _safeTempMaxController {
    _tempMaxController ??= TextEditingController();
    return _tempMaxController!;
  }

  TextEditingController get _safePhMinController {
    _phMinController ??= TextEditingController();
    return _phMinController!;
  }

  TextEditingController get _safePhMaxController {
    _phMaxController ??= TextEditingController();
    return _phMaxController!;
  }

  List<Map<String, dynamic>> get _safeFishCatalog {
    _fishCatalog ??= <Map<String, dynamic>>[];
    return _fishCatalog!;
  }

  String get _safeThresholdSourceLabel {
    final value = _thresholdSourceLabel;
    if (value == null || value.trim().isEmpty) {
      return 'Mặc định hệ thống';
    }
    return value;
  }

  void _ensureStatusTimer() {
    if (_statusTimer != null) return;
    _statusTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _refreshPondOnlineStatuses();
    });
  }

  double? _predictNextHourValue({
    required List<AquariumTelemetry> data,
    required double? Function(AquariumTelemetry) selector,
    required double min,
    required double max,
  }) {
    final rows = data
        .map((item) => (t: DateTime.tryParse(item.timestamp ?? ''), v: selector(item)))
        .where((row) => row.t != null && row.v != null)
        .cast<({DateTime t, double v})>()
        .toList();

    if (rows.length < 2) {
      return null;
    }

    final points = rows.length > 20 ? rows.sublist(rows.length - 20) : rows;
    final t0 = points.first.t.millisecondsSinceEpoch.toDouble();
    final xs = points
        .map((p) => (p.t.millisecondsSinceEpoch.toDouble() - t0) / 60000.0)
        .toList();
    final ys = points.map((p) => p.v).toList();

    final n = xs.length;
    final xMean = xs.reduce((a, b) => a + b) / n;
    final yMean = ys.reduce((a, b) => a + b) / n;

    double num = 0;
    double den = 0;
    for (int i = 0; i < n; i++) {
      final dx = xs[i] - xMean;
      num += dx * (ys[i] - yMean);
      den += dx * dx;
    }

    final slope = den == 0 ? 0 : (num / den);
    final intercept = yMean - slope * xMean;
    final targetX = ((points.last.t.add(const Duration(hours: 1))).millisecondsSinceEpoch.toDouble() - t0) / 60000.0;
    final predicted = slope * targetX + intercept;

    return predicted.clamp(min, max).toDouble();
  }

  Widget _buildAiMetricCard({
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
  void initState() {
    super.initState();
    _pondNameController = TextEditingController();
    _tempMinController = TextEditingController();
    _tempMaxController = TextEditingController();
    _phMinController = TextEditingController();
    _phMaxController = TextEditingController();
    _fishCatalog = <Map<String, dynamic>>[];
    _thresholdSourceLabel = 'Mặc định hệ thống';
    _loadPondsFromBackend();
    _loadFishTypeOptions();
    _ensureStatusTimer();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _pondNameController?.dispose();
    _tempMinController?.dispose();
    _tempMaxController?.dispose();
    _phMinController?.dispose();
    _phMaxController?.dispose();
    _pondNameController = null;
    _tempMinController = null;
    _tempMaxController = null;
    _phMinController = null;
    _phMaxController = null;
    _fishCatalog = null;
    _thresholdSourceLabel = null;
    super.dispose();
  }

  Future<void> _loadPondsFromBackend() async {
    final currentSelectedPondId =
        _selectedIndex != null && _selectedIndex! >= 0 && _selectedIndex! < _ponds.length
            ? _ponds[_selectedIndex!].id
            : null;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await ApiService.fetchPonds();
      final ponds = <PondInfo>[];
      for (final e in list) {
        ponds.add(
          PondInfo(
            id: (e['id'] as num).toInt(),
            deviceId: e['deviceId'] is num ? (e['deviceId'] as num).toInt() : null,
            name: (e['name'] as String?) ?? 'Ao #${e['id']}',
            fishType: e['fishType'] as String?,
            area: e['area'] as String?,
            customTempMin: _toDouble(e['customTempMin']),
            customTempMax: _toDouble(e['customTempMax']),
            customPhMin: _toDouble(e['customPhMin']),
            customPhMax: _toDouble(e['customPhMax']),
          ),
        );
      }

      setState(() {
        _ponds
          ..clear()
          ..addAll(ponds);
        if (_ponds.isNotEmpty) {
          final restoredIndex = currentSelectedPondId == null
              ? 0
              : _ponds.indexWhere((p) => p.id == currentSelectedPondId);
          _selectedIndex = restoredIndex >= 0 ? restoredIndex : 0;
          _syncPondEditorState(_ponds[_selectedIndex!]);
        }
        _isLoading = false;
      });
      _refreshPondOnlineStatuses();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFishTypeOptions() async {
    setState(() {
      _isLoadingFishTypes = true;
    });

    try {
      final response = await ApiService.fetchConfiguredFish(page: 0, size: 80);
      final dynamic content = response['content'];
      final dynamic fallbackData = response['data'];
      final List<dynamic> rawItems = content is List<dynamic>
          ? content
          : fallbackData is List<dynamic>
              ? fallbackData
              : const [];
      final names = <String>{};
      final catalog = <Map<String, dynamic>>[];

      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);

        final vn = (item['nameVietnamese'] ?? '').toString().trim();
        final en = (item['nameEnglish'] ?? '').toString().trim();
        final common = (item['commonName'] ?? '').toString().trim();
        String displayName = vn;
        if (displayName.isEmpty) displayName = en;
        if (displayName.isEmpty) displayName = common;

        if (vn.isNotEmpty) names.add(vn);
        if (en.isNotEmpty) names.add(en);
        if (common.isNotEmpty) names.add(common);
        if (displayName.isNotEmpty) {
          names.add(displayName);
          catalog.add(item);
        }
      }

      for (final pond in _ponds) {
        final ft = pond.fishType?.trim();
        if (ft != null && ft.isNotEmpty) names.add(ft);
      }

      if (!mounted) return;
      setState(() {
        _safeFishCatalog
          ..clear()
          ..addAll(catalog);
        _fishTypeOptions
          ..clear()
          ..addAll(names.toList()..sort());
        _isLoadingFishTypes = false;
      });
      _loadThresholdsForSelection();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingFishTypes = false;
      });
    }
  }

  String _displayFishName(Map<String, dynamic> fish) {
    final vn = (fish['nameVietnamese'] ?? '').toString().trim();
    final en = (fish['nameEnglish'] ?? '').toString().trim();
    final common = (fish['commonName'] ?? '').toString().trim();
    if (vn.isNotEmpty) return vn;
    if (en.isNotEmpty) return en;
    if (common.isNotEmpty) return common;
    return '';
  }

  String _normalizeFishKey(String? raw) {
    if (raw == null) return '';
    final lower = raw.trim().toLowerCase();
    return lower.replaceAll(RegExp(r'\s+'), ' ');
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  PondInfo? _currentEditingPond() {
    final id = _editingPondId;
    if (id == null) return null;
    for (final p in _ponds) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _applyThresholdValues({
    required double? tempMin,
    required double? tempMax,
    required double? phMin,
    required double? phMax,
  }) {
    _safeTempMinController.text = tempMin?.toStringAsFixed(1) ?? '';
    _safeTempMaxController.text = tempMax?.toStringAsFixed(1) ?? '';
    _safePhMinController.text = phMin?.toStringAsFixed(1) ?? '';
    _safePhMaxController.text = phMax?.toStringAsFixed(1) ?? '';
  }

  Map<String, dynamic>? _findFishBySelectedType() {
    final selected = _selectedFishType?.trim();
    if (selected == null || selected.isEmpty) return null;
    final normalizedSelected = _normalizeFishKey(selected);

    // 1) Ưu tiên match chính xác theo nhiều trường tên.
    for (final fish in _safeFishCatalog) {
      final vn = _normalizeFishKey((fish['nameVietnamese'] ?? '').toString());
      final en = _normalizeFishKey((fish['nameEnglish'] ?? '').toString());
      final common = _normalizeFishKey((fish['commonName'] ?? '').toString());
      final key = _normalizeFishKey((fish['nameKey'] ?? '').toString());
      if (vn == normalizedSelected ||
          en == normalizedSelected ||
          common == normalizedSelected ||
          key == normalizedSelected) {
        return fish;
      }
    }

    // 2) Match gần đúng khi user nhập rút gọn.
    for (final fish in _safeFishCatalog) {
      final names = <String>[
        _normalizeFishKey((fish['nameVietnamese'] ?? '').toString()),
        _normalizeFishKey((fish['nameEnglish'] ?? '').toString()),
        _normalizeFishKey((fish['commonName'] ?? '').toString()),
      ].where((e) => e.isNotEmpty);

      for (final n in names) {
        if (n.contains(normalizedSelected) || normalizedSelected.contains(n)) {
          return fish;
        }
      }
    }

    return null;
  }

  Future<void> _loadThresholdsForSelection() async {
    if (!mounted) return;
    setState(() {
      _isLoadingThresholds = true;
      _thresholdError = null;
    });

    try {
      final currentPond = _currentEditingPond();
      final hasPondCustom = currentPond != null &&
          currentPond.customTempMin != null &&
          currentPond.customTempMax != null &&
          currentPond.customPhMin != null &&
          currentPond.customPhMax != null;

      if (hasPondCustom) {
        _applyThresholdValues(
          tempMin: currentPond!.customTempMin,
          tempMax: currentPond.customTempMax,
          phMin: currentPond.customPhMin,
          phMax: currentPond.customPhMax,
        );
        if (!mounted) return;
        setState(() {
          _thresholdSourceLabel = 'Ngưỡng riêng của bể';
          _isLoadingThresholds = false;
        });
        return;
      }

      _selectedFish = _findFishBySelectedType();
      if (_selectedFish == null) {
        final selected = _selectedFishType?.trim() ?? '';
        if (selected.isNotEmpty) {
          final searchResults = await ApiService.searchFishByName(selected);
          if (searchResults.isNotEmpty) {
            // Ưu tiên match gần nhất theo tên hiển thị, fallback phần tử đầu.
            final normalizedSelected = _normalizeFishKey(selected);
            Map<String, dynamic>? picked;
            for (final fish in searchResults) {
              final dn = _normalizeFishKey(_displayFishName(fish));
              if (dn == normalizedSelected ||
                  dn.contains(normalizedSelected) ||
                  normalizedSelected.contains(dn)) {
                picked = fish;
                break;
              }
            }
            _selectedFish = picked ?? searchResults.first;

            final display = _displayFishName(_selectedFish!);
            if (display.isNotEmpty && !_fishTypeOptions.contains(display)) {
              _fishTypeOptions.add(display);
              _fishTypeOptions.sort();
            }
          }
        }
      }

      final fishId = (_selectedFish?['id'] as num?)?.toInt();

      if (fishId != null) {
        final detail = await ApiService.fetchFishDetail(fishId);
        final effective = detail['effectiveThresholds'] is Map
            ? Map<String, dynamic>.from(detail['effectiveThresholds'] as Map)
            : <String, dynamic>{};
        final usingCustom = detail['usingCustom'] == true;

        _applyThresholdValues(
          tempMin: _toDouble(effective['tempMin']),
          tempMax: _toDouble(effective['tempMax']),
          phMin: _toDouble(effective['phMin']),
          phMax: _toDouble(effective['phMax']),
        );

        if (!mounted) return;
        setState(() {
          _thresholdSourceLabel = usingCustom
              ? 'Ngưỡng tùy chỉnh của loài cá'
              : 'Ngưỡng mặc định của loài cá/hệ thống';
          _isLoadingThresholds = false;
        });
        return;
      }

      final defaults = await ApiService.fetchFishDefaultThresholds();
      _applyThresholdValues(
        tempMin: _toDouble(defaults['tempMin']),
        tempMax: _toDouble(defaults['tempMax']),
        phMin: _toDouble(defaults['phMin']),
        phMax: _toDouble(defaults['phMax']),
      );

      if (!mounted) return;
      setState(() {
        _thresholdSourceLabel = 'Ngưỡng mặc định hệ thống';
        _isLoadingThresholds = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _thresholdError = 'Không tải được ngưỡng: $e';
        _isLoadingThresholds = false;
      });
    }
  }

  void _syncPondEditorState(PondInfo pond) {
    if (_editingPondId == pond.id) return;
    _editingPondId = pond.id;
    _safePondNameController.text = pond.name;
    _selectedFishType = pond.fishType?.trim().isEmpty ?? true
        ? null
        : pond.fishType?.trim();
    _selectedFish = null;
    if (_selectedFishType != null && !_fishTypeOptions.contains(_selectedFishType)) {
      _fishTypeOptions.add(_selectedFishType!);
      _fishTypeOptions.sort();
    }
    _loadThresholdsForSelection();
  }

  Future<void> _savePondInfo(PondInfo pond) async {
    final nextName = _safePondNameController.text.trim();
    final nextFishType = (_selectedFishType ?? '').trim();

    if (nextName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên bể không được để trống')),
      );
      return;
    }

    setState(() {
      _isSavingPondInfo = true;
    });

    try {
      await ApiService.updatePond(
        pond.id,
        name: nextName,
        fishType: nextFishType.isEmpty ? '' : nextFishType,
      );

      if (!mounted) return;
      await _loadPondsFromBackend();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật thông tin bể cá')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingPondInfo = false;
      });
    }
  }

  Future<void> _saveFishThresholds() async {
    final pond = _currentEditingPond();
    if (pond == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không xác định được bể để cập nhật ngưỡng')),
      );
      return;
    }

    final tempMin = double.tryParse(_safeTempMinController.text.trim());
    final tempMax = double.tryParse(_safeTempMaxController.text.trim());
    final phMin = double.tryParse(_safePhMinController.text.trim());
    final phMax = double.tryParse(_safePhMaxController.text.trim());

    if (tempMin == null || tempMax == null || phMin == null || phMax == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ giá trị số cho ngưỡng')), 
      );
      return;
    }

    setState(() {
      _isSavingThresholds = true;
      _thresholdError = null;
    });

    try {
      await ApiService.updatePondThresholds(
        pond.id,
        tempMin: tempMin,
        tempMax: tempMax,
        phMin: phMin,
        phMax: phMax,
      );

      if (!mounted) return;
      await _loadPondsFromBackend();
      if (!mounted) return;
      await _loadThresholdsForSelection();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật ngưỡng riêng cho bể')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _thresholdError = 'Lỗi cập nhật ngưỡng: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingThresholds = false;
      });
    }
  }

  Future<void> _resetFishThresholds() async {
    final pond = _currentEditingPond();

    if (pond == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không xác định được bể để reset ngưỡng')),
      );
      return;
    }

    setState(() {
      _isResettingThresholds = true;
      _thresholdError = null;
    });

    try {
      await ApiService.resetPondThresholds(pond.id);
      if (!mounted) return;
      await _loadPondsFromBackend();
      if (!mounted) return;
      await _loadThresholdsForSelection();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã reset ngưỡng riêng của bể (fallback loài/hệ thống)')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _thresholdError = 'Lỗi reset ngưỡng: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isResettingThresholds = false;
      });
    }
  }

  Widget _buildPondFishInfoTab(PondInfo pond) {
    _syncPondEditorState(pond);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
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
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: Colors.blueGrey),
                  SizedBox(width: 6),
                  Text(
                    'Thông tin bể cá',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'ID ao: ${pond.id}${pond.deviceId != null ? ' | deviceId: ${pond.deviceId}' : ''}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Trạng thái: ${(_safeOnlineByPond[pond.id] ?? false) ? 'Online' : 'Offline'}',
                style: TextStyle(
                  fontSize: 13,
                  color: (_safeOnlineByPond[pond.id] ?? false)
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_lastSeenByPond[pond.id] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Cập nhật gần nhất: ${_lastSeenByPond[pond.id]}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
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
              const Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: Colors.indigo),
                  SizedBox(width: 6),
                  Text(
                    'Cấu hình bể',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _safePondNameController,
                decoration: InputDecoration(
                  labelText: 'Tên bể cá',
                  prefixIcon: const Icon(Icons.edit_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoadingFishTypes)
                const LinearProgressIndicator(minHeight: 2)
              else
                DropdownButtonFormField<String>(
                  value: _selectedFishType,
                  decoration: InputDecoration(
                    labelText: 'Loại cá',
                    prefixIcon: const Icon(Icons.set_meal_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Chưa chọn loại cá'),
                    ),
                    for (final name in _fishTypeOptions)
                      DropdownMenuItem<String>(
                        value: name,
                        child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFishType = value;
                    });
                    _loadThresholdsForSelection();
                  },
                ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.thermostat_rounded, size: 18, color: Colors.teal),
                        SizedBox(width: 6),
                        Text(
                          'Ngưỡng pH / nhiệt độ',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nguồn: $_safeThresholdSourceLabel',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    if (_selectedFish == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Bể chưa có ngưỡng riêng, đang fallback theo loài hoặc hệ thống.',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                        ),
                      ),
                    if (_thresholdError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _thresholdError!,
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (_isLoadingThresholds)
                      const LinearProgressIndicator(minHeight: 2)
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _safeTempMinController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: 'Nhiệt độ min (°C)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _safeTempMaxController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: 'Nhiệt độ max (°C)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _safePhMinController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: 'pH min',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _safePhMaxController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: 'pH max',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isResettingThresholds ? null : _resetFishThresholds,
                                  icon: _isResettingThresholds
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.restart_alt_rounded),
                                  label: const Text('Reset mặc định'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isSavingThresholds
                                      ? null
                                      : _saveFishThresholds,
                                  icon: _isSavingThresholds
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save_as_rounded),
                                  label: const Text('Cập nhật ngưỡng'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingFishTypes ? null : _loadFishTypeOptions,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tải lại loại cá'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSavingPondInfo ? null : () => _savePondInfo(pond),
                      icon: _isSavingPondInfo
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSavingPondInfo ? 'Đang lưu...' : 'Lưu thay đổi'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _refreshPondOnlineStatuses() async {
    if (_ponds.isEmpty) return;

    try {
      final snapshots = await ApiService.fetchPondSnapshots();
      final updates = <int, bool>{};
      final seen = <int, String>{};

      for (final raw in snapshots) {
        final snapshotPondId = (raw['id'] as num?)?.toInt();
        if (snapshotPondId == null) continue;

        final rawLastTelemetryAt = raw['lastTelemetryAt']?.toString().trim();
        DateTime? lastUpdate;
        if (rawLastTelemetryAt != null && rawLastTelemetryAt.isNotEmpty) {
          lastUpdate = DateTime.tryParse(rawLastTelemetryAt);
        }

        final isOnline = lastUpdate != null
          ? DateTime.now().difference(lastUpdate).inSeconds.abs() < _onlineThresholdSeconds
          : false;

        updates[snapshotPondId] = isOnline;
        if (rawLastTelemetryAt != null && rawLastTelemetryAt.isNotEmpty) {
          seen[snapshotPondId] = rawLastTelemetryAt;
        }
      }

      if (!mounted) return;
      setState(() {
        _safeOnlineByPond
          ..clear()
          ..addAll(updates);
        _lastSeenByPond
          ..clear()
          ..addAll(seen);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _safeOnlineByPond.clear();
        _lastSeenByPond.clear();
      });
    }
  }

  void _onAddPondPressed() {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const Text(
                    'Thêm ao bằng deviceId',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nhập deviceId số của ESP32.\n'
                    'Hiện tại thiết bị đang dùng deviceId = 5.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: 'deviceId',
                      prefixIcon: const Icon(Icons.qr_code_2_rounded),
                      errorText: errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Tên hiển thị (tuỳ chọn)',
                      prefixIcon: const Icon(Icons.edit_rounded),
                      helperText: 'Nếu bỏ trống, hệ thống sẽ đặt tên tự động.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Huỷ'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final code = codeController.text.trim();
                          if (code.isEmpty) {
                            setModalState(() {
                              errorText = 'Vui lòng nhập deviceId (số)';
                            });
                            return;
                          }

                          final id = int.tryParse(code);
                          if (id == null) {
                            setModalState(() {
                              errorText = 'deviceId phải là số';
                            });
                            return;
                          }

                          try {
                            await ApiService.bindDeviceById(id);
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            await _loadPondsFromBackend();
                          } catch (e) {
                            setModalState(() {
                              errorText = e.toString();
                            });
                          }
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Lưu ao'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAiOverviewTab(PondInfo pond) {
    return FutureBuilder<List<dynamic>>(
      key: ValueKey('ai-${pond.id}-$_aiTabReloadToken'),
      future: Future.wait<dynamic>([
        ApiService.fetchAiAlertsForPond(pond.id),
        ApiService.fetchRecentTelemetry(pondId: pond.id),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'Không tải được dữ liệu AI: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _aiTabReloadToken++;
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data != null && snapshot.data!.isNotEmpty
            ? (snapshot.data![0] as Map<String, dynamic>)
            : <String, dynamic>{};
        final recentTelemetry = snapshot.data != null && snapshot.data!.length > 1
            ? (snapshot.data![1] as List<AquariumTelemetry>)
            : <AquariumTelemetry>[];
        final thresholdsSource = (data['thresholdsSource'] ?? 'N/A').toString();
        final warning = data['warning']?.toString();
        final timestamp = data['timestamp']?.toString();
        final summary = (data['summary'] ?? data['prediction'] ?? data['insight'] ?? '').toString();
        final fallback = data['fallback'] == true;
        final tempPred = _predictNextHourValue(
          data: recentTelemetry,
          selector: (x) => x.temperature,
          min: 0,
          max: 45,
        );
        final phPred = _predictNextHourValue(
          data: recentTelemetry,
          selector: (x) => x.ph,
          min: 0,
          max: 14,
        );
        double? latestAnomalyScore;
        bool? latestAnomalyFlag;
        for (final item in recentTelemetry.reversed) {
          if (item.anomalyScore != null || item.anomalyFlag != null) {
            latestAnomalyScore = item.anomalyScore;
            latestAnomalyFlag = item.anomalyFlag;
            break;
          }
        }
        if (latestAnomalyFlag == null && latestAnomalyScore != null) {
          latestAnomalyFlag = latestAnomalyScore > 0.12;
        }
        final earlyWarnings = <String>[];
        if (tempPred != null && (tempPred < 18 || tempPred > 30)) {
          earlyWarnings.add('Nhiệt độ dự đoán sau 1 giờ có thể vượt ngưỡng an toàn.');
        }
        if (phPred != null && (phPred < 6.0 || phPred > 8.5)) {
          earlyWarnings.add('pH dự đoán sau 1 giờ có thể vượt ngưỡng an toàn.');
        }

        final rawAlertsDynamic = data['alerts'];
        final List<dynamic> rawAlerts = rawAlertsDynamic is List<dynamic>
            ? rawAlertsDynamic
            : const [];
        final alerts = <Map<String, dynamic>>[];
        for (final e in rawAlerts) {
          if (e is Map) {
            alerts.add(Map<String, dynamic>.from(e));
          }
        }
        final abnormalAlerts = alerts
            .where((a) => (a['level'] ?? 'OK').toString().toUpperCase() != 'OK')
            .toList();

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _aiTabReloadToken++;
            });
          },
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
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
                      children: [
                        const Icon(Icons.psychology_alt_rounded, size: 18, color: Colors.purple),
                        const SizedBox(width: 6),
                        const Text(
                          'AI dự đoán & cảnh báo sớm (1 giờ tới)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildAiMetricCard(
                          label: 'Nhiệt độ sau 1h',
                          value: tempPred == null ? '--' : '${tempPred.toStringAsFixed(1)}°C',
                          icon: Icons.thermostat,
                          color: Colors.deepOrange,
                        ),
                        const SizedBox(width: 10),
                        _buildAiMetricCard(
                          label: 'pH sau 1h',
                          value: phPred == null ? '--' : phPred.toStringAsFixed(2),
                          icon: Icons.science,
                          color: Colors.teal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (latestAnomalyFlag == true ? Colors.red : Colors.indigo).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (latestAnomalyFlag == true ? Colors.red : Colors.indigo).withOpacity(0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                latestAnomalyFlag == true
                                    ? Icons.warning_amber_rounded
                                    : Icons.auto_graph_rounded,
                                size: 18,
                                color: latestAnomalyFlag == true ? Colors.red : Colors.indigo,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                latestAnomalyFlag == true
                                    ? 'Anomaly: phát hiện bất thường'
                                    : 'Anomaly: trạng thái ổn định',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: latestAnomalyFlag == true ? Colors.red : Colors.indigo,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Điểm anomaly: ${latestAnomalyScore != null ? latestAnomalyScore.toStringAsFixed(3) : 'chưa có'}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Anomaly là độ lệch giữa nhiệt độ dự đoán từ model trên thiết bị và nhiệt độ đo thực tế.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (earlyWarnings.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Chưa thấy rủi ro sớm trong 1 giờ tới theo xu hướng hiện tại.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...earlyWarnings.map(
                        (msg) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text('Nguồn ngưỡng: $thresholdsSource', style: const TextStyle(fontSize: 13)),
                    if (timestamp != null && timestamp.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Thời điểm: $timestamp', style: const TextStyle(fontSize: 13)),
                      ),
                    if (summary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(summary, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                    if (warning != null && warning.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Lưu ý: $warning',
                          style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
                        ),
                      ),
                    if (fallback)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'AI đang dùng dữ liệu fallback.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
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
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Colors.redAccent),
                        SizedBox(width: 6),
                        Text(
                          'Cảnh báo bất thường',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (abnormalAlerts.isEmpty)
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 18),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text('Không có cảnh báo bất thường từ AI.'),
                          ),
                        ],
                      )
                    else
                      for (final alert in abnormalAlerts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Builder(
                            builder: (context) {
                              final level = (alert['level'] ?? 'WARNING').toString();
                              final metric = (alert['metric'] ?? 'Chỉ số').toString();
                              final message = (alert['message'] ?? '').toString();
                              final Color levelColor =
                                  level == 'DANGER' ? Colors.red : Colors.orange;

                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: levelColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: levelColor.withOpacity(0.4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$metric • $level',
                                      style: TextStyle(
                                        color: levelColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      message.isEmpty
                                          ? 'Phát hiện bất thường từ AI.'
                                          : message,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureStatusTimer();
    final selectedPond =
        _selectedIndex != null && _ponds.isNotEmpty ? _ponds[_selectedIndex!] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý ao nuôi'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Làm mới từ backend',
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadPondsFromBackend,
          ),
          IconButton(
            tooltip: 'Thêm thiết bị bằng deviceId',
            icon: const Icon(Icons.add_rounded),
            onPressed: _onAddPondPressed,
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'Lỗi tải danh sách ao:\n$_error',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadPondsFromBackend,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 102,
                  child: _ponds.isEmpty && _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _ponds.isEmpty
                          ? const Center(
                              child: Text(
                                'Chưa có ao nào trong hệ thống.\nHãy tạo ao trên web-admin hoặc thêm ao cục bộ.',
                                textAlign: TextAlign.center,
                              ),
                            )
                            : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                final pond = _ponds[index];
                                final bool isSelected = index == _selectedIndex;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedIndex = index;
                                      _syncPondEditorState(_ponds[index]);
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 170,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue.shade50
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue
                                            : Colors.grey.shade300,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Colors.black.withOpacity(0.03),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                pond.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (isSelected)
                                              const Icon(
                                                Icons.check_circle,
                                                color: Colors.blue,
                                                size: 18,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (pond.fishType != null &&
                                            pond.fishType!.isNotEmpty)
                                          Text(
                                            pond.fishType!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        if (pond.area != null &&
                                            pond.area!.isNotEmpty)
                                          Text(
                                            'Diện tích: ${pond.area}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: (_safeOnlineByPond[pond.id] ?? false)
                                                    ? Colors.green
                                                    : Colors.redAccent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              (_safeOnlineByPond[pond.id] ?? false)
                                                  ? 'Online'
                                                  : 'Offline',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: (_safeOnlineByPond[pond.id] ?? false)
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Ao #${pond.id}${pond.deviceId != null ? ' | deviceId ${pond.deviceId}' : ''}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemCount: _ponds.length,
                            ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Thêm thiết bị mới bằng deviceId'),
                    onPressed: _onAddPondPressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue.shade200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (selectedPond != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Đang xem ao: ${selectedPond.name} (#${selectedPond.id}${selectedPond.deviceId != null ? ', deviceId ${selectedPond.deviceId}' : ''})',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  Expanded(
                    child: DefaultTabController(
                      length: 4,
                      child: Column(
                        children: [
                          TabBar(
                            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                            tabs: const [
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.dashboard_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Text('Dashboard', style: TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.history_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Text('Cảnh báo', style: TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.psychology_alt_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Text('AI', style: TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.set_meal_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Text('Loại cá', style: TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: DashboardScreen(
                                    pondId: selectedPond.deviceId ?? selectedPond.id,
                                    pondName: selectedPond.name,
                                    fishType: selectedPond.fishType,
                                    area: selectedPond.area,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: PondAlertHistoryPanel(
                                    pondId: selectedPond.id,
                                    pondName: selectedPond.name,
                                  ),
                                ),
                                _buildAiOverviewTab(selectedPond),
                                _buildPondFishInfoTab(selectedPond),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Hãy chọn hoặc thêm một ao để bắt đầu theo dõi.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

