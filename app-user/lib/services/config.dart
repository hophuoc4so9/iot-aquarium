import 'package:flutter/foundation.dart';

class Config {
  // Priority 1: explicit override from build/run command.
  // Example: flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080/api
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }

    // Web runs in browser on host machine, localhost is usually correct.
    if (kIsWeb) {
      return 'http://localhost:8080/api';
    }

    // Android emulator cannot reach host via localhost.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api';
    }

    // iOS simulator / desktop default.
    return 'http://localhost:8080/api';
  }
}
