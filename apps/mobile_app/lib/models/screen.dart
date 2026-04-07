import 'dart:convert';

class ScreenDevice {
  final String ip;
  final String name;
  final String orientation;
  final String? deviceId;

  final DateTime? lastOpenedAt;
  final DateTime? lastContentSentAt;
  final int? lastContentVersion;
  final String? lastContentName;

  const ScreenDevice({
    required this.ip,
    required this.name,
    this.orientation = 'landscape',
    this.deviceId,
    this.lastOpenedAt,
    this.lastContentSentAt,
    this.lastContentVersion,
    this.lastContentName,
  });

  ScreenDevice copyWith({
    String? ip,
    String? name,
    String? orientation,
    String? deviceId,
    DateTime? lastOpenedAt,
    DateTime? lastContentSentAt,
    int? lastContentVersion,
    String? lastContentName,
    bool clearDeviceId = false,
    bool clearLastOpenedAt = false,
    bool clearLastContentSentAt = false,
    bool clearLastContentVersion = false,
  }) {
    return ScreenDevice(
      ip: ip ?? this.ip,
      name: name ?? this.name,
      orientation: orientation ?? this.orientation,
      deviceId: clearDeviceId ? null : (deviceId ?? this.deviceId),
      lastOpenedAt: clearLastOpenedAt
          ? null
          : (lastOpenedAt ?? this.lastOpenedAt),
      lastContentSentAt: clearLastContentSentAt
          ? null
          : (lastContentSentAt ?? this.lastContentSentAt),
      lastContentVersion: clearLastContentVersion
          ? null
          : (lastContentVersion ?? this.lastContentVersion),
      lastContentName: clearLastContentVersion
          ? null
          : (lastContentName ?? this.lastContentName),
    );
  }

  factory ScreenDevice.fromJson(Map<String, dynamic> json) {
    return ScreenDevice(
      ip: json['ip'] as String? ?? '',
      name: json['name'] as String? ?? '',
      orientation: json['orientation'] as String? ?? 'landscape',
      deviceId: json['deviceId'] as String?,
      lastOpenedAt: DateTime.tryParse(json['lastOpenedAt'] as String? ?? ''),
      lastContentSentAt:
          DateTime.tryParse(json['lastContentSentAt'] as String? ?? ''),
      lastContentVersion: json['lastContentVersion'] as int?,
      lastContentName: json['lastContentName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ip': ip,
      'name': name,
      'orientation': orientation,
      'deviceId': deviceId,
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      'lastContentSentAt': lastContentSentAt?.toIso8601String(),
      'lastContentVersion': lastContentVersion,
      'lastContentName': lastContentName,
    };
  }

  static List<ScreenDevice> decodeList(String jsonString) {
    if (jsonString.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(jsonString);

    if (decoded is! List) {
      return [];
    }

    return decoded
        .map((item) => ScreenDevice.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static String encodeList(List<ScreenDevice> screens) {
    return jsonEncode(screens.map((e) => e.toJson()).toList());
  }
}
