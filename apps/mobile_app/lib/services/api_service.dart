import 'dart:convert';
import 'package:http/http.dart' as http;

class ScreenStatus {
  final bool isOnline;
  final bool isPaired;
  final int? contentVersion;

  ScreenStatus({
    required this.isOnline,
    required this.isPaired,
    this.contentVersion,
  });
}

class PairingInfoResult {
  final bool success;
  final String? deviceId;
  final String? screenName;
  final String? orientation;
  final String? ip;
  final bool? paired;

  const PairingInfoResult({
    required this.success,
    this.deviceId,
    this.screenName,
    this.orientation,
    this.ip,
    this.paired,
  });
}

class ApiResult {
  final bool success;
  final String? error;

  const ApiResult({
    required this.success,
    this.error,
  });
}

class ApiService {
  final String baseUrl;

  ApiService(this.baseUrl);

  Future<bool> pairDevice({
    required String pairingCode,
    required String screenName,
    String orientation = 'landscape',
  }) async {
    final url = Uri.parse('$baseUrl/pair');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'pairingCode': pairingCode,
              'screenName': screenName,
              'orientation': orientation,
            }),
          )
          .timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<PairingInfoResult> getPairingInfo({
    Duration timeout = const Duration(milliseconds: 450),
  }) async {
    final url = Uri.parse('$baseUrl/pairing-info');

    try {
      final response = await http.get(url).timeout(timeout);

      if (response.statusCode != 200) {
        return const PairingInfoResult(success: false);
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return const PairingInfoResult(success: false);
      }

      return PairingInfoResult(
        success: decoded['success'] == true,
        deviceId: decoded['deviceId']?.toString(),
        screenName: decoded['screenName']?.toString(),
        orientation: decoded['orientation']?.toString(),
        ip: decoded['ip']?.toString(),
        paired: decoded['paired'] as bool?,
      );
    } catch (_) {
      return const PairingInfoResult(success: false);
    }
  }


  Future<ApiResult> setScreenName(String screenName) async {
    final url = Uri.parse('$baseUrl/set-name');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'screenName': screenName,
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        return const ApiResult(success: true);
      }

      String error = 'Serverfehler (${response.statusCode})';

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> &&
            decoded['error'] is String &&
            (decoded['error'] as String).trim().isNotEmpty) {
          error = decoded['error'] as String;
        }
      } catch (_) {}

      return ApiResult(success: false, error: error);
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return const ApiResult(
          success: false,
          error: 'Timeout – Screen antwortet nicht',
        );
      }

      return const ApiResult(
        success: false,
        error: 'Keine Verbindung zum Screen',
      );
    }
  }

  Future<ApiResult> sendContent(Map<String, dynamic> payload) async {
    final url = Uri.parse('$baseUrl/content');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        return const ApiResult(success: true);
      }

      String error = 'Serverfehler (${response.statusCode})';

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> &&
            decoded['error'] is String &&
            (decoded['error'] as String).trim().isNotEmpty) {
          error = decoded['error'] as String;
        }
      } catch (_) {}

      return ApiResult(
        success: false,
        error: error,
      );
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return const ApiResult(
          success: false,
          error: 'Timeout – Screen antwortet nicht',
        );
      }

      return const ApiResult(
        success: false,
        error: 'Keine Verbindung zum Screen',
      );
    }
  }

  Future<bool> unpairDevice() async {
    final url = Uri.parse('$baseUrl/unpair');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<ScreenStatus> getStatus() async {
    final url = Uri.parse('$baseUrl/status');

    try {
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 2));

      if (response.statusCode != 200) {
        return ScreenStatus(isOnline: false, isPaired: false);
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return ScreenStatus(isOnline: false, isPaired: false);
      }

      final isPaired = decoded['paired'] == true;
      final statusValue = decoded['status']?.toString();

      return ScreenStatus(
        isOnline: decoded['success'] == true &&
            statusValue == 'ok' &&
            isPaired,
        isPaired: isPaired,
        contentVersion: decoded['contentVersion'] as int?,
      );
    } catch (_) {
      return ScreenStatus(isOnline: false, isPaired: false);
    }
  }
}
