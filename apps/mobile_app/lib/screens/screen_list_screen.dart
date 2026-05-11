import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/screen.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_chalk_style.dart';
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
  String appVersion = '';

  final Map<String, ScreenStatus?> screenStatuses = {};
  Timer? statusRefreshTimer;
  DateTime? lastDiscoveryAt;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    loadScreens();
    _startAutoRefresh();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      appVersion = 'v${info.version}';
    });
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
    return DateTime.now().difference(lastDiscoveryAt!).inSeconds >= 20;
  }

  Future<void> _discoverScreensInCurrentNetwork({bool force = false}) async {
    if (!_shouldRunDiscovery(force: force)) return;
    if (!mounted) return;
    setState(() => isDiscoveringScreens = true);
    lastDiscoveryAt = DateTime.now();

    try {
      final subnetPrefix = await _getLocalSubnetPrefix();
      if (subnetPrefix == null) return;

      final ownIp = await _getLocalIpv4();
      final candidates = <String>[];
      for (int i = 1; i <= 254; i++) {
        final ip = '$subnetPrefix.$i';
        if (ip != ownIp) candidates.add(ip);
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

          await storage.addOrUpdateScreen(
            ScreenDevice(
              ip: ip,
              name: _resolveScreenName(info.screenName, info.deviceId, ip),
              orientation: resolvedOrientation,
              deviceId: info.deviceId,
            ),
          );
          foundCount++;
        }
      }

      if (foundCount > 0) await _reloadFromStorage();
    } finally {
      if (mounted) setState(() => isDiscoveringScreens = false);
    }
  }

  String _resolveScreenName(String? liveName, String? deviceId, String ip) {
    final trimmed = liveName?.trim() ?? '';
    if (trimmed.isNotEmpty && !_isGenericFallbackName(trimmed)) return trimmed;
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
    return RegExp(r'^Screen(\s+[A-Z0-9\.\-]{3,})?$', caseSensitive: false)
        .hasMatch(normalized);
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
          if (!ip.startsWith('127.') && !ip.startsWith('169.254.')) return ip;
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
    setState(() => isRefreshingStatus = true);

    if (runDiscovery) {
      await _discoverScreensInCurrentNetwork();
      await _reloadFromStorage();
    }

    for (final screen in screens) {
      final api = ApiService('http://${screen.ip}:8080');
      final status = await api.getStatus();
      if (!mounted) return;
      setState(() => screenStatuses[screen.ip] = status);
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
        setState(() => screenStatuses[screen.ip] = status);
      }
    }

    if (mounted) setState(() => isRefreshingStatus = false);
  }

  void _startAutoRefresh() {
    statusRefreshTimer?.cancel();
    statusRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || isLoading || isRefreshingStatus) return;
      refreshStatuses();
    });
  }

  void _stopAutoRefresh() {
    statusRefreshTimer?.cancel();
    statusRefreshTimer = null;
  }

  Future<void> _openMyTemplatesQuickAccess() async {
    if (screens.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte zuerst einen Screen hinzufügen oder im gleichen WLAN finden lassen.'),
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
      MaterialPageRoute(builder: (_) => const PairingScreen()),
    ).then((_) => loadScreens());
  }

  Future<void> reconnectScreen(ScreenDevice screen) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PairingScreen(initialScreen: screen)),
    );
    await loadScreens();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wenn der Screen im selben Netz ist, wird seine IP jetzt automatisch oder per QR-Scan aktualisiert.'),
      ),
    );
  }

  void showOptions(ScreenDevice screen) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.52),
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: chalkCreamSoft.withOpacity(0.98),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.52), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.34),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSheetAction(
                icon: Icons.edit_rounded,
                label: 'Umbenennen',
                onTap: () {
                  Navigator.pop(context);
                  renameScreen(screen);
                },
              ),
              _buildSheetAction(
                icon: Icons.sync_rounded,
                label: 'Screen neu verbinden / IP aktualisieren',
                onTap: () {
                  Navigator.pop(context);
                  reconnectScreen(screen);
                },
              ),
              _buildSheetAction(
                icon: Icons.delete_outline_rounded,
                label: 'Screen löschen',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  deleteScreen(screen);
                },
              ),
              _buildSheetAction(
                icon: Icons.link_off_rounded,
                label: 'Screen entkoppeln',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  unpairScreen(screen);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final accent = isDestructive ? const Color(0xFF9B2D2D) : chalkText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? const Color(0xFFFFE8E4)
                        : Colors.white.withOpacity(0.56),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _chalkDialogButtonStyle({bool destructive = false}) {
    return ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: destructive ? const Color(0xFF9B2D2D) : chalkCream,
      foregroundColor: destructive ? Colors.white : chalkText,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    );
  }

  AlertDialog _chalkDialog({
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) {
    return AlertDialog(
      backgroundColor: chalkCreamSoft,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(
        title,
        style: const TextStyle(
          color: chalkText,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: content,
      actions: actions,
    );
  }

  void renameScreen(ScreenDevice screen) {
    final controller = TextEditingController(text: screen.name);
    showDialog(
      context: context,
      builder: (_) => _chalkDialog(
        title: 'Screen umbenennen',
        content: TextField(
          controller: controller,
          cursorColor: chalkText,
          decoration: InputDecoration(
            labelText: 'Neuer Name',
            labelStyle: TextStyle(color: chalkMutedText.withOpacity(0.9)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.58),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: chalkMutedText.withOpacity(0.24)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: chalkCream, width: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: chalkMutedText),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: _chalkDialogButtonStyle(),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              final api = ApiService('http://${screen.ip}:8080');
              final result = await api.setScreenName(newName);
              if (!mounted) return;
              if (!result.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.error ?? 'Screen-Name konnte nicht gespeichert werden')),
                );
                return;
              }
              final storage = StorageService();
              await storage.addOrUpdateScreen(screen.copyWith(name: newName));
              if (!mounted) return;
              Navigator.pop(context);
              await loadScreens();
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
      builder: (_) => _chalkDialog(
        title: 'Screen löschen',
        content: Text(
          'Soll "${screen.name}" wirklich aus der App gelöscht werden?',
          style: TextStyle(color: chalkMutedText.withOpacity(0.95), height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: chalkMutedText),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: _chalkDialogButtonStyle(destructive: true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final storage = StorageService();
    await storage.deleteScreenByDeviceIdOrIp(deviceId: screen.deviceId, ip: screen.ip);
    await loadScreens();
  }

  Future<void> unpairScreen(ScreenDevice screen) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _chalkDialog(
        title: 'Screen entkoppeln',
        content: Text(
          'Soll "${screen.name}" wirklich entkoppelt werden?\n\nAm Screen werden Pairing und Content entfernt.',
          style: TextStyle(color: chalkMutedText.withOpacity(0.95), height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: chalkMutedText),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: _chalkDialogButtonStyle(destructive: true),
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
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screen konnte nicht entkoppelt werden')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Entkoppeln: $e')),
      );
    }
  }

  String _formatRelativeActivity(DateTime? dateTime) {
    if (dateTime == null) return 'noch nie';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std';
    if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '$day.$month.${dateTime.year}';
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
    if (status != null && status.isReachable && !status.isPaired) return 'Kein aktives Pairing';
    final liveContentName = status?.contentName?.trim();
    if (liveContentName != null && liveContentName.isNotEmpty) return liveContentName;
    final lastContentName = screen.lastContentName?.trim();
    if (lastContentName != null && lastContentName.isNotEmpty) return lastContentName;
    return 'Kein Inhalt bekannt';
  }

  Widget _buildStatusMeta(ScreenDevice screen, ScreenStatus? status) {
    final orientationLabel = screen.orientation == 'portrait' ? 'Portrait' : 'Landscape';
    final statusText = _buildStatusText(status);
    final isOnline = status?.isOnline == true;
    final isUnpaired = status != null && status.isReachable && !status.isPaired;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChalkPill(
          label: statusText,
          icon: isUnpaired
              ? Icons.link_off_rounded
              : isOnline
                  ? Icons.check_circle_rounded
                  : Icons.circle_rounded,
          background: isUnpaired
              ? const Color(0xFFFFF0D6)
              : isOnline
                  ? const Color(0xFFE5F7ED)
                  : const Color(0xFFFFE8E6),
          foreground: isUnpaired
              ? const Color(0xFF9A6400)
              : isOnline
                  ? const Color(0xFF18764C)
                  : const Color(0xFFB83C35),
        ),
        ChalkPill(
          label: orientationLabel,
          icon: screen.orientation == 'portrait'
              ? Icons.stay_current_portrait_rounded
              : Icons.stay_current_landscape_rounded,
          background: const Color(0xFFF2F0EA),
          foreground: const Color(0xFF5D5549),
        ),
      ],
    );
  }

  Widget _buildScreenCard(ScreenDevice screen, {required bool isRecent}) {
    final status = screenStatuses[screen.ip];
    final contentLabel = _buildContentNameText(screen, status);
    final activityLabel = _formatRelativeActivity(_resolveLastActivity(screen));

    return ChalkCard(
      onTap: () => openScreen(screen),
      opacity: status?.isOnline == false ? 0.90 : 0.96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isRecent ? chalkCream.withOpacity(0.92) : const Color(0xFFF1EEE7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isRecent ? Icons.star_rounded : Icons.monitor_rounded,
                  color: isRecent ? const Color(0xFF7A5E2C) : const Color(0xFF66736C),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      screen.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: chalkText,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      screen.ip,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(top: 4), child: _buildStatusDot(status)),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => showOptions(screen),
                visualDensity: VisualDensity.compact,
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 13),
          _buildStatusMeta(screen, status),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F5EF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aktueller Inhalt',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contentLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: status?.isOnline == false ? Colors.grey.shade700 : chalkText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  activityLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_tethering_rounded, size: 72, color: chalkCream),
            const SizedBox(height: 18),
            const Text(
              'Keine Screens gespeichert',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              'Die App sucht automatisch nach erreichbaren Screens im gleichen WLAN. Du kannst jederzeit auch manuell einen Screen koppeln.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.78)),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: (isRefreshingStatus || isDiscoveringScreens) ? null : () => refreshStatuses(),
              icon: (isRefreshingStatus || isDiscoveringScreens)
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded),
              label: const Text('Erneut suchen'),
              style: OutlinedButton.styleFrom(foregroundColor: chalkCream),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: addScreen,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Screen manuell hinzufügen'),
              style: TextButton.styleFrom(foregroundColor: chalkCream),
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
        backgroundColor: chalkInk,
        body: Center(child: CircularProgressIndicator(color: chalkCream)),
      );
    }

    return Scaffold(
      backgroundColor: chalkInk,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: chalkInk,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 18,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icon_studio.png',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TafelFix Studio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: chalkCream,
                      height: 1.05,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Meine Screens',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFD8D2C6),
                      fontWeight: FontWeight.w600,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: (isRefreshingStatus || isDiscoveringScreens) ? null : refreshStatuses,
            icon: (isRefreshingStatus || isDiscoveringScreens)
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: chalkCream),
                  )
                : const Icon(Icons.refresh_rounded, color: chalkCream),
          ),
        ],
      ),
      body: ChalkBackground(
        child: screens.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 108),
                itemCount: screens.length,
                itemBuilder: (context, index) {
                  final screen = screens[index];
                  return _buildScreenCard(
                    screen,
                    isRecent: index == 0 && screen.lastOpenedAt != null,
                  );
                },
              ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      appVersion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFA89F8E),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Text(
                    '© Greenbird.fm',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFA89F8E),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.28),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: addScreen,
                      icon: const Icon(Icons.add_to_photos_rounded, size: 18),
                      label: const Text('Screen hinzufügen'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: chalkText,
                        side: const BorderSide(color: Color(0xFFE1D8C9)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _openMyTemplatesQuickAccess,
                      icon: const Icon(Icons.folder_copy_rounded, size: 18),
                      label: const Text('Meine Vorlagen'),
                      style: FilledButton.styleFrom(
                        backgroundColor: chalkCream,
                        foregroundColor: chalkText,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
