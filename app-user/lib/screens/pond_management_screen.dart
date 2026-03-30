import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

class PondInfo {
  final int id;
  final String name;
  final String? fishType;
  final String? area;

  PondInfo({
    required this.id,
    required this.name,
    this.fishType,
    this.area,
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
  final List<PondInfo> _ponds = [];
  int? _selectedIndex;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPondsFromBackend();
  }

  Future<void> _loadPondsFromBackend() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await ApiService.fetchPonds();
      final ponds = list.map((e) {
        return PondInfo(
          id: (e['id'] as num).toInt(),
          name: (e['name'] as String?) ?? 'Ao #${e['id']}',
          fishType: e['fishType'] as String?,
          area: e['area'] as String?,
        );
      }).toList();

      setState(() {
        _ponds
          ..clear()
          ..addAll(ponds);
        if (_ponds.isNotEmpty) {
          _selectedIndex = 0;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
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
                    'Thêm ao bằng mã code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nhập mã code/id ao được cấp từ hệ thống web-admin.\n'
                    'Hiện tại thao tác này chỉ lưu cục bộ, chưa gửi lên backend.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: 'Mã code / ID ao',
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
                              errorText = 'Vui lòng nhập ID ao (số)';
                            });
                            return;
                          }

                          final id = int.tryParse(code);
                          if (id == null) {
                            setModalState(() {
                              errorText = 'ID ao phải là số';
                            });
                            return;
                          }

                          try {
                            await ApiService.bindPondById(id);
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

  @override
  Widget build(BuildContext context) {
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
            tooltip: 'Thêm ao bằng mã code',
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
                  height: 130,
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
                                  horizontal: 16, vertical: 12),
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                final pond = _ponds[index];
                                final bool isSelected = index == _selectedIndex;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedIndex = index;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 200,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue.shade50
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue
                                            : Colors.grey.shade300,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Colors.black.withOpacity(0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
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
                                                  fontSize: 14,
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
                                              fontSize: 12,
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
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        const Spacer(),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: const [
                                                Icon(
                                                  Icons.water_rounded,
                                                  size: 16,
                                                  color: Colors.teal,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Đang theo dõi',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.teal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '#${pond.id}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    Colors.grey.shade600,
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
                    label: const Text('Thêm ao mới bằng mã code'),
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
                      'Đang xem dashboard cho: ${selectedPond.name} (#${selectedPond.id})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: DashboardScreen(
                        pondId: selectedPond.id,
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

