import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../models/screen.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import 'screen_dashboard.dart';
import 'pairing_screen.dart';

class ScreenListScreen extends StatefulWidget {
  const ScreenListScreen({super.key});

  @override
  State<ScreenListScreen> createState() => _ScreenListScreenState();
}

class _ScreenListScreenState extends State<ScreenListScreen> {
  List<ScreenDevice> screens = [];
  bool isLoading = true;
  bool isRefreshingStatus = false;
  bool isDiscoveringScreens = false;

  final Map<String, ScreenStatus?> screenStatuses = {};
  Timer? statusRefreshTimer;
  DateTime? lastDiscoveryAt;

  @override
  void initState() {
    super.initState();
    loadScreens();
    _startAutoRefresh();
  }

  Future<void> loadScreens() async {
    final storage = StorageService();
    final loaded = await storage.loadScreens();

    if (!mounted) return;

    setState(() {
      screens = loaded;
      isLoading = false;

      for (final screen in loaded) {
        screenStatuses.putIfAbsent(screen.ip, () => null);
      }

      final ips = loaded.map((e) => e.ip).toSet();
      screenStatuses.removeWhere((ip, _) => !ips.contains(ip));
    });

    await _discoverKnownScreensInCurrentNetwork();
    await _reloadFromStorage();
    await refreshStatuses();
  }

  Future<void> _reloadFromStorage() async {
    final storage = StorageService();
    final loaded = await storage.loadScreens();

    if (!mounted) return;

    setState(() {
      screens = loaded;

      for (final screen in loaded) {
        screenStatuses.putIfAbsent(screen.ip, () => null);
      }

      final ips = loaded.map((e) => e.ip).toSet();
      screenStatuses.removeWhere((ip, _) => !ips.contains(ip));
    });
  }

  bool _shouldRunDiscovery() {
    if (screens.isEmpty) return false;
    if (isDiscoveringScreens) return false;
    if (screens.every((screen) =>
        screen.deviceId == null || screen.deviceId!.trim().isEmpty)) {
      return false;
    }

    if (lastDiscoveryAt == null) return true;

    final diff = DateTime.now().difference(lastDiscoveryAt!);
    return diff.inSeconds >= 20;
  }

