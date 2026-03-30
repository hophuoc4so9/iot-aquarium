import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

/// Trang camera / chẩn đoán bệnh cá.
class CameraDiagnosisScreen extends StatefulWidget {
  const CameraDiagnosisScreen({super.key});

  @override
  State<CameraDiagnosisScreen> createState() => _CameraDiagnosisScreenState();
}

class _CameraDiagnosisScreenState extends State<CameraDiagnosisScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _imageFile;
  bool _loading = false;
  bool _historyLoading = false;
  bool _pondLoading = false;
  Map<String, dynamic>? _result;
  String? _error;
  String? _historyError;
  int? _selectedPondId;
  int? _historyFilterPondId;
  List<Map<String, dynamic>> _ponds = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadPondsAndHistory();
  }

  Future<void> _loadPondsAndHistory() async {
    setState(() {
      _pondLoading = true;
    });

    try {
      final ponds = await ApiService.fetchPonds();
      if (!mounted) return;
      setState(() {
        _ponds = ponds;
      });
    } catch (_) {
      // Không chặn luồng chẩn đoán nếu không tải được danh sách ao.
    } finally {
      if (!mounted) return;
      setState(() {
        _pondLoading = false;
      });
    }

    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });

    try {
      final data = await ApiService.fetchFishDiseaseHistory(
        pondId: _historyFilterPondId,
      );
      if (!mounted) return;
      setState(() {
        _history = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _historyLoading = false;
      });
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value);
    }
    return null;
  }

  Future<void> _pickAndDiagnose(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _imageFile = picked;
      _loading = true;
      _result = null;
      _error = null;
    });

    try {
      final data = await ApiService.classifyFishDisease(
        pondId: _selectedPondId,
        imageFile: picked,
      );
      setState(() {
        _result = data;
      });
      await _loadHistory();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera - Chẩn đoán bệnh cá'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPondsAndHistory,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ao dùng để chẩn đoán',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: _selectedPondId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    hint: const Text('Không chọn ao'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Không chọn ao'),
                      ),
                      ..._ponds.map((pond) {
                        final id = _asInt(pond['id']);
                        final name = (pond['name'] ?? 'Ao không tên').toString();
                        if (id == null) return null;
                        return DropdownMenuItem<int?>(
                          value: id,
                          child: Text('$name (#$id)'),
                        );
                      }).whereType<DropdownMenuItem<int?>>(),
                    ],
                    onChanged: _pondLoading
                        ? null
                        : (value) {
                            setState(() {
                              _selectedPondId = value;
                            });
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.grey.shade200,
                  child: _imageFile == null
                      ? const Center(
                          child: Text(
                            'Chọn ảnh hoặc chụp ảnh cá để AI phân loại.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Image.network(
                          _imageFile!.path,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () => _pickAndDiagnose(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Chọn ảnh'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : () => _pickAndDiagnose(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Chụp ảnh'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _loading
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Đang gửi ảnh tới AI...'),
                      ],
                    )
                  : _error != null
                      ? Text(
                          'Lỗi: $_error',
                          style: const TextStyle(fontSize: 14, color: Colors.red),
                        )
                      : _result == null
                          ? const Text(
                              'Kết quả chẩn đoán sẽ hiển thị ở đây.',
                              style: TextStyle(fontSize: 14),
                            )
                          : Text(
                              "Nhãn: ${_result!['label'] ?? '-'}\n"
                              "Độ tin cậy: ${(_result!['score'] as num?)?.toDouble() != null ? (((_result!['score'] as num).toDouble()) * 100).toStringAsFixed(1) : '-'}%",
                              style: const TextStyle(fontSize: 14),
                            ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lịch sử chẩn đoán',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  tooltip: 'Tải lại lịch sử',
                  onPressed: _historyLoading ? null : _loadHistory,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            DropdownButtonFormField<int?>(
              value: _historyFilterPondId,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Lọc theo ao',
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Tất cả ao'),
                ),
                ..._ponds.map((pond) {
                  final id = _asInt(pond['id']);
                  final name = (pond['name'] ?? 'Ao không tên').toString();
                  if (id == null) return null;
                  return DropdownMenuItem<int?>(
                    value: id,
                    child: Text('$name (#$id)'),
                  );
                }).whereType<DropdownMenuItem<int?>>(),
              ],
              onChanged: (value) {
                setState(() {
                  _historyFilterPondId = value;
                });
                _loadHistory();
              },
            ),
            const SizedBox(height: 12),
            if (_historyLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_historyError != null)
              Text(
                'Lỗi tải lịch sử: $_historyError',
                style: const TextStyle(color: Colors.red),
              )
            else if (_history.isEmpty)
              const Text('Chưa có lịch sử chẩn đoán')
            else
              ..._history.map((item) {
                final pondName = (item['pondName'] ?? '').toString();
                final pondId = _asInt(item['pondId']);
                final label = (item['label'] ?? '-').toString();
                final score = item['score'] is num
                    ? ((item['score'] as num).toDouble() * 100).toStringAsFixed(1)
                    : '-';
                final diagnosedAt = (item['diagnosedAt'] ?? '').toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text('$label ($score%)'),
                    subtitle: Text(
                      'Ao: ${pondId == null ? 'Không chọn ao' : '${pondName.isEmpty ? 'Ao' : pondName} (#$pondId)'}\nThời gian: ${diagnosedAt.isEmpty ? '-' : diagnosedAt}',
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

