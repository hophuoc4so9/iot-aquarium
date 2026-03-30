/// Model cho dữ liệu telemetry từ backend
/// Hệ thống Smart Aquarium gồm:
/// - Temperature sensor (DS18B20)
/// - pH sensor (analog probe)
/// - 2 Float switches (HIGH/LOW)
/// - Motor control (AUTO/MANUAL)
library;

class AquariumTelemetry {
  final double? temperature;
  final double? ph;
  final bool? floatHigh;
  final bool? floatLow;
  final bool? motorRunning;
  final int? duty;
  final String? mode;
  final String? timestamp;

  AquariumTelemetry({
    this.temperature,
    this.ph,
    this.floatHigh,
    this.floatLow,
    this.motorRunning,
    this.duty,
    this.mode,
    this.timestamp,
  });

  factory AquariumTelemetry.fromJson(Map<String, dynamic> json) {
    return AquariumTelemetry(
      temperature: json['temperature']?.toDouble(),
      ph: json['ph']?.toDouble(),
      floatHigh: json['floatHigh'],
      floatLow: json['floatLow'],
      motorRunning: json['motorRunning'],
      duty: json['duty'],
      mode: json['mode'],
      timestamp: json['timestamp'],
    );
  }

  // Tính toán mức nước dựa trên float switches
  // Logic: floatXXX = true nghĩa là phao đã nổi (có nước ở mức đó)
  // floatHigh=true AND floatLow=true  -> Tank FULL (95%)
  // floatHigh=false AND floatLow=true -> Normal (50%)
  // floatHigh=true AND floatLow=false -> IMPOSSIBLE STATE (20%)
  // floatHigh=false AND floatLow=false -> LOW (15%)
  int get waterLevelPercent {
    if (floatHigh == true && floatLow == true) {
      return 95; // Cả 2 phao nổi - bể đầy
    }
    if (floatHigh == false && floatLow == true) {
      return 50; // Chỉ phao thấp nổi - bình thường
    }
    if (floatHigh == true && floatLow == false) {
      return 20; // IMPOSSIBLE - lỗi phần cứng
    }
    return 15; // Cả 2 phao chìm - nước rất thấp
  }

  String get waterLevelStatus {
    if (floatHigh == true && floatLow == true) return "HIGH - Tank full";
    if (floatHigh == false && floatLow == true) return "NORMAL";
    if (floatHigh == true && floatLow == false) return "ERROR - Check hardware";
    return "CRITICAL - Below minimum";
  }
}
