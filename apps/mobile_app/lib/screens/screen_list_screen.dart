import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../models/screen.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'pairing_screen.dart';
import 'screen_dashboard.dart';
import 'content_library_screen.dart';

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

    await _discoverScreensInCurrentNetwork(force: true);
    await _reloadFromStorage();
    await refreshStatuses(runDiscovery: false);
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

  bool _shouldRunDiscovery({bool force = false}) {
    if (force) return true;
    if (isDiscoveringScreens) return false;

    if (lastDiscoveryAt == null) return true;

    final diff = DateTime.now().difference(lastDiscoveryAt!);
    return diff.inSeconds >= 20;
  }

  Future<void> _discoverScreensInCurrentNetwork({bool force = false}) async {
    if (!_shouldRunDiscovery(force: force)) return;

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

      int foundCount = 0;
      final storage = StorageService();

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
          final ip = result.key;
          final info = result.value;

          if (!info.success) continue;

          final resolvedOrientation =
              (info.orientation == 'portrait' || info.orientation == 'landscape')
                  ? info.orientation!
                  : 'landscape';

          final resolvedName = _resolveScreenName(
            info.screenName,
            info.deviceId,
            ip,
          );

          await storage.addOrUpdateScreen(
            ScreenDevice(
              ip: ip,
              name: resolvedName,
              orientation: resolvedOrientation,
              deviceId: info.deviceId,
            ),
          );

          foundCount++;
        }
      }

      if (foundCount > 0) {
        await _reloadFromStorage();
      }
    } finally {
      if (!mounted) return;
      setState(() {
        isDiscoveringScreens = false;
      });
    }
  }

  String _resolveScreenName(String? liveName, String? deviceId, String ip) {
    final trimmed = liveName?.trim() ?? '';
    if (trimmed.isNotEmpty && !_isGenericFallbackName(trimmed)) {
      return trimmed;
    }

    if (deviceId != null && deviceId.trim().isNotEmpty) {
      final suffix = deviceId.trim();
      final shortSuffix = suffix.length > 6 ? suffix.substring(0, 6) : suffix;
      return 'Screen $shortSuffix';
    }

    return 'Screen $ip';
  }

  bool _isGenericFallbackName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return false;

    final genericPattern = RegExp(
      r'^Screen(\s+[A-Z0-9\.\-]{3,})?$',
      caseSensitive: false,
    );
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

  Future<void> refreshStatuses({bool runDiscovery = true}) async {
    if (isRefreshingStatus) return;

    if (!mounted) return;
    setState(() {
      isRefreshingStatus = true;
    });

    if (runDiscovery) {
      await _discoverScreensInCurrentNetwork();
      await _reloadFromStorage();
    }

    if (screens.isEmpty) {
      if (!mounted) return;
      setState(() {
        isRefreshingStatus = false;
      });
      return;
    }

    for (final screen in screens) {
      final api = ApiService('http://${screen.ip}:8080');
      final status = await api.getStatus();

      if (!mounted) return;
      setState(() {
        screenStatuses[screen.ip] = status;
      });
    }

    final hasOfflineOrMovedScreens = screens.any((screen) {
      final status = screenStatuses[screen.ip];
      return status == null || !status.isReachable;
    });

    if (hasOfflineOrMovedScreens && runDiscovery) {
      await _discoverScreensInCurrentNetwork(force: true);
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
        if (!mounted || isLoading || isRefreshingStatus) {
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

  Future<void> _openContentLibraryQuickAccess() async {
    if (screens.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bitte zuerst einen Screen hinzufügen oder im gleichen WLAN finden lassen.',
          ),
        ),
      );
      return;
    }

    final defaultScreen = screens.first;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContentLibraryScreen(
          ip: defaultScreen.ip,
          screenName: defaultScreen.name,
          screenOrientation: defaultScreen.orientation,
        ),
      ),
    );

    await loadScreens();
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
                      result.error ??
                          'Screen-Name konnte nicht gespeichert werden',
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
          'Der Screen bleibt in deiner Liste sichtbar und kann danach direkt neu gekoppelt werden.\n'
          'Am Screen selbst werden Pairing und Content entfernt.',
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
        if (!mounted) return;

        setState(() {
          screenStatuses[screen.ip] = const ScreenStatus(
            isOnline: false,
            isPaired: false,
            isReachable: false,
          );
        });

        await loadScreens();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${screen.name}" wurde entkoppelt und bleibt für neues Pairing in der Liste sichtbar',
            ),
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


  String _formatRelativeActivity(DateTime? dateTime) {
    if (dateTime == null) {
      return 'noch nie';
    }

    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'gerade eben';
    }
    if (diff.inMinutes < 60) {
      return 'vor ${diff.inMinutes} Min';
    }
    if (diff.inHours < 24) {
      return 'vor ${diff.inHours} Std';
    }
    if (diff.inHours < 48) {
      return 'gestern';
    }

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    return '$day.$month.$year';
  }

  DateTime? _resolveLastActivity(ScreenDevice screen) {
    return screen.lastOpenedAt ?? screen.lastContentSentAt;
  }

  Widget _buildStatusDot(ScreenStatus? status) {
    if (status == null) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (status.isReachable && !status.isPaired) {
      return Icon(Icons.circle, size: 12, color: Colors.orange.shade400);
    }

    return Icon(
      Icons.circle,
      size: 12,
      color: status.isOnline ? Colors.green.shade400 : Colors.red.shade300,
    );
  }

  String _buildStatusText(ScreenStatus? status) {
    if (status == null) return 'Wird geprüft';
    if (status.isReachable && !status.isPaired) return 'Nicht gekoppelt';
    return status.isOnline ? 'Online' : 'Offline';
  }

  String _buildContentNameText(ScreenDevice screen, ScreenStatus? status) {
    if (status != null && status.isReachable && !status.isPaired) {
      return 'Kein aktives Pairing';
    }

    final liveContentName = status?.contentName?.trim();
    if (liveContentName != null && liveContentName.isNotEmpty) {
      return liveContentName;
    }

    final lastContentName = screen.lastContentName?.trim();
    if (lastContentName != null && lastContentName.isNotEmpty) {
      return lastContentName;
    }

    return 'Kein Inhalt bekannt';
  }

  Widget _buildStatusMeta(ScreenDevice screen, ScreenStatus? status) {
    final orientationLabel =
        screen.orientation == 'portrait' ? 'Portrait' : 'Landscape';

    return Text(
      '${_buildStatusText(status)} • $orientationLabel',
      style: TextStyle(
        fontSize: 13,
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildScreenCard(ScreenDevice screen, {required bool isRecent}) {
    final status = screenStatuses[screen.ip];
    final contentLabel = _buildContentNameText(screen, status);
    final activityLabel = _formatRelativeActivity(_resolveLastActivity(screen));
    final cardColor = status?.isOnline == false
        ? Colors.grey.shade50
        : Theme.of(context).cardColor;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1.5,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openScreen(screen),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.deepPurple.shade50,
                    child: Icon(
                      isRecent ? Icons.star : Icons.tv_outlined,
                      color: Colors.deepPurple.shade300,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          screen.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          screen.ip,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _buildStatusDot(status),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => showOptions(screen),
                    visualDensity: VisualDensity.compact,
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildStatusMeta(screen, status),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      contentLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: status?.isOnline == false
                            ? Colors.grey.shade700
                            : Colors.grey.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    activityLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPrimaryActionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.send_outlined),
                title: const Text('Inhalt senden'),
                subtitle: const Text('Gespeicherte Inhalte an einen Screen senden'),
                onTap: () {
                  Navigator.pop(context);
                  _openContentLibraryQuickAccess();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_to_photos_outlined),
                title: const Text('Neuen Screen hinzufügen'),
                subtitle: const Text('Screen koppeln oder erneut verbinden'),
                onTap: () {
                  Navigator.pop(context);
                  addScreen();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_tethering,
              size: 72,
              color: Colors.blueGrey.shade300,
            ),
            const SizedBox(height: 18),
            const Text(
              'Keine Screens gespeichert',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Die App sucht automatisch nach erreichbaren Screens im gleichen WLAN. Du kannst jederzeit auch manuell einen Screen koppeln.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: (isRefreshingStatus || isDiscoveringScreens)
                  ? null
                  : () => refreshStatuses(),
              icon: (isRefreshingStatus || isDiscoveringScreens)
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Erneut suchen'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: addScreen,
              icon: const Icon(Icons.add),
              label: const Text('Screen manuell hinzufügen'),
            ),
          ],
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
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: screens.length,
              itemBuilder: (context, index) {
                final screen = screens[index];
                return _buildScreenCard(
                  screen,
                  isRecent: index == 0 && screen.lastOpenedAt != null,
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'primary_screen_action_fab',
        onPressed: _showPrimaryActionSheet,
        icon: const Icon(Icons.send_outlined),
        label: const Text('Inhalt senden'),
      ),
    );
  }
}
