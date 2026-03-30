import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'config.dart';
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
  /// Lấy dữ liệu telemetry mới nhất từ backend
  static Future<AquariumTelemetry> fetchLatestTelemetry() async {
    final response = await http.get(
      Uri.parse("${Config.baseUrl}/control/status/latest"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return AquariumTelemetry.fromJson(data);
    } else {
      throw Exception("Không thể tải dữ liệu telemetry");
    }
  }

  /// Đổi mode AUTO <-> MANUAL
  static Future<void> setMode(String mode) async {
    final response = await http.post(
      Uri.parse("${Config.baseUrl}/control/mode?mode=$mode"),
    );

    if (response.statusCode != 200) {
      throw Exception("Không thể đổi mode");
    }
  }

  /// Điều khiển motor thủ công (FORWARD, BACKWARD, STOP)
  static Future<void> controlMotor(String command) async {
    final response = await http.post(
      Uri.parse("${Config.baseUrl}/control/motor?cmd=$command"),
    );

    if (response.statusCode != 200) {
      throw Exception("Không thể điều khiển motor");
    }
  }

  /// Lấy danh sách telemetry gần đây (cho biểu đồ)
  static Future<List<AquariumTelemetry>> fetchRecentTelemetry() async {
    final response = await http.get(
      Uri.parse("${Config.baseUrl}/telemetry/recent"),
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
    return jsonDecode(response.body) as Map<String, dynamic>;
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
    final uri = Uri.parse("${Config.baseUrl}/ai/fish-disease").replace(
      queryParameters: pondId == null
          ? null
          : {
              'pondId': pondId.toString(),
            },
    );

    final request = http.MultipartRequest("POST", uri);
    final filePath = imageFile.path;
    final fileName = filePath.split(RegExp(r"[\\/]")).last;
    final bytes = await imageFile.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception("File ảnh không hợp lệ");
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        "file",
        bytes,
        filename: fileName.isNotEmpty ? fileName : "image",
      ),
    );

    // Nếu backend yêu cầu BasicAuth ở môi trường của bạn thì headers này sẽ giúp.
    request.headers.addAll(_authHeaders());

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception("Không thể phân loại bệnh cá: ${response.statusCode} ${response.body}");
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

  /// Gán ao cho user hiện tại bằng ID (bind-by-id).
  static Future<Map<String, dynamic>> bindPondById(int pondId) async {
    final response = await http.post(
      Uri.parse("${Config.baseUrl}/ponds/bind-by-id"),
      headers: _authHeaders(extra: {"Content-Type": "application/json"}),
      body: jsonEncode({"pondId": pondId}),
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
    return jsonDecode(response.body) as Map<String, dynamic>;
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
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
