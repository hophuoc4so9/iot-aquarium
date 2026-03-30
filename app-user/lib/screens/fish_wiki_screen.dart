import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FishSpeciesUiModel {
  final int id;
  final String title;
  final String subtitle;
  final String environment; // Ví dụ: "Nước ngọt", "Nước lợ"
  final String temperatureRange;
  final String phRange;
  final String density;
  final String notes;

  const FishSpeciesUiModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.environment,
    required this.temperatureRange,
    required this.phRange,
    required this.density,
    required this.notes,
  });
}

/// Trang wiki loài cá: giao diện dạng thẻ, có ô tìm kiếm và filter.
class FishWikiScreen extends StatefulWidget {
  const FishWikiScreen({super.key});

  @override
  State<FishWikiScreen> createState() => _FishWikiScreenState();
}

class _FishWikiScreenState extends State<FishWikiScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedEnvFilter = 'Tất cả';
  bool _isLoading = false;
  String? _error;
  List<FishSpeciesUiModel> _allSpecies = [];

  @override
  void initState() {
    super.initState();
    _loadFishFromBackend();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFishFromBackend() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.fetchConfiguredFish(page: 0, size: 50);
      final List<dynamic> content = data['content'] ?? [];
      final items = content.map((raw) {
        final m = raw as Map<String, dynamic>;
        final id = (m['id'] as num).toInt();
        final nameVi = (m['nameVietnamese'] as String?) ?? '';
        final nameEn = (m['nameEnglish'] as String?) ?? '';
        final title = nameVi.isNotEmpty ? nameVi : nameEn;
        final subtitle = nameVi.isNotEmpty ? nameEn : nameVi;

        String env = 'Khác';
        final fw = m['vnFreshwater'] as bool?;
        final br = m['vnBrackish'] as bool?;
        if (fw == true && br == true) {
          env = 'Nước ngọt / lợ';
        } else if (fw == true) {
          env = 'Nước ngọt';
        } else if (br == true) {
          env = 'Nước lợ';
        }

        final tempRange = (m['tempRange'] as String?) ??
            _buildRangeFrom(
              m['autoTempMin'] as num?,
              m['autoTempMax'] as num?,
              unit: '°C',
            );
        final phRange = (m['phRange'] as String?) ??
            _buildRangeFrom(
              m['autoPhMin'] as num?,
              m['autoPhMax'] as num?,
              unit: '',
            );

        final density = (m['vnAbundance'] as String?) ??
            'Tham khảo thêm trong tài liệu kỹ thuật địa phương.';

        final notes = (m['remarksVi'] as String?)?.trim().isNotEmpty == true
            ? (m['remarksVi'] as String)
            : ((m['remarksEn'] as String?) ??
                'Dữ liệu mô tả chi tiết sẽ được bổ sung sau.');

        return FishSpeciesUiModel(
          id: id,
          title: title,
          subtitle: subtitle,
          environment: env,
          temperatureRange: tempRange,
          phRange: phRange,
          density: density,
          notes: notes,
        );
      }).toList();

      setState(() {
        _allSpecies = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _buildRangeFrom(num? min, num? max, {required String unit}) {
    if (min == null && max == null) return 'Chưa có dữ liệu';
    final String u = unit.isEmpty ? '' : unit;
    if (min != null && max != null) {
      return '${min.toStringAsFixed(1)}–${max.toStringAsFixed(1)}$u';
    }
    if (min != null) {
      return '>= ${min.toStringAsFixed(1)}$u';
    }
    return '<= ${max!.toStringAsFixed(1)}$u';
  }

  List<FishSpeciesUiModel> get _filteredSpecies {
    final query = _searchController.text.toLowerCase().trim();

    return _allSpecies.where((s) {
      final matchEnv =
          _selectedEnvFilter == 'Tất cả' || s.environment == _selectedEnvFilter;
      final textCombined =
          '${s.title} ${s.subtitle} ${s.environment}'.toLowerCase();
      final matchText = query.isEmpty || textCombined.contains(query);
      return matchEnv && matchText;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final species = _filteredSpecies;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wiki loài cá'),
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
            onPressed: _isLoading ? null : _loadFishFromBackend,
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
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'Lỗi tải dữ liệu wiki cá:\n$_error',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadFishFromBackend,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm theo tên cá (VI/EN)...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Tất cả'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Nước ngọt'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Nước lợ'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Khác'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _isLoading && species.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : species.isEmpty
                            ? const Center(
                                child: Text(
                                  'Không tìm thấy loài nào phù hợp.\nHãy thử từ khoá hoặc filter khác.',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.78,
                                ),
                                itemCount: species.length,
                                itemBuilder: (context, index) {
                                  final s = species[index];
                                  return _buildSpeciesCard(context, s);
                                },
                              ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label) {
    final bool selected = _selectedEnvFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _selectedEnvFilter = label;
        });
      },
      selectedColor: Colors.blue.shade50,
      labelStyle: TextStyle(
        color: selected ? Colors.blue : Colors.grey.shade800,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildSpeciesCard(BuildContext context, FishSpeciesUiModel s) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              s.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              s.environment,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.subtitle.isEmpty ? '' : s.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: Icons.thermostat,
                        title: 'Nhiệt độ thích hợp',
                        value: s.temperatureRange,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        icon: Icons.water_drop,
                        title: 'Khoảng pH',
                        value: s.phRange,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        icon: Icons.bubble_chart,
                        title: 'Mật độ thả nuôi tham khảo',
                        value: s.density,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Ghi chú nuôi quản lý',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.notes,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Thông tin tham khảo, cần điều chỉnh tuỳ điều kiện thực tế và khuyến cáo kỹ thuật địa phương.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade400,
                    Colors.teal.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.set_meal_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (s.subtitle.isNotEmpty)
                      Text(
                        s.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.water,
                              size: 14,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              s.environment,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Chi tiết',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

