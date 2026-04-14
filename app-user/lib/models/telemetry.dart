/// Model cho dữ liệu telemetry từ backend
/// Hệ thống Smart Aquarium gồm:
/// - Temperature sensor (DS18B20)
/// - pH sensor (analog probe)
/// - 2 Float switches (HIGH/LOW)
/// - Motor control (AUTO/MANUAL)
library;

class AquariumTelemetry {
  final int? pondId;
  final double? temperature;
  final double? ph;
  final int? waterLevelPercentRaw;
  final bool? floatHigh;
  final bool? floatLow;
  final bool? motorRunning;
  final int? duty;
  final double? anomalyScore;
  final bool? anomalyFlag;
  final String? source;
  final String? mode;
  final String? timestamp;

  AquariumTelemetry({
    this.pondId,
    this.temperature,
    this.ph,
    this.waterLevelPercentRaw,
    this.floatHigh,
    this.floatLow,
    this.motorRunning,
    this.duty,
    this.anomalyScore,
    this.anomalyFlag,
    this.source,
    this.mode,
    this.timestamp,
  });

  factory AquariumTelemetry.fromJson(Map<String, dynamic> json) {
    bool? parseBool(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      final s = v.toString().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
      return null;
    }

    return AquariumTelemetry(
      pondId: json['pondId'] is num ? (json['pondId'] as num).toInt() : null,
      temperature: json['temperature']?.toDouble(),
      ph: json['ph']?.toDouble(),
      waterLevelPercentRaw: json['waterLevelPercent'] is num
          ? (json['waterLevelPercent'] as num).toInt()
          : null,
      floatHigh: parseBool(json['floatHigh']),
      floatLow: parseBool(json['floatLow']),
      motorRunning: parseBool(json['motorRunning']),
      duty: json['duty'] is num ? (json['duty'] as num).toInt() : null,
      anomalyScore: json['anomalyScore']?.toDouble(),
      anomalyFlag: parseBool(json['anomalyFlag']),
      source: json['source']?.toString(),
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
    if (waterLevelPercentRaw != null) {
      return waterLevelPercentRaw!.clamp(0, 100);
    }
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
