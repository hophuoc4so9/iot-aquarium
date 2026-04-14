import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'config.dart';
import 'alert_history_store.dart';
import '../models/telemetry.dart';

/// API Service cho Smart Aquarium
/// Giao tiếp với backend Spring Boot qua REST API

class ApiService {
  static String? _basicUsername;
  static String? _basicPassword;

  static void setBasicAuth(String username, String password) {
    _basicUsername = username;
    _basicPassword = password;
  }

  static void clearAuth() {
    _basicUsername = null;
    _basicPassword = null;
  }

  static Map<String, String> _authHeaders({Map<String, String>? extra}) {
    final headers = <String, String>{};
    if (_basicUsername != null && _basicPassword != null) {
      final cred = '$_basicUsername:$_basicPassword';
      final encoded = base64Encode(utf8.encode(cred));
      headers['Authorization'] = 'Basic $encoded';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  static String _withPondId(String path, int? pondId) {
    if (pondId == null) {
      return path;
    }
    final separator = path.contains('?') ? '&' : '?';
    return '$path${separator}pondId=$pondId';
  }

  static String _extractErrorMessage(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['detail'] ?? decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {
      // Keep fallback if body is not JSON.
    }
    return '$fallback (${response.statusCode})';
  }

  /// Lấy dữ liệu telemetry mới nhất từ backend
  static Future<AquariumTelemetry> fetchLatestTelemetry({int? pondId}) async {
    final response = await http.get(
      Uri.parse("${Config.baseUrl}" + _withPondId("/control/status/latest", pondId)),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return AquariumTelemetry.fromJson(data);
    } else {
      throw Exception("Không thể tải dữ liệu telemetry");
    }
  }

  /// Đổi mode AUTO <-> MANUAL
  static Future<void> setMode(String mode, {int? pondId}) async {
    final response = await http.post(
      Uri.parse("${Config.baseUrl}" + _withPondId("/control/mode?mode=$mode", pondId)),
    );

    if (response.statusCode != 200) {
      throw Exception("Không thể đổi mode");
    }
  }

  /// Điều khiển motor thủ công (FORWARD, BACKWARD, STOP)
  static Future<void> controlMotor(String command, {int? pondId}) async {
    final response = await http.post(
      Uri.parse("${Config.baseUrl}" + _withPondId("/control/motor?cmd=$command", pondId)),
    );

    if (response.statusCode != 200) {
      throw Exception("Không thể điều khiển motor");
    }
  }

  /// Lấy danh sách telemetry gần đây (cho biểu đồ)
  static Future<List<AquariumTelemetry>> fetchRecentTelemetry({int? pondId}) async {
    final response = await http.get(
      Uri.parse("${Config.baseUrl}" + _withPondId("/telemetry/recent", pondId)),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => AquariumTelemetry.fromJson(json)).toList();
    } else {
      throw Exception("Không thể tải lịch sử telemetry");
    }
  }

  // --- Chatbot tư vấn (Gemini) ---

  /// Gửi tin nhắn, nhận reply từ AI. Lịch sử lưu ở backend.
  static Future<String> sendChatMessage(
    String sessionId,
    String message, [
    String clientId = "app-user",
  ]) async {
    final response = await http.post(
      Uri.parse("${Config.baseUrl}/chat"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "sessionId": sessionId,
        "message": message,
        "clientId": clientId,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data["reply"] as String? ?? "";
    } else {
      throw Exception("Gửi tin nhắn thất bại: ${response.statusCode}");
    }
  }

  /// Lấy lịch sử chat của phiên (để hiển thị lại khi mở màn hình).
  static Future<List<Map<String, dynamic>>> getChatHistory(String sessionId) async {
    final response = await http.get(
      Uri.parse("${Config.baseUrl}/chat/history?sessionId=$sessionId"),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Lấy cảnh báo AI cho 1 ao nuôi (gọi qua backend Java, backend sẽ gọi AI service).
  static Future<Map<String, dynamic>> fetchAiAlertsForPond(int pondId) async {
    final response = await http.get(
      Uri.parse("${Config.baseUrl}/ai/ponds/$pondId/alerts"),
    );
    if (response.statusCode != 200) {
      throw Exception("Không thể tải cảnh báo AI: ${response.statusCode}");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['fallback'] != true) {
      final alerts = (data['alerts'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((item) => (item['level'] ?? 'OK').toString() != 'OK')
          .map((item) => <String, dynamic>{
                'pondId': pondId,
                'pondName': data['pondName']?.toString() ?? 'Ao #$pondId',
                'source': 'AI',
                'title': item['metric']?.toString() ?? 'AI alert',
                'message': item['message']?.toString() ?? '',
                'level': item['level']?.toString() ?? 'WARNING',
                'createdAt': data['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
                'dedupeKey': '$pondId|AI|${item['metric'] ?? ''}|${item['level'] ?? ''}|${item['message'] ?? ''}',
              })
          .where((item) => (item['message'] as String).trim().isNotEmpty)
          .toList();

      if (alerts.isNotEmpty) {
        await AlertHistoryStore.recordEvents(alerts);
      }
    }

    return data;
  }

  // --- Dự đoán bệnh cá (AI) ---

  /// Gửi ảnh cá để AI phân loại bệnh.
  /// POST `${Config.baseUrl}/ai/fish-disease`
  /// multipart form-data field: `file`
  /// `pondId` là tuỳ chọn, không bắt buộc.
  static Future<Map<String, dynamic>> classifyFishDisease({
    int? pondId,
    required XFile imageFile,
  }) async {
    final hasAuth = _basicUsername != null && _basicPassword != null;
    final effectivePondId = hasAuth ? pondId : null;

    final uri = Uri.parse("${Config.baseUrl}/ai/fish-disease").replace(
      queryParameters: effectivePondId == null
          ? null
          : {
              'pondId': effectivePondId.toString(),
            },
    );

    final request = http.MultipartRequest("POST", uri);
    final filePath = imageFile.path;
    final byPathName = filePath.split(RegExp(r"[\\/]")).last;
    final fileName = (imageFile.name.isNotEmpty ? imageFile.name : byPathName).trim();
    final bytes = await imageFile.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception("File ảnh không hợp lệ");
    }

    String ext = '';
    final dot = fileName.lastIndexOf('.');
    if (dot >= 0 && dot < fileName.length - 1) {
      ext = fileName.substring(dot + 1).toLowerCase();
    }

    MediaType mediaType;
    if (ext == 'png') {
      mediaType = MediaType('image', 'png');
    } else if (ext == 'webp') {
      mediaType = MediaType('image', 'webp');
    } else {
      mediaType = MediaType('image', 'jpeg');
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        "file",
        bytes,
        filename: fileName.isNotEmpty ? fileName : "image",
        contentType: mediaType,
      ),
    );

    // Nếu backend yêu cầu BasicAuth ở môi trường của bạn thì headers này sẽ giúp.
    request.headers.addAll(_authHeaders());

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      throw Exception("Bạn cần đăng nhập để chẩn đoán theo ao");
    }

    throw Exception(
      _extractErrorMessage(response, "Không thể phân loại bệnh cá"),
    );
  }

  /// Lấy lịch sử chẩn đoán bệnh cá của user hiện tại.
  /// Có thể lọc theo ao bằng `pondId`.
  static Future<List<Map<String, dynamic>>> fetchFishDiseaseHistory({
    int? pondId,
  }) async {
    final uri = Uri.parse("${Config.baseUrl}/ai/fish-disease/history").replace(
      queryParameters: pondId == null
          ? null
          : {
              'pondId': pondId.toString(),
            },
    );

    final response = await http.get(
      uri,
      headers: _authHeaders(),
    );

    if (response.statusCode == 401) {
      throw Exception("Bạn cần đăng nhập để xem lịch sử chẩn đoán");
    }
    if (response.statusCode != 200) {
      throw Exception("Không thể tải lịch sử chẩn đoán: ${response.statusCode}");
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // --- Đồng bộ danh sách ao với backend ---

  /// Lấy danh sách ao thuộc user hiện tại.
  /// GET /api/ponds/my
  static Future<List<Map<String, dynamic>>> fetchPonds() async {
    final response = await http.get(
      Uri.parse("${Config.baseUrl}/ponds/my"),
      headers: _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception("Không thể tải danh sách ao: ${response.statusCode}");
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Lấy danh sách ao kèm snapshot trạng thái mới nhất.
  /// GET /api/ponds/my/snapshots
  static Future<List<Map<String, dynamic>>> fetchPondSnapshots() async {
    final response = await http.get(
      Uri.parse("${Config.baseUrl}/ponds/my/snapshots"),
      headers: _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception("Không thể tải snapshot ao: ${response.statusCode}");
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Gán thiết bị/ao cho user hiện tại bằng deviceId số.
  static Future<Map<String, dynamic>> bindDeviceById(int deviceId) async {
    final response = await http.post(
      Uri.parse("${Config.baseUrl}/ponds/bind-by-id"),
      headers: _authHeaders(extra: {"Content-Type": "application/json"}),
      body: jsonEncode({"deviceId": deviceId}),
    );
    if (response.statusCode == 403) {
      throw Exception("Ao này đã được gán cho người dùng khác");
    }
    if (response.statusCode == 404) {
      throw Exception("Không tìm thấy ao với ID tương ứng");
    }
    if (response.statusCode != 200) {
      throw Exception("Không thể gán ao: ${response.statusCode}");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Backward-compatible wrapper.
  static Future<Map<String, dynamic>> bindPondById(int pondId) {
    return bindDeviceById(pondId);
  }

  /// Cập nhật thông tin ao (tên, loại cá, ...).
  /// PUT /api/ponds/{id}
  static Future<Map<String, dynamic>> updatePond(
    int pondId, {
    String? name,
    String? fishType,
    String? area,
    double? customTempMin,
    double? customTempMax,
    double? customPhMin,
    double? customPhMax,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (fishType != null) body['fishType'] = fishType;
    if (area != null) body['area'] = area;
    if (customTempMin != null) body['customTempMin'] = customTempMin;
    if (customTempMax != null) body['customTempMax'] = customTempMax;
    if (customPhMin != null) body['customPhMin'] = customPhMin;
    if (customPhMax != null) body['customPhMax'] = customPhMax;

    final response = await http.put(
      Uri.parse("${Config.baseUrl}/ponds/$pondId"),
      headers: _authHeaders(extra: {"Content-Type": "application/json"}),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception("Không thể cập nhật ao: ${response.statusCode}");
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Cập nhật ngưỡng riêng cho từng bể.
  /// PUT /api/ponds/{id}/thresholds
  static Future<Map<String, dynamic>> updatePondThresholds(
    int pondId, {
    required double tempMin,
    required double tempMax,
    required double phMin,
    required double phMax,
  }) async {
    final response = await http.put(
      Uri.parse("${Config.baseUrl}/ponds/$pondId/thresholds"),
      headers: _authHeaders(extra: {"Content-Type": "application/json"}),
      body: jsonEncode({
        "tempMin": tempMin,
        "tempMax": tempMax,
        "phMin": phMin,
        "phMax": phMax,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Không thể cập nhật ngưỡng bể: ${response.statusCode}");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Reset ngưỡng riêng của bể về null (fallback loài/hệ thống).
  /// POST /api/ponds/{id}/thresholds/reset
  static Future<Map<String, dynamic>> resetPondThresholds(int pondId) async {
    final response = await http.post(
      Uri.parse("${Config.baseUrl}/ponds/$pondId/thresholds/reset"),
      headers: _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception("Không thể reset ngưỡng bể: ${response.statusCode}");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // --- Wiki cá: đồng bộ với FishSpeciesController ---

  /// Lấy danh sách loài cá đã cấu hình ngưỡng (dùng cho Wiki).
  /// GET /api/fish/configured?page=0&size=50&name=<query?>
  static Future<Map<String, dynamic>> fetchConfiguredFish({
    int page = 0,
    int size = 50,
    String? name,
  }) async {
    final query = name == null || name.trim().isEmpty
        ? ''
        : '&name=${Uri.encodeQueryComponent(name.trim())}';
    final response = await http.get(
      Uri.parse("${Config.baseUrl}/fish/configured?page=$page&size=$size$query"),
    );
    if (response.statusCode != 200) {
      throw Exception("Không thể tải danh sách loài cá: ${response.statusCode}");
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is List<dynamic>) {
      return <String, dynamic>{'content': decoded};
    }
    return const <String, dynamic>{'content': []};
  }

  /// Tìm kiếm loài cá theo tên (EN/VN).
  /// GET /api/fish/search?name=...
  static Future<List<Map<String, dynamic>>> searchFishByName(String? name) async {
    final query = name == null || name.trim().isEmpty
        ? ''
        : '?name=${Uri.encodeQueryComponent(name.trim())}';
    final response = await http.get(
      Uri.parse("${Config.baseUrl}/fish/search$query"),
    );
    if (response.statusCode != 200) {
      throw Exception("Không thể tìm kiếm loài cá: ${response.statusCode}");
    }
    final decoded = jsonDecode(response.body);
    final List<dynamic> data = decoded is List<dynamic>
        ? decoded
        : decoded is Map<String, dynamic> && decoded['content'] is List<dynamic>
            ? (decoded['content'] as List<dynamic>)
            : const [];
    final results = <Map<String, dynamic>>[];
    for (final e in data) {
      if (e is Map) {
        results.add(Map<String, dynamic>.from(e));
      }
    }
    return results;
  }

  /// Lấy chi tiết 1 loài cá (gồm cả ngưỡng hiệu lực).
  /// GET /api/fish/{id}
  static Future<Map<String, dynamic>> fetchFishDetail(int id) async {
    final response = await http.get(
      Uri.parse("${Config.baseUrl}/fish/$id"),
    );
    if (response.statusCode != 200) {
      throw Exception("Không thể tải chi tiết loài cá: ${response.statusCode}");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Cập nhật ngưỡng cảnh báo cho 1 loài cá.
  /// PUT /api/fish/{id}/thresholds
  static Future<Map<String, dynamic>> updateFishThresholds(
    int id, {
    required double tempMin,
    required double tempMax,
    required double phMin,
    required double phMax,
  }) async {
    final response = await http.put(
      Uri.parse("${Config.baseUrl}/fish/$id/thresholds"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "tempMin": tempMin,
        "tempMax": tempMax,
        "phMin": phMin,
        "phMax": phMax,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Không thể cập nhật ngưỡng: ${response.statusCode}");
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return const <String, dynamic>{};
  }

  /// Reset ngưỡng cảnh báo của loài cá về mặc định.
  /// POST /api/fish/{id}/reset
  static Future<Map<String, dynamic>> resetFishThresholds(int id) async {
    final response = await http.post(Uri.parse("${Config.baseUrl}/fish/$id/reset"));
    if (response.statusCode != 200) {
      throw Exception("Không thể reset ngưỡng: ${response.statusCode}");
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return const <String, dynamic>{};
  }

  /// Lấy ngưỡng mặc định hệ thống.
  /// GET /api/fish/defaults
  static Future<Map<String, dynamic>> fetchFishDefaultThresholds() async {
    final response = await http.get(Uri.parse("${Config.baseUrl}/fish/defaults"));
    if (response.statusCode != 200) {
      throw Exception("Không thể tải ngưỡng mặc định: ${response.statusCode}");
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return const <String, dynamic>{};
  }

  // --- Auth cho app-user ---

  /// Lấy thông tin user hiện tại (dùng HTTP Basic).
  static Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await http.get(
      Uri.parse("${Config.baseUrl}/auth/me"),
      headers: _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception("Không thể lấy thông tin user: ${response.statusCode}");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Đăng ký user mới.
  static Future<void> registerUser(
    String username,
    String password,
    String fullName,
  ) async {
    final response = await http.post(
      Uri.parse("${Config.baseUrl}/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username,
        "password": password,
        "fullName": fullName,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception("Đăng ký thất bại: ${response.statusCode} ${response.body}");
    }
  }
}