  Future<void> _discoverKnownScreensInCurrentNetwork() async {
    if (!_shouldRunDiscovery()) return;

    final knownByDeviceId = <String, ScreenDevice>{};
    for (final screen in screens) {
      final deviceId = screen.deviceId?.trim();
      if (deviceId != null && deviceId.isNotEmpty) {
        knownByDeviceId[deviceId] = screen;
      }
    }

    if (knownByDeviceId.isEmpty) return;

    setState(() {
      isDiscoveringScreens = true;
    });

    lastDiscoveryAt = DateTime.now();

    try {
      final subnetPrefix = await _getLocalSubnetPrefix();
      if (subnetPrefix == null) {
        return;
      }

      final ownIp = await _getLocalIpv4();
      final candidates = <String>[];
      for (int i = 1; i <= 254; i++) {
        final ip = '$subnetPrefix.$i';
        if (ip == ownIp) continue;
        candidates.add(ip);
      }

      int updatedCount = 0;

      for (int start = 0; start < candidates.length; start += 24) {
        final batch = candidates.skip(start).take(24).toList();

        final results = await Future.wait(
          batch.map((ip) async {
            final api = ApiService('http://$ip:8080');
            final info = await api.getPairingInfo(
              timeout: const Duration(milliseconds: 350),
            );
            return MapEntry(ip, info);
          }),
        );

        for (final result in results) {
          final info = result.value;
          final deviceId = info.deviceId?.trim();

          if (!info.success || deviceId == null || deviceId.isEmpty) {
            continue;
          }

          final knownScreen = knownByDeviceId[deviceId];
          if (knownScreen == null) {
            continue;
          }

          final newOrientation = (info.orientation == 'portrait' ||
                  info.orientation == 'landscape')
              ? info.orientation!
              : knownScreen.orientation;

          final liveName = info.screenName?.trim();
          final newName = (liveName != null &&
                  liveName.isNotEmpty &&
                  !_isGenericFallbackName(liveName))
              ? liveName
              : knownScreen.name;

          if (knownScreen.ip != result.key ||
              knownScreen.orientation != newOrientation ||
              knownScreen.name != newName) {
            final storage = StorageService();
            await storage.addOrUpdateScreen(
              knownScreen.copyWith(
                ip: result.key,
                name: newName,
                orientation: newOrientation,
              ),
            );
            updatedCount++;
          }
        }
      }

      if (updatedCount > 0) {
        await _reloadFromStorage();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$updatedCount bekannte Screen-Adresse(n) im aktuellen Netzwerk aktualisiert',
            ),
          ),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        isDiscoveringScreens = false;
      });
    }
  }


  bool _isGenericFallbackName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return false;

    final genericPattern = RegExp(r'^Screen\s+[A-Z0-9]{4,}$', caseSensitive: false);
    return genericPattern.hasMatch(normalized);
  }

  Future<String?> _getLocalIpv4() async {
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
          if (!ip.startsWith('127.') && !ip.startsWith('169.254.')) {
            return ip;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<String?> _getLocalSubnetPrefix() async {
    final ip = await _getLocalIpv4();
    if (ip == null) return null;

    final parts = ip.split('.');
    if (parts.length != 4) return null;

    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  Future<void> refreshStatuses() async {
    if (screens.isEmpty) return;
    if (isRefreshingStatus) return;

    if (!mounted) return;
    setState(() {
      isRefreshingStatus = true;
    });

    for (final screen in screens) {
      final api = ApiService('http://${screen.ip}:8080');
      final status = await api.getStatus();

      if (!mounted) return;
      setState(() {
        screenStatuses[screen.ip] = status;
      });
    }

    final hasOfflineScreens = screens.any((screen) {
      final status = screenStatuses[screen.ip];
      return status == null || !status.isOnline;
    });

    if (hasOfflineScreens) {
      await _discoverKnownScreensInCurrentNetwork();
      await _reloadFromStorage();

      for (final screen in screens) {
        final api = ApiService('http://${screen.ip}:8080');
        final status = await api.getStatus();

        if (!mounted) return;
        setState(() {
          screenStatuses[screen.ip] = status;
        });
      }
    }

    if (!mounted) return;
    setState(() {
      isRefreshingStatus = false;
    });
  }

  void _startAutoRefresh() {
    statusRefreshTimer?.cancel();

    statusRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (!mounted || isLoading || isRefreshingStatus || screens.isEmpty) {
          return;
        }
        refreshStatuses();
      },
    );
  }

  void _stopAutoRefresh() {
    statusRefreshTimer?.cancel();
    statusRefreshTimer = null;
  }

  Future<void> openScreen(ScreenDevice screen) async {
    final storage = StorageService();
    await storage.markScreenAsLastOpened(screen.ip);

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreenDashboardPage(
          ip: screen.ip,
          screenName: screen.name,
          screenOrientation: screen.orientation,
        ),
      ),
    );

    await loadScreens();
  }

  void addScreen() {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const PairingScreen(),
      ),
    ).then((_) => loadScreens());
  }

  Future<void> reconnectScreen(ScreenDevice screen) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PairingScreen(
          initialScreen: screen,
        ),
      ),
    );

    await loadScreens();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Wenn der Screen im selben Netz ist, wird seine IP jetzt automatisch oder per QR-Scan aktualisiert.',
        ),
      ),
    );
  }

  void showOptions(ScreenDevice screen) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Umbenennen'),
                onTap: () {
                  Navigator.pop(context);
                  renameScreen(screen);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Screen neu verbinden / IP aktualisieren'),
                onTap: () {
                  Navigator.pop(context);
                  reconnectScreen(screen);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Screen löschen'),
                onTap: () {
                  Navigator.pop(context);
                  deleteScreen(screen);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_off, color: Colors.red),
                title: const Text('Screen entkoppeln'),
                onTap: () {
                  Navigator.pop(context);
                  unpairScreen(screen);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void renameScreen(ScreenDevice screen) {
    final controller = TextEditingController(text: screen.name);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Screen umbenennen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Neuer Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();

              if (newName.isEmpty) return;

              final api = ApiService('http://${screen.ip}:8080');
              final result = await api.setScreenName(newName);

              if (!mounted) return;

              if (!result.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.error ?? 'Screen-Name konnte nicht gespeichert werden',
                    ),
                  ),
                );
                return;
              }

              final storage = StorageService();

              await storage.addOrUpdateScreen(
                screen.copyWith(name: newName),
              );

              if (!mounted) return;

              Navigator.pop(context);
              await loadScreens();

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"$newName" wurde gespeichert'),
                ),
              );
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Future<void> deleteScreen(ScreenDevice screen) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Screen löschen'),
        content: Text(
          'Soll "${screen.name}" wirklich aus der App gelöscht werden?\n\n'
          'Das funktioniert auch dann, wenn der Screen gerade offline ist.\n'
          'Der Screen selbst bleibt dabei unverändert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final storage = StorageService();
    await storage.deleteScreenByDeviceIdOrIp(
      deviceId: screen.deviceId,
      ip: screen.ip,
    );
    await loadScreens();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${screen.name}" wurde gelöscht'),
      ),
    );
  }

  Future<void> unpairScreen(ScreenDevice screen) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Screen entkoppeln'),
        content: Text(
          'Soll "${screen.name}" wirklich entkoppelt werden?\n\n'
          'Der Screen löscht dabei sein Pairing und seinen Content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entkoppeln'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = ApiService('http://${screen.ip}:8080');
      final success = await api.unpairDevice();

      if (success) {
        final storage = StorageService();
        await storage.deleteScreenByDeviceIdOrIp(
          deviceId: screen.deviceId,
          ip: screen.ip,
        );
        await loadScreens();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${screen.name}" wurde entkoppelt'),
          ),
        );
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Screen konnte nicht entkoppelt werden'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Entkoppeln: $e'),
        ),
      );
    }
  }

  String _lastUsedLabel(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Noch nicht geöffnet';
    }

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return 'Zuletzt geöffnet: $day.$month.$year $hour:$minute';
  }

  String _lastSentLabel(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Noch nie gesendet';
    }

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return 'Zuletzt gesendet: $day.$month.$year $hour:$minute';
  }

  Widget _buildStatusDot(ScreenStatus? status) {
    if (status == null) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Icon(
      Icons.circle,
      size: 16,
      color: status.isOnline ? Colors.green : Colors.red,
    );
  }

  String _buildStatusText(ScreenStatus? status) {
    if (status == null) {
      return 'Status wird geprüft';
    }
    return status.isOnline ? 'Online' : 'Offline';
  }

  String _buildVersionText(ScreenDevice screen, ScreenStatus? status) {
    final liveVersion = status?.contentVersion;
    final lastSentVersion = screen.lastContentVersion;

    if (liveVersion != null) {
      return 'Live-Version: $liveVersion';
    }

    if (lastSentVersion != null) {
      return 'Letzte gesendete Version: $lastSentVersion';
    }

    return 'Version unbekannt';
  }

  Widget _buildScreenCard(ScreenDevice screen, {required bool isRecent}) {
    final status = screenStatuses[screen.ip];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          child: Icon(
            isRecent ? Icons.star : Icons.tv,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(screen.name),
            ),
            const SizedBox(width: 8),
            _buildStatusDot(status),
          ],
        ),
        subtitle: Text(
          '${screen.ip}\n'
          '${_buildStatusText(status)}\n'
          '${screen.orientation == 'portrait' ? 'Portrait' : 'Landscape'}\n'
          '${_lastSentLabel(screen.lastContentSentAt)}\n'
          '${_buildVersionText(screen, status)}\n'
          '${_lastUsedLabel(screen.lastOpenedAt)}',
        ),
        isThreeLine: false,
        onTap: () => openScreen(screen),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => showOptions(screen),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Screens'),
        actions: [
          IconButton(
            onPressed: (isRefreshingStatus || isDiscoveringScreens)
                ? null
                : refreshStatuses,
            icon: (isRefreshingStatus || isDiscoveringScreens)
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: screens.isEmpty
          ? const Center(
              child: Text('Keine Screens vorhanden'),
            )
          : ListView.builder(
              itemCount: screens.length,
              itemBuilder: (context, index) {
                final screen = screens[index];
                return _buildScreenCard(
                  screen,
                  isRecent: index == 0 && screen.lastOpenedAt != null,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: addScreen,
        child: const Icon(Icons.add),
      ),
    );
  }
}
