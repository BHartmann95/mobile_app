import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/saved_content.dart';
import '../models/template.dart';

class ScreenStatus {
  final bool isOnline;
  final bool isPaired;
  final bool isReachable;
  final int? contentVersion;

  const ScreenStatus({
    required this.isOnline,
    required this.isPaired,
    required this.isReachable,
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

class ScreenContentResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? rawContent;
  final SavedContent? savedContent;
  final int? contentVersion;
  final String? screenName;
  final String? orientation;

  const ScreenContentResult({
    required this.success,
    this.error,
    this.rawContent,
    this.savedContent,
    this.contentVersion,
    this.screenName,
    this.orientation,
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

  Future<ScreenContentResult> getCurrentContent({
    Duration timeout = const Duration(seconds: 3),
    String? fallbackName,
    String fallbackOrientation = 'landscape',
    String? stableContentId,
  }) async {
    final url = Uri.parse('$baseUrl/content');

    try {
      final response = await http.get(url).timeout(timeout);

      if (response.statusCode != 200) {
        String error = 'Serverfehler (${response.statusCode})';

        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> &&
              decoded['error'] is String &&
              (decoded['error'] as String).trim().isNotEmpty) {
            error = decoded['error'] as String;
          }
        } catch (_) {}

        return ScreenContentResult(success: false, error: error);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const ScreenContentResult(
          success: false,
          error: 'Ungültige Serverantwort',
        );
      }

      if (decoded['success'] != true) {
        return ScreenContentResult(
          success: false,
          error: decoded['error']?.toString() ?? 'Content konnte nicht geladen werden',
        );
      }

      final rawContent = decoded['content'];
      if (rawContent is! Map<String, dynamic>) {
        return const ScreenContentResult(
          success: false,
          error: 'Kein gültiger Content am Screen vorhanden',
        );
      }

      final screenName = (decoded['screenName']?.toString().trim().isNotEmpty ?? false)
          ? decoded['screenName']!.toString().trim()
          : (fallbackName?.trim().isNotEmpty ?? false)
              ? fallbackName!.trim()
              : 'Screen-Inhalt';

      final orientation = _normalizeOrientation(
        decoded['orientation']?.toString(),
        fallbackOrientation,
      );

      final savedContent = _mapScreenPayloadToSavedContent(
        rawContent,
        screenName: screenName,
        orientation: orientation,
        stableContentId: stableContentId,
      );

      return ScreenContentResult(
        success: true,
        rawContent: rawContent,
        savedContent: savedContent,
        contentVersion: _parseInt(decoded['contentVersion']),
        screenName: screenName,
        orientation: orientation,
      );
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return const ScreenContentResult(
          success: false,
          error: 'Timeout – Screen antwortet nicht',
        );
      }

      return const ScreenContentResult(
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

  Future<ScreenStatus> getStatus({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final url = Uri.parse('$baseUrl/status');

    try {
      final response = await http.get(url).timeout(timeout);

      if (response.statusCode != 200) {
        return const ScreenStatus(
          isOnline: false,
          isPaired: false,
          isReachable: false,
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return const ScreenStatus(
          isOnline: false,
          isPaired: false,
          isReachable: false,
        );
      }

      final success = decoded['success'] == true;
      final isPaired = decoded['paired'] == true;
      final statusValue = decoded['status']?.toString();

      return ScreenStatus(
        isOnline: success && statusValue == 'ok' && isPaired,
        isPaired: isPaired,
        isReachable: success,
        contentVersion: decoded['contentVersion'] as int?,
      );
    } catch (_) {
      return const ScreenStatus(
        isOnline: false,
        isPaired: false,
        isReachable: false,
      );
    }
  }

  SavedContent _mapScreenPayloadToSavedContent(
    Map<String, dynamic> payload, {
    required String screenName,
    required String orientation,
    String? stableContentId,
  }) {
    final rawSlides = (payload['slides'] as List?) ?? const [];
    final slides = <SavedSlide>[];

    for (var i = 0; i < rawSlides.length; i++) {
      final rawSlide = rawSlides[i];
      if (rawSlide is! Map) {
        continue;
      }

      final slideMap = Map<String, dynamic>.from(rawSlide);
      final rawItems = (slideMap['items'] as List?) ?? const [];

      slides.add(
        SavedSlide(
          id: slideMap['slideId']?.toString().trim().isNotEmpty == true
              ? slideMap['slideId'].toString().trim()
              : 'slide_${i + 1}',
          templateType: _templateTypeFromString(
            slideMap['templateType']?.toString(),
          ),
          title: slideMap['title']?.toString() ?? '',
          subtitle: slideMap['subtitle']?.toString() ?? '',
          footer: slideMap['footer']?.toString() ?? '',
          highlightTitle: _nullableString(slideMap['highlightTitle']),
          highlightPrice: _nullableString(slideMap['highlightPrice']),
          items: rawItems.whereType<Map>().map((item) {
            final itemMap = Map<String, dynamic>.from(item);
            return SavedMenuItem(
              name: itemMap['name']?.toString() ?? '',
              price: itemMap['price']?.toString() ?? '',
              soldOut: itemMap['soldOut'] == true,
            );
          }).toList(),
          durationSeconds: _parseInt(slideMap['durationSeconds']) ?? 10,
          textScale: _parseDouble(slideMap['textScale']) ?? 1.0,
        ),
      );
    }

    final normalizedSlides = slides.isNotEmpty
        ? slides
        : [
            SavedSlide(
              id: 'slide_1',
              templateType: TemplateType.menu,
              title: '',
              subtitle: '',
              footer: '',
              highlightTitle: null,
              highlightPrice: null,
              items: const [],
              durationSeconds: 10,
            ),
          ];

    return SavedContent(
      id: stableContentId ?? 'screen_content_${Uri.encodeComponent(baseUrl)}',
      name: '$screenName – Aktueller Screen-Inhalt',
      templateType: normalizedSlides.first.templateType,
      lastUsedScreenIp: _extractIpFromBaseUrl(),
      slides: normalizedSlides,
      boardStyle: _normalizeBoardStyle(payload['boardStyle']?.toString()),
      fontStyle: _normalizeFontStyle(payload['fontStyle']?.toString()),
    );
  }

  String? _extractIpFromBaseUrl() {
    try {
      return Uri.parse(baseUrl).host;
    } catch (_) {
      return null;
    }
  }

  TemplateType _templateTypeFromString(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'promo':
        return TemplateType.promo;
      case 'welcome':
        return TemplateType.welcome;
      case 'menu':
      default:
        return TemplateType.menu;
    }
  }

  String _normalizeBoardStyle(String? value) {
    return (value ?? '').trim().toLowerCase() == 'green' ? 'green' : 'black';
  }

  String _normalizeFontStyle(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'standard':
      case 'normal':
      case 'classic':
        return 'standard';
      case 'chalk':
      case 'kreide':
      case 'chalk1':
      case 'chalk2':
      case 'chalk3':
      case 'schrift 1':
      case 'schrift 2':
      case 'schrift 3':
      default:
        return 'chalk';
    }
  }

  String _normalizeOrientation(String? value, String fallback) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized == 'portrait') {
      return 'portrait';
    }
    if (normalized == 'landscape') {
      return 'landscape';
    }
    return fallback.trim().toLowerCase() == 'portrait' ? 'portrait' : 'landscape';
  }

  int? _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _parseDouble(Object? value) {
    if (value is double) return value.clamp(0.8, 1.25).toDouble();
    if (value is num) return value.toDouble().clamp(0.8, 1.25).toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    return parsed == null ? null : parsed.clamp(0.8, 1.25).toDouble();
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
