import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'widgets/headline_board_widget.dart';
import 'widgets/menu_board_widget.dart';
import 'widgets/photo_board_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureFullscreen();
  runApp(const MyApp());
}

Future<void> _configureFullscreen() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

enum PlayerAppState {
  initializing,
  unpaired,
  pairedIdle,
  playing,
  error,
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ScreenPlayerPage(),
    );
  }
}

class ScreenPlayerPage extends StatefulWidget {
  const ScreenPlayerPage({super.key});

  @override
  State<ScreenPlayerPage> createState() => _ScreenPlayerPageState();
}

class _ScreenPlayerPageState extends State<ScreenPlayerPage>
    with WidgetsBindingObserver {
  static const String _deviceIdKey = 'device_id';
  static const String _pairedKey = 'paired';
  static const String _screenNameKey = 'screen_name';
  static const String _contentVersionKey = 'content_version';
  static const String _pairingCodeKey = 'pairing_code';
  static const String _orientationKey = 'screen_orientation';
  static const int _serverPort = 8080;

  PlayerAppState appState = PlayerAppState.initializing;

  String appVersion = '';
  String? errorMessage;
  String? deviceId;
  String? screenName;
  String? pairingCode;
  bool paired = false;
  int contentVersion = 0;
  String screenOrientation = 'landscape';

  Map<String, dynamic>? contentPackage;
  int currentSlideIndex = 0;
  Timer? slideTimer;

  HttpServer? localServer;
  String? localIpAddress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
    _refreshFullscreenSoon();
    _loadAppVersion();
  }

    Future<void> _refreshFullscreenSoon() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    await _configureFullscreen();
  }

    double _getSlidePhotoScale(Map<String, dynamic>? slide) {
    final value = slide?['photoScale'];
    double resolved = 1.0;
    if (value is num) {
      resolved = value.toDouble();
    } else if (value is String) {
      resolved = double.tryParse(value) ?? 1.0;
    }
    if (resolved.isNaN || resolved.isInfinite) return 1.0;
    return resolved.clamp(0.8, 1.25).toDouble();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshFullscreenSoon();
    }
  }

  Future<void> _loadAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      appVersion = info.version;
    });
  } catch (_) {
    appVersion = '';
  }
}

  Future<void> _initializeApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String? storedDeviceId = prefs.getString(_deviceIdKey);
      if (storedDeviceId == null || storedDeviceId.isEmpty) {
        storedDeviceId = const Uuid().v4();
        await prefs.setString(_deviceIdKey, storedDeviceId);
      }

      String? storedPairingCode = prefs.getString(_pairingCodeKey);
      if (storedPairingCode == null || storedPairingCode.isEmpty) {
        storedPairingCode = _generatePairingCode();
        await prefs.setString(_pairingCodeKey, storedPairingCode);
      }

      final storedPaired = prefs.getBool(_pairedKey) ?? false;
      final storedScreenName = prefs.getString(_screenNameKey);
      final storedContentVersion = prefs.getInt(_contentVersionKey) ?? 0;
      final storedOrientation = prefs.getString(_orientationKey) ?? 'landscape';

      final localContent = await _readLocalContentPackage();

      deviceId = storedDeviceId;
      pairingCode = storedPairingCode;
      paired = storedPaired;
      screenName = storedScreenName;
      contentVersion = storedContentVersion;
      screenOrientation = storedOrientation;
      contentPackage = localContent;

      await _resolveLocalIpAddress();
      await _startLocalHttpServer();

      if (!mounted) return;

      final slides = _getSlides();

      setState(() {
        if (paired && slides.isNotEmpty) {
          appState = PlayerAppState.playing;
        } else if (paired) {
          appState = PlayerAppState.pairedIdle;
        } else {
          appState = PlayerAppState.unpaired;
        }
      });

      if (appState == PlayerAppState.playing) {
        _startSlideTimer();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        appState = PlayerAppState.error;
        errorMessage = 'Initialisierungsfehler: $e';
      });
    }
  }

  String _generatePairingCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _rotatePairingCode() async {
    final newCode = _generatePairingCode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pairingCodeKey, newCode);

    if (!mounted) return;
    setState(() {
      pairingCode = newCode;
    });
  }

  Future<void> _resolveLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();

        if (name.contains('nord') ||
            name.contains('vpn') ||
            name.contains('tun') ||
            name.contains('tap') ||
            name.contains('virtual')) {
          continue;
        }

        for (final addr in interface.addresses) {
          final ip = addr.address;
          if (_isUsableLocalIpv4(ip)) {
            localIpAddress = ip;
            return;
          }
        }
      }

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          if (_isUsableLocalIpv4(ip)) {
            localIpAddress = ip;
            return;
          }
        }
      }
    } catch (_) {
      localIpAddress = null;
    }
  }

  bool _isUsableLocalIpv4(String ip) {
    if (ip.startsWith('127.')) return false;
    if (ip.startsWith('169.254.')) return false;
    return true;
  }

  String _detectDeviceOrientation() {
    try {
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isNotEmpty) {
        final size = views.first.physicalSize;
        if (size.height > size.width) {
          return 'portrait';
        }
        return 'landscape';
      }
    } catch (_) {}

    return screenOrientation;
  }

  String _getPairingOrientation() {
    final detected = _detectDeviceOrientation();
    if (detected == 'portrait' || detected == 'landscape') {
      return detected;
    }
    return screenOrientation;
  }

  Future<void> _startLocalHttpServer() async {
    localServer?.close(force: true);

    localServer = await HttpServer.bind(
      InternetAddress.anyIPv4,
      _serverPort,
      shared: true,
    );

    localServer!.listen((HttpRequest request) async {
      try {
        final path = request.uri.path;

        if (request.method == 'GET' && path == '/pairing-info') {
          await _handleGetPairingInfo(request);
          return;
        }

        if (request.method == 'GET' && path == '/status') {
          await _handleGetStatus(request);
          return;
        }

        if (request.method == 'POST' && path == '/pair') {
          await _handlePostPair(request);
          return;
        }

        if (request.method == 'POST' && path == '/unpair') {
          await _handlePostUnpair(request);
          return;
        }

        if (request.method == 'GET' && path == '/content') {
          await _handleGetContent(request);
          return;
        }

        if (request.method == 'GET' && path == '/asset') {
          await _handleGetAsset(request);
          return;
        }

        if (request.method == 'POST' && path == '/asset') {
          await _handlePostAssetUpload(request);
          return;
        }

        if (request.method == 'POST' && path == '/content') {
          await _handlePostContent(request);
          return;
        }

        if (request.method == 'POST' && path == '/set-name') {
          await _handlePostSetName(request);
          return;
        }

        request.response.statusCode = HttpStatus.notFound;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'success': false,
          'error': 'Not Found',
          'path': path,
        }));
        await request.response.close();
      } catch (e) {
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'success': false,
            'error': 'Serverfehler',
            'details': e.toString(),
          }));
          await request.response.close();
        } catch (_) {}
      }
    });
  }

  Future<void> _handleGetPairingInfo(HttpRequest request) async {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;

    request.response.write(jsonEncode({
      'success': true,
      'deviceId': deviceId,
      'paired': paired,
      'screenName': screenName,
      'pairingCode': paired ? null : pairingCode,
      'contentVersion': contentVersion,
      'orientation': _getPairingOrientation(),
      'ip': localIpAddress,
      'port': _serverPort,
      'endpoints': {
        'pairingInfo': '/pairing-info',
        'status': '/status',
        'pair': '/pair',
        'unpair': '/unpair',
        'content': '/content',
        'asset': '/asset',
        'setName': '/set-name',
      },
      'hasContent': contentPackage != null,
    }));

    await request.response.close();
  }

  Future<void> _handleGetStatus(HttpRequest request) async {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;

    request.response.write(jsonEncode({
      'success': true,
      'status': paired ? 'ok' : 'unpaired',
      'deviceId': deviceId,
      'paired': paired,
      'screenName': screenName,
      'contentVersion': contentVersion,
      'orientation': _getPairingOrientation(),
      'ip': localIpAddress,
      'port': _serverPort,
      'appState': appState.name,
      'slidesCount': _getSlides().length,
    }));

    await request.response.close();
  }

  Future<void> _handlePostPair(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final decoded = jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'Ungültiges JSON',
      }));
      await request.response.close();
      return;
    }

    final receivedPairingCode = decoded['pairingCode']?.toString().trim();
    final newScreenName = decoded['screenName']?.toString().trim();
    final receivedOrientation =
        decoded['orientation']?.toString().trim().toLowerCase();

    if (receivedPairingCode == null || receivedPairingCode.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'pairingCode fehlt',
      }));
      await request.response.close();
      return;
    }

    if (receivedPairingCode != pairingCode) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'Pairing Code ungültig',
      }));
      await request.response.close();
      return;
    }

    if (newScreenName == null || newScreenName.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'screenName fehlt',
      }));
      await request.response.close();
      return;
    }

    final normalizedOrientation =
        receivedOrientation == 'portrait' ? 'portrait' : 'landscape';

    await _setPairedState(
      newPaired: true,
      newScreenName: newScreenName,
      newOrientation: normalizedOrientation,
    );

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'success': true,
      'deviceId': deviceId,
      'paired': true,
      'screenName': screenName,
      'message': 'Gerät erfolgreich gekoppelt',
    }));
    await request.response.close();
  }

  Future<void> _handlePostUnpair(HttpRequest request) async {
    await _resetDevice(rotateCode: true, preserveContent: false);

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'success': true,
      'paired': false,
      'message': 'Gerät wurde entkoppelt',
    }));
    await request.response.close();
  }


  Future<void> _handleGetContent(HttpRequest request) async {
    if (!paired) {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'Gerät ist nicht gekoppelt',
      }));
      await request.response.close();
      return;
    }

    if (contentPackage == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'Am Screen ist aktuell kein gespeicherter Content vorhanden',
        'deviceId': deviceId,
        'screenName': screenName,
        'contentVersion': contentVersion,
        'orientation': _getContentOrientation(),
      }));
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'success': true,
      'deviceId': deviceId,
      'screenName': screenName,
      'contentVersion': contentVersion,
      'orientation': _getContentOrientation(),
      'content': contentPackage,
    }));
    await request.response.close();
  }

  Future<void> _handleGetAsset(HttpRequest request) async {
    if (!paired) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    final assetId = request.uri.queryParameters['assetId']?.trim();
    if (assetId == null || assetId.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'assetId fehlt',
      }));
      await request.response.close();
      return;
    }

    String fallbackFileName = 'image.jpg';
    final slides = (contentPackage?['slides'] as List?) ?? const [];
    for (final rawSlide in slides.whereType<Map>()) {
      final slide = Map<String, dynamic>.from(rawSlide);
      if (slide['imageAssetId']?.toString().trim() == assetId) {
        fallbackFileName = slide['imageFileName']?.toString().trim().isNotEmpty == true
            ? slide['imageFileName'].toString().trim()
            : 'image.jpg';
        break;
      }
    }

    final file = await _assetFileForId(assetId, fallbackFileName: fallbackFileName);
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'Asset nicht gefunden',
      }));
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.ok;
    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  Future<void> _handlePostAssetUpload(HttpRequest request) async {
    if (!paired) {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'Gerät ist nicht gekoppelt',
      }));
      await request.response.close();
      return;
    }

    final assetId = request.headers.value('X-Asset-Id')?.trim();
    final fileName = request.headers.value('X-File-Name')?.trim() ?? 'image.jpg';

    if (assetId == null || assetId.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'X-Asset-Id fehlt',
      }));
      await request.response.close();
      return;
    }

    final bytes = await request.fold<List<int>>(<int>[], (buffer, data) {
      buffer.addAll(data);
      return buffer;
    });

    if (bytes.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'Asset ist leer',
      }));
      await request.response.close();
      return;
    }

    final file = await _assetFileForId(assetId, fallbackFileName: fileName);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'success': true,
      'assetId': assetId,
      'fileName': file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : fileName,
    }));
    await request.response.close();
  }

  Future<void> _handlePostSetName(HttpRequest request) async {
    if (!paired) {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'Gerät ist nicht gekoppelt',
      }));
      await request.response.close();
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      final decoded = jsonDecode(body);

      if (decoded is! Map<String, dynamic>) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'success': false,
          'error': 'Ungültiges JSON',
        }));
        await request.response.close();
        return;
      }

      final newScreenName = decoded['screenName']?.toString().trim();

      if (newScreenName == null || newScreenName.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'success': false,
          'error': 'screenName fehlt',
        }));
        await request.response.close();
        return;
      }

      await _setPairedState(
        newPaired: paired,
        newScreenName: newScreenName,
      );

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': true,
        'deviceId': deviceId,
        'paired': paired,
        'screenName': screenName,
        'message': 'Screen-Name erfolgreich gespeichert',
      }));
      await request.response.close();
    } catch (e) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'Screen-Name konnte nicht gespeichert werden',
        'details': e.toString(),
      }));
      await request.response.close();
    }
  }

  Future<void> _handlePostContent(HttpRequest request) async {
    if (!paired) {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'Gerät ist nicht gekoppelt',
      }));
      await request.response.close();
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    final decoded = jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': 'Ungültiges JSON',
      }));
      await request.response.close();
      return;
    }

    final validationError = await _validateContentPackage(decoded);
    if (validationError != null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': validationError,
      }));
      await request.response.close();
      return;
    }

    final newVersion = _extractContentVersion(decoded);

    await _setPairedState(
      newPaired: true,
      newScreenName: screenName,
      newContentVersion: newVersion,
      newContentPackage: decoded,
    );

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'success': true,
      'message': 'Content erfolgreich gespeichert',
      'contentVersion': contentVersion,
      'slidesCount': _getSlides().length,
    }));
    await request.response.close();
  }

  Future<String?> _validateContentPackage(Map<String, dynamic> data) async {
    final slides = data['slides'];

    if (slides is! List) {
      return 'slides fehlt oder ist keine Liste';
    }

    if (slides.isEmpty) {
      return 'slides darf nicht leer sein';
    }

    for (var i = 0; i < slides.length; i++) {
      final slide = slides[i];

      if (slide is! Map<String, dynamic>) {
        return 'slide an Position $i ist kein Objekt';
      }

      final templateType = slide['templateType']?.toString().trim().toLowerCase() ?? 'menu';
      final title = slide['title']?.toString();
      if (templateType != 'photo' && (title == null || title.trim().isEmpty)) {
        return 'slide an Position $i hat keinen title';
      }

      if (templateType == 'photo') {
        final assetId = slide['imageAssetId']?.toString().trim();
        if (assetId == null || assetId.isEmpty) {
          return 'Foto-Slide an Position $i hat kein Bild';
        }
        final assetFile = await _assetFileForId(
          assetId,
          fallbackFileName: slide['imageFileName']?.toString() ?? 'image.jpg',
        );
        if (!await assetFile.exists()) {
          return 'Bilddatei für Foto-Slide an Position $i fehlt';
        }
      }

      final duration = slide['durationSeconds'];
      if (duration != null) {
        if (duration is! int || duration <= 0) {
          return 'slide an Position $i hat ungültige durationSeconds';
        }
      }
    }

    return null;
  }

  int _extractContentVersion(Map<String, dynamic> data) {
    final value = data['contentVersion'];

    if (value is int && value > 0) return value;

    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0) return parsed;
    }

    return contentVersion + 1;
  }

  Future<File> _getContentFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/content_package.json');
  }

  Future<Directory> _getAssetsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final assetsDir = Directory('${dir.path}/content_assets');
    if (!await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
    }
    return assetsDir;
  }

  String _sanitizeFileName(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.isEmpty ? 'image.jpg' : cleaned;
  }

  Future<File> _assetFileForId(String assetId, {
    required String fallbackFileName,
  }) async {
    final assetsDir = await _getAssetsDirectory();
    final safeAssetId = _sanitizeFileName(assetId);
    final safeFileName = _sanitizeFileName(fallbackFileName);
    final extension = safeFileName.contains('.')
        ? safeFileName.substring(safeFileName.lastIndexOf('.'))
        : '.jpg';
    return File('${assetsDir.path}/${safeAssetId}$extension');
  }

  Set<String> _referencedAssetKeys(Map<String, dynamic>? package) {
    if (package == null) return <String>{};
    final slides = package['slides'] as List?;
    if (slides == null) return <String>{};

    final keys = <String>{};
    for (final rawSlide in slides.whereType<Map>()) {
      final slide = Map<String, dynamic>.from(rawSlide);
      final assetId = slide['imageAssetId']?.toString().trim();
      final fileName = slide['imageFileName']?.toString().trim() ?? 'image.jpg';
      if (assetId == null || assetId.isEmpty) continue;
      final safeAssetId = _sanitizeFileName(assetId);
      final safeFileName = _sanitizeFileName(fileName);
      final extension = safeFileName.contains('.')
          ? safeFileName.substring(safeFileName.lastIndexOf('.'))
          : '.jpg';
      keys.add('$safeAssetId$extension');
    }
    return keys;
  }

  Future<void> _pruneUnusedAssets(Map<String, dynamic>? package) async {
    final assetsDir = await _getAssetsDirectory();
    if (!await assetsDir.exists()) return;

    final keep = _referencedAssetKeys(package);
    await for (final entity in assetsDir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isNotEmpty ? entity.uri.pathSegments.last : '';
      if (!keep.contains(name)) {
        await entity.delete().catchError((_) {});
      }
    }
  }

  Future<Map<String, dynamic>?> _readLocalContentPackage() async {
    try {
      final file = await _getContentFile();
      if (!await file.exists()) {
        return null;
      }

      final raw = await file.readAsString();
      final decoded = json.decode(raw);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLocalContentPackage(Map<String, dynamic> package) async {
    final file = await _getContentFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(package),
      flush: true,
    );
    await _pruneUnusedAssets(package);
  }

  int _maxMenuItemsPerSlide() {
    return _isPortraitContent() ? 10 : 6;
  }

  List<List<T>> _chunkList<T>(List<T> items, int size) {
    if (items.isEmpty) return const [];
    final chunks = <List<T>>[];
    for (var i = 0; i < items.length; i += size) {
      final end = (i + size < items.length) ? i + size : items.length;
      chunks.add(items.sublist(i, end));
    }
    return chunks;
  }

  List<Map<String, dynamic>> _getSlides() {
    if (contentPackage == null) return [];

    final rawSlides = contentPackage!['slides'];
    if (rawSlides is! List) return [];

    final normalizedSlides = rawSlides
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final expandedSlides = <Map<String, dynamic>>[];
    final maxItems = _maxMenuItemsPerSlide();

    for (final slide in normalizedSlides) {
      final templateType = slide['templateType']?.toString() ?? 'menu';
      if (templateType != 'menu' && templateType != 'drinks') {
        expandedSlides.add(slide);
        continue;
      }

      final rawItems = (slide['items'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((e) =>
                  (e['name']?.toString().trim().isNotEmpty ?? false) ||
                  (e['price']?.toString().trim().isNotEmpty ?? false))
              .toList() ??
          <Map<String, dynamic>>[];

      if (rawItems.isEmpty) {
        expandedSlides.add({...slide, 'items': <Map<String, dynamic>>[]});
        continue;
      }

      final chunks = _chunkList(rawItems, maxItems);
      for (var i = 0; i < chunks.length; i++) {
        final cloned = Map<String, dynamic>.from(slide);
        cloned['items'] = chunks[i];
        cloned['menuChunkIndex'] = i + 1;
        cloned['menuChunkTotal'] = chunks.length;
        expandedSlides.add(cloned);
      }
    }

    return expandedSlides;
  }

  int _getSlideDurationSeconds(Map<String, dynamic> slide) {
    final value = slide['durationSeconds'];

    if (value is int && value > 0) return value;

    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0) return parsed;
    }

    return 10;
  }

  Color _getBoardColor() {
    final style = contentPackage?['boardStyle']?.toString() ?? 'black';

    if (style == 'green') {
      return const Color(0xFF1B5E20);
    }

    return const Color(0xFF111111);
  }

  String _getContentOrientation() {
    final contentValue =
        contentPackage?['orientation']?.toString().toLowerCase();

    if (contentValue == 'portrait') {
      return 'portrait';
    }

    if (contentValue == 'landscape') {
      return 'landscape';
    }

    if (screenOrientation == 'portrait') {
      return 'portrait';
    }

    return 'landscape';
  }

  bool _isPortraitContent() {
    return _getContentOrientation() == 'portrait';
  }


  String? _getLogoBase64() {
    final value = contentPackage?['logoBase64']?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
  String _getSlideLogoMode(Map<String, dynamic>? slide) {
    final value = slide?['logoMode']?.toString().trim().toLowerCase();
    switch (value) {
      case 'center':
      case 'centerwatermark':
      case 'watermark':
        return 'center';
      case 'topleft':
      case 'top_left':
      case 'top-left':
      case 'stamp':
        return 'topLeft';
      default:
        return 'none';
    }
  }

  double _getSlideLogoOpacity(Map<String, dynamic>? slide) {
    final value = slide?['logoOpacity'];
    double resolved = 0.12;
    if (value is num) {
      resolved = value.toDouble();
    } else if (value is String) {
      resolved = double.tryParse(value) ?? 0.12;
    }
    if (resolved.isNaN || resolved.isInfinite) {
      return 0.12;
    }
    if (resolved > 1) {
      resolved = resolved / 100.0;
    }
    return resolved.clamp(0.05, 0.80).toDouble();
  }

  Widget _buildLogoOverlay(Map<String, dynamic>? slide) {
    final raw = _getLogoBase64();
    if (raw == null) return const SizedBox.shrink();

    try {
      final bytes = base64Decode(raw);
      final isPortrait = _isPortraitContent();
      if ((slide?['templateType']?.toString().trim().toLowerCase() == 'photo') &&
          (slide?['title']?.toString().trim().isNotEmpty ?? false)) {
        return const SizedBox.shrink();
      }
      final mode = _getSlideLogoMode(slide);

      if (mode == 'topLeft') {
        return LayoutBuilder(
          builder: (context, constraints) {
            final stampWidth = isPortrait
                ? constraints.maxWidth * 0.20
                : constraints.maxWidth * 0.16;

            return IgnorePointer(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: constraints.maxWidth * 0.055,
                    top: constraints.maxHeight * 0.055,
                  ),
                  child: Opacity(
                    opacity: _getSlideLogoOpacity(slide),
                    child: Transform.rotate(
                      angle: -0.16,
                      child: SizedBox(
                        width: stampWidth,
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }

      if (mode == 'center') {
        return LayoutBuilder(
          builder: (context, constraints) {
            final watermarkWidth = isPortrait
                ? constraints.maxWidth * 0.62
                : constraints.maxWidth * 0.52;

            return IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: _getSlideLogoOpacity(slide),
                  child: SizedBox(
                    width: watermarkWidth,
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }

      return const SizedBox.shrink();
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  String _getFontStyle([Map<String, dynamic>? slide]) {
    final raw = (slide?['fontStyle'] ?? contentPackage?['fontStyle'])
        ?.toString()
        .toLowerCase()
        .trim();

    switch (raw) {
      case 'standard':
      case 'normal':
      case 'classic':
        return 'standard';
      case 'chalk':
      case 'chalk1':
      case 'chalk2':
      case 'chalk3':
      case 'kreide':
      case 'schrift 1':
      case 'schrift 2':
      case 'schrift 3':
      default:
        return 'chalk';
    }
  }

  double _getSlideTextScale(Map<String, dynamic>? slide) {
    final value = slide?['textScale'];
    double resolved = 1.0;
    if (value is num) {
      resolved = value.toDouble();
    } else if (value is String) {
      resolved = double.tryParse(value) ?? 1.0;
    }
    if (resolved.isNaN || resolved.isInfinite) {
      return 1.0;
    }
    return resolved.clamp(0.8, 1.25).toDouble();
  }

  TextStyle _getTitleStyle({
    double fontSize = 48,
    Map<String, dynamic>? slide,
  }) {
    final fontStyle = _getFontStyle(slide);
    final resolvedFontSize = fontSize * _getSlideTextScale(slide);

    switch (fontStyle) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'Gobsmacked',
          fontFamilyFallback: const ['Roboto', 'Noto Sans'],
          fontSize: resolvedFontSize,
          color: const Color(0xFFF2E9DC),
          height: 1.0,
        );
      default:
        return TextStyle(
          fontFamily: 'Roboto',
          fontFamilyFallback: const ['Noto Sans'],
          fontSize: resolvedFontSize,
          color: const Color(0xFFF2E9DC),
          height: 1.0,
          fontWeight: FontWeight.w700,
        );
    }
  }

  TextStyle _getBodyStyle({
    double fontSize = 28,
    Map<String, dynamic>? slide,
  }) {
    final fontStyle = _getFontStyle(slide);
    final resolvedFontSize = fontSize * _getSlideTextScale(slide);

    switch (fontStyle) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'Gobsmacked',
          fontFamilyFallback: const ['Roboto', 'Noto Sans'],
          fontSize: resolvedFontSize,
          color: const Color(0xFFF2E9DC),
          height: 1.12,
        );
      default:
        return TextStyle(
          fontFamily: 'Roboto',
          fontFamilyFallback: const ['Noto Sans'],
          fontSize: resolvedFontSize,
          color: const Color(0xFFF2E9DC),
          height: 1.12,
          fontWeight: FontWeight.w500,
        );
    }
  }

  TextStyle _getPriceStyle({
    double fontSize = 34,
    Map<String, dynamic>? slide,
  }) {
    final fontStyle = _getFontStyle(slide);
    final resolvedFontSize = fontSize * _getSlideTextScale(slide);

    switch (fontStyle) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'Gobsmacked',
          fontFamilyFallback: const ['Roboto', 'Noto Sans'],
          fontSize: resolvedFontSize,
          color: const Color(0xFFF2E9DC),
          height: 1.0,
        );
      default:
        return TextStyle(
          fontFamily: 'Roboto',
          fontFamilyFallback: const ['Noto Sans'],
          fontSize: resolvedFontSize,
          color: const Color(0xFFF2E9DC),
          height: 1.0,
          fontWeight: FontWeight.w700,
        );
    }
  }

  void _startSlideTimer() {
    slideTimer?.cancel();

    final slides = _getSlides();
    if (slides.isEmpty) return;

    if (currentSlideIndex >= slides.length) {
      currentSlideIndex = 0;
    }

    final duration = _getSlideDurationSeconds(slides[currentSlideIndex]);

    slideTimer = Timer(Duration(seconds: duration), () {
      if (!mounted) return;

      final currentSlides = _getSlides();
      if (currentSlides.isEmpty) return;

      setState(() {
        currentSlideIndex = (currentSlideIndex + 1) % currentSlides.length;
      });

      _startSlideTimer();
    });
  }

  Future<void> _setPairedState({
    required bool newPaired,
    String? newScreenName,
    String? newOrientation,
    int? newContentVersion,
    Map<String, dynamic>? newContentPackage,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_pairedKey, newPaired);

    if (newScreenName != null) {
      await prefs.setString(_screenNameKey, newScreenName);
    }

    if (newOrientation != null) {
      await prefs.setString(_orientationKey, newOrientation);
    }

    if (newContentVersion != null) {
      await prefs.setInt(_contentVersionKey, newContentVersion);
    }

    if (newContentPackage != null) {
      await _saveLocalContentPackage(newContentPackage);
    }

    if (!mounted) return;

    setState(() {
      paired = newPaired;
      screenName = newScreenName ?? screenName;
      screenOrientation = newOrientation ?? screenOrientation;
      contentVersion = newContentVersion ?? contentVersion;
      contentPackage = newContentPackage ?? contentPackage;
      currentSlideIndex = 0;

      final slides = _getSlides();
      if (paired && slides.isNotEmpty) {
        appState = PlayerAppState.playing;
      } else if (paired) {
        appState = PlayerAppState.pairedIdle;
      } else {
        appState = PlayerAppState.unpaired;
      }
    });

    if (appState == PlayerAppState.playing) {
      _startSlideTimer();
    } else {
      slideTimer?.cancel();
    }
  }

  Future<void> _resetDevice({
    bool rotateCode = false,
    bool preserveContent = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final file = await _getContentFile();

    await prefs.setBool(_pairedKey, false);

    if (!preserveContent) {
      await prefs.remove(_screenNameKey);
      await prefs.remove(_contentVersionKey);
      await prefs.remove(_orientationKey);

      if (await file.exists()) {
        await file.delete();
      }
    }

    slideTimer?.cancel();

    if (rotateCode) {
      await _rotatePairingCode();
    }

    if (!mounted) return;

    setState(() {
      paired = false;
      if (!preserveContent) {
        screenName = null;
        contentVersion = 0;
        screenOrientation = 'landscape';
        contentPackage = null;
      }
      currentSlideIndex = 0;
      appState = PlayerAppState.unpaired;
    });
  }

  String _pairingUrlText() {
    if (localIpAddress == null) {
      return 'IP wird ermittelt...';
    }
    return 'http://$localIpAddress:$_serverPort/pairing-info';
  }

  String _pairingQrData() {
    return jsonEncode({
      'type': 'greenbird_pairing',
      'deviceId': deviceId,
      'screenName': screenName,
      'pairingCode': pairingCode,
      'ip': localIpAddress,
      'port': _serverPort,
      'orientation': _getPairingOrientation(),
      'pairingInfoUrl': localIpAddress == null
          ? null
          : 'http://$localIpAddress:$_serverPort/pairing-info',
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    slideTimer?.cancel();
    localServer?.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (appState) {
      case PlayerAppState.initializing:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );

      case PlayerAppState.error:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                errorMessage ?? 'Unbekannter Fehler',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
        );

      case PlayerAppState.unpaired:
        return _buildUnpairedScreen();

      case PlayerAppState.pairedIdle:
        return _buildPairedIdleScreen();

      case PlayerAppState.playing:
        return _buildPlayingScreen();
    }
  }

  Widget _buildUnpairedScreen() {
    return Scaffold(
      body: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cast_connected,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Gerät noch nicht gekoppelt',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 34,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Dieses Display wartet auf Pairing und Content-Übertragung über die Handy-/Tablet-App.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 30),
                SelectableText(
                  'Device ID:\n${deviceId ?? "-"}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                SelectableText(
                  'Pairing Code:\n${pairingCode ?? "-"}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                SelectableText(
                  'Server:\n${_pairingUrlText()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 260,
                  height: 260,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: localIpAddress == null ||
                          pairingCode == null ||
                          pairingCode!.isEmpty
                      ? const Center(
                          child: Text(
                            'QR wird vorbereitet...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black87,
                            ),
                          ),
                        )
                      : QrImageView(
                          data: _pairingQrData(),
                          version: QrVersions.auto,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mit der Handy-App scannen und automatisch koppeln',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPairedIdleScreen() {
    return Scaffold(
      body: GestureDetector(
        onLongPress: () => _resetDevice(rotateCode: true, preserveContent: true),
        child: Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 90,
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Screen gekoppelt',
                    style: TextStyle(
                      fontSize: 34,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    screenName ?? 'Unbenannter Screen',
                    style: const TextStyle(
                      fontSize: 26,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Noch kein Content übertragen',
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Long Press zum Entkoppeln',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayingScreen() {
    final slides = _getSlides();

    if (slides.isEmpty) {
      return _buildPairedIdleScreen();
    }

    if (currentSlideIndex >= slides.length) {
      currentSlideIndex = 0;
    }

    final slide = slides[currentSlideIndex];
    final templateType = slide['templateType']?.toString() ?? 'menu';

    return Scaffold(
  body: GestureDetector(
    onLongPress: () => _resetDevice(rotateCode: true, preserveContent: true),
    child: Container(
      width: double.infinity,
      height: double.infinity,
      color: _getBoardColor(),
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildLogoOverlay(slide),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 80,
              vertical: 60,
            ),
            child: _buildSlideContent(slide, templateType),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Opacity(
              opacity: 0.35,
              child: Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: Text(
                      screenName ?? 'Unbenannter Screen',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            '©',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'greenbird.fm',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        this.appVersion.trim().isEmpty
                            ? 'Player'
                            : 'Player ${this.appVersion}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

  }
  Widget _buildSlideContent(Map<String, dynamic> slide, String templateType) {
    switch (templateType) {
      case 'photo':
        return _buildPhotoSlide(slide);
      case 'promo':
        return _buildPromoSlide(slide);
      case 'welcome':
        return _buildWelcomeSlide(slide);
      case 'drinks':
      case 'menu':
      default:
        return _buildMenuSlide(slide);
    }
  }

  Widget _buildMenuSlide(Map<String, dynamic> slide) {
    return _isPortraitContent()
        ? _buildMenuPortrait(slide)
        : _buildMenuLandscape(slide);
  }

  Widget _buildMenuLandscape(Map<String, dynamic> slide) {
    final items = ((slide['items'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final chunkIndex = (slide['menuChunkIndex'] as num?)?.toInt() ?? 1;
    final chunkTotal = (slide['menuChunkTotal'] as num?)?.toInt() ?? 1;

    return Center(
      child: MenuBoardWidget(
        title: slide['title']?.toString() ?? '',
        subtitle: slide['subtitle']?.toString() ?? '',
        footer: slide['footer']?.toString() ?? '',
        items: items,
        isPortrait: false,
        pageLabel: chunkTotal > 1 ? 'Teil $chunkIndex von $chunkTotal' : null,
        titleStyleBuilder: (base) => _getTitleStyle(fontSize: base, slide: slide),
        bodyStyleBuilder: (base) => _getBodyStyle(fontSize: base, slide: slide),
        priceStyleBuilder: (base) =>
            _getPriceStyle(fontSize: base, slide: slide),
      ),
    );
  }

  Widget _buildMenuPortrait(Map<String, dynamic> slide) {
    final items = ((slide['items'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final chunkIndex = (slide['menuChunkIndex'] as num?)?.toInt() ?? 1;
    final chunkTotal = (slide['menuChunkTotal'] as num?)?.toInt() ?? 1;

    return Center(
      child: MenuBoardWidget(
        title: slide['title']?.toString() ?? '',
        subtitle: slide['subtitle']?.toString() ?? '',
        footer: slide['footer']?.toString() ?? '',
        items: items,
        isPortrait: true,
        pageLabel: chunkTotal > 1 ? 'Teil $chunkIndex von $chunkTotal' : null,
        titleStyleBuilder: (base) => _getTitleStyle(fontSize: base, slide: slide),
        bodyStyleBuilder: (base) => _getBodyStyle(fontSize: base, slide: slide),
        priceStyleBuilder: (base) =>
            _getPriceStyle(fontSize: base, slide: slide),
      ),
    );
  }

  Widget _buildPhotoSlide(Map<String, dynamic> slide) {
    return FutureBuilder<File>(
      future: _assetFileForId(
        slide['imageAssetId']?.toString().trim() ?? '',
        fallbackFileName: slide['imageFileName']?.toString() ?? 'image.jpg',
      ),
      builder: (context, snapshot) {
        final file = snapshot.data;
        final exists = file != null && file.existsSync();

        return PhotoBoardWidget(
          title: slide['title']?.toString() ?? '',
          isPortrait: _isPortraitContent(),
          photoScale: _getSlidePhotoScale(slide),
          titleStyleBuilder: (base) => _getTitleStyle(fontSize: base, slide: slide),
          imageChild: exists
              ? Image.file(
                  file,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Bild nicht gefunden',
                      textAlign: TextAlign.center,
                      style: _getBodyStyle(
                        fontSize: _isPortraitContent() ? 34 : 24,
                        slide: slide,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPromoSlide(Map<String, dynamic> slide) {
    return _isPortraitContent()
        ? _buildPromoPortrait(slide)
        : _buildPromoLandscape(slide);
  }

  Widget _buildPromoLandscape(Map<String, dynamic> slide) {
    return HeadlineBoardWidget(
      title: slide['title']?.toString() ?? '',
      subtitle: slide['subtitle']?.toString() ?? '',
      footer: slide['footer']?.toString() ?? '',
      highlightTitle: slide['highlightTitle']?.toString() ?? '',
      highlightPrice: slide['highlightPrice']?.toString() ?? '',
      isPortrait: false,
      isWelcome: false,
      titleStyleBuilder: (base) => _getTitleStyle(fontSize: base, slide: slide),
      bodyStyleBuilder: (base) => _getBodyStyle(fontSize: base, slide: slide),
      priceStyleBuilder: (base) =>
          _getPriceStyle(fontSize: base, slide: slide),
    );
  }

  Widget _buildPromoPortrait(Map<String, dynamic> slide) {
    return HeadlineBoardWidget(
      title: slide['title']?.toString() ?? '',
      subtitle: slide['subtitle']?.toString() ?? '',
      footer: slide['footer']?.toString() ?? '',
      highlightTitle: slide['highlightTitle']?.toString() ?? '',
      highlightPrice: slide['highlightPrice']?.toString() ?? '',
      isPortrait: true,
      isWelcome: false,
      titleStyleBuilder: (base) => _getTitleStyle(fontSize: base, slide: slide),
      bodyStyleBuilder: (base) => _getBodyStyle(fontSize: base, slide: slide),
      priceStyleBuilder: (base) =>
          _getPriceStyle(fontSize: base, slide: slide),
    );
  }

  Widget _buildWelcomeSlide(Map<String, dynamic> slide) {
    return _isPortraitContent()
        ? _buildWelcomePortrait(slide)
        : _buildWelcomeLandscape(slide);
  }

  Widget _buildWelcomeLandscape(Map<String, dynamic> slide) {
    return HeadlineBoardWidget(
      title: slide['title']?.toString() ?? '',
      subtitle: slide['subtitle']?.toString() ?? '',
      footer: slide['footer']?.toString() ?? '',
      highlightTitle: '',
      highlightPrice: '',
      isPortrait: false,
      isWelcome: true,
      titleStyleBuilder: (base) => _getTitleStyle(fontSize: base, slide: slide),
      bodyStyleBuilder: (base) => _getBodyStyle(fontSize: base, slide: slide),
      priceStyleBuilder: (base) =>
          _getPriceStyle(fontSize: base, slide: slide),
    );
  }

  Widget _buildWelcomePortrait(Map<String, dynamic> slide) {
    return HeadlineBoardWidget(
      title: slide['title']?.toString() ?? '',
      subtitle: slide['subtitle']?.toString() ?? '',
      footer: slide['footer']?.toString() ?? '',
      highlightTitle: '',
      highlightPrice: '',
      isPortrait: true,
      isWelcome: true,
      titleStyleBuilder: (base) => _getTitleStyle(fontSize: base, slide: slide),
      bodyStyleBuilder: (base) => _getBodyStyle(fontSize: base, slide: slide),
      priceStyleBuilder: (base) =>
          _getPriceStyle(fontSize: base, slide: slide),
    );
  
  }
}