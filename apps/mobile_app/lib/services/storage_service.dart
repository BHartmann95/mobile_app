import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';
import '../models/screen.dart';

class StorageService {
  static const String screensKey = 'saved_screens';

  Future<List<ScreenDevice>> loadScreens() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(screensKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final screens = ScreenDevice.decodeList(raw);
      return _sortScreens(screens);
    } catch (e, stackTrace) {
      developer.log(
        'Fehler beim Laden der Screens',
        name: 'StorageService',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<void> saveScreens(List<ScreenDevice> screens) async {
    final prefs = await SharedPreferences.getInstance();
    final sortedScreens = _sortScreens(screens);
    await prefs.setString(screensKey, ScreenDevice.encodeList(sortedScreens));
  }

  Future<void> addOrUpdateScreen(ScreenDevice screen) async {
    final screens = await loadScreens();

    int existingIndex = -1;

    if (screen.deviceId != null && screen.deviceId!.trim().isNotEmpty) {
      existingIndex = screens.indexWhere((s) => s.deviceId == screen.deviceId);
    }

    if (existingIndex < 0) {
      existingIndex = screens.indexWhere((s) => s.ip == screen.ip);
    }

    if (existingIndex >= 0) {
      final existing = screens[existingIndex];

      screens[existingIndex] = existing.copyWith(
        ip: screen.ip,
        name: screen.name,
        orientation: screen.orientation,
        deviceId: screen.deviceId ?? existing.deviceId,
        lastOpenedAt: screen.lastOpenedAt ?? existing.lastOpenedAt,
        lastContentSentAt:
            screen.lastContentSentAt ?? existing.lastContentSentAt,
        lastContentVersion:
            screen.lastContentVersion ?? existing.lastContentVersion,
      );
    } else {
      screens.add(screen);
    }

    await saveScreens(screens);
  }

  Future<void> deleteScreen(String ip) async {
    final screens = await loadScreens();
    screens.removeWhere((s) => s.ip == ip);
    await saveScreens(screens);
  }

  Future<void> deleteScreenByDeviceIdOrIp({
    String? deviceId,
    String? ip,
  }) async {
    final screens = await loadScreens();

    screens.removeWhere((screen) {
      if (deviceId != null &&
          deviceId.trim().isNotEmpty &&
          screen.deviceId == deviceId) {
        return true;
      }

      if (ip != null && ip.trim().isNotEmpty && screen.ip == ip) {
        return true;
      }

      return false;
    });

    await saveScreens(screens);
  }

  Future<void> markScreenAsLastOpened(String ip) async {
    final screens = await loadScreens();
    final now = DateTime.now();

    final updated = screens.map((screen) {
      if (screen.ip == ip) {
        return screen.copyWith(lastOpenedAt: now);
      }
      return screen;
    }).toList();

    await saveScreens(updated);
  }

  Future<void> markContentSent({
    required String ip,
    required int contentVersion,
  }) async {
    final screens = await loadScreens();
    final now = DateTime.now();

    final updated = screens.map((screen) {
      if (screen.ip == ip) {
        return screen.copyWith(
          lastContentSentAt: now,
          lastContentVersion: contentVersion,
        );
      }
      return screen;
    }).toList();

    await saveScreens(updated);
  }

  List<ScreenDevice> _sortScreens(List<ScreenDevice> screens) {
    final sorted = List<ScreenDevice>.from(screens);

    sorted.sort((a, b) {
      final aTime = a.lastOpenedAt;
      final bTime = b.lastOpenedAt;

      if (aTime != null && bTime != null) {
        return bTime.compareTo(aTime);
      }
      if (aTime != null) return -1;
      if (bTime != null) return 1;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return sorted;
  }
}
