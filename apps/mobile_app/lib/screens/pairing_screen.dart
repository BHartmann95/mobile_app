import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/screen.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_chalk_style.dart';

class PairingScreen extends StatefulWidget {
  final Future<void> Function()? onPairedComplete;
  final ScreenDevice? initialScreen;

  const PairingScreen({
    super.key,
    this.onPairedComplete,
    this.initialScreen,
  });

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingInfoData {
  final String screenName;
  final String orientation;

  const _PairingInfoData({
    required this.screenName,
    required this.orientation,
  });
}

class _PairingScreenState extends State<PairingScreen> {
  final ipController = TextEditingController();
  final codeController = TextEditingController();
  final nameController = TextEditingController();

  String orientation = 'landscape';
  String? detectedDeviceId;

  bool isLoading = false;
  bool isScannerOpen = false;
  bool isHandlingScan = false;
  String? error;

  @override
  void initState() {
    super.initState();

    final initialScreen = widget.initialScreen;
    if (initialScreen != null) {
      ipController.text = initialScreen.ip;
      nameController.text = initialScreen.name;
      orientation = initialScreen.orientation;
      detectedDeviceId = initialScreen.deviceId;
    }
  }

  bool get _isReconnectFlow => widget.initialScreen != null;

  Future<void> pair() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final ip = ipController.text.trim();
      final code = codeController.text.trim();
      final typedName = nameController.text.trim();
      final name = typedName.isNotEmpty
          ? typedName
          : (widget.initialScreen?.name.trim() ?? '');

      if (ip.isEmpty || code.isEmpty || name.isEmpty) {
        setState(() {
          error = 'Bitte alle Felder ausfüllen';
          isLoading = false;
        });
        return;
      }

      final api = ApiService('http://$ip:8080');

      final success = await api.pairDevice(
        pairingCode: code,
        screenName: name,
        orientation: orientation,
      );

      if (!mounted) return;

      if (success) {
        await _persistPairedScreen(
          ip: ip,
          name: name,
          orientation: orientation,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isReconnectFlow
                  ? '"$name" wurde erneut verbunden'
                  : '"$name" wurde erfolgreich gekoppelt',
            ),
          ),
        );

        if (Navigator.of(context).canPop()) {
          Navigator.pop(context, true);
        } else if (widget.onPairedComplete != null) {
          await widget.onPairedComplete!.call();
        }
      } else {
        setState(() {
          error = 'Pairing fehlgeschlagen';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'Fehler: $e';
      });
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _persistPairedScreen({
    required String ip,
    required String name,
    required String orientation,
  }) async {
    final storage = StorageService();
    final initialScreen = widget.initialScreen;
    final resolvedDeviceId =
        (detectedDeviceId != null && detectedDeviceId!.trim().isNotEmpty)
            ? detectedDeviceId!.trim()
            : initialScreen?.deviceId;

    if (initialScreen != null) {
      await storage.deleteScreenByDeviceIdOrIp(
        deviceId: initialScreen.deviceId,
        ip: initialScreen.ip,
      );
    }

    await storage.addOrUpdateScreen(
      ScreenDevice(
        ip: ip,
        name: name,
        orientation: orientation,
        deviceId: resolvedDeviceId,
        lastOpenedAt: initialScreen?.lastOpenedAt,
        lastContentSentAt: initialScreen?.lastContentSentAt,
        lastContentVersion: initialScreen?.lastContentVersion,
      ),
    );
  }

  Future<void> _openQrScanner() async {
    if (isScannerOpen || isLoading) return;

    setState(() {
      error = null;
      isScannerOpen = true;
      isHandlingScan = false;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: Stack(
              children: [
                MobileScanner(
                  onDetect: (capture) async {
                    if (isHandlingScan) return;

                    final barcode =
                        capture.barcodes.isNotEmpty ? capture.barcodes.first : null;

                    final rawValue = barcode?.rawValue;
                    if (rawValue == null || rawValue.trim().isEmpty) return;

                    isHandlingScan = true;

                    try {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }

                      await _handleQrPayload(rawValue.trim());
                    } catch (e) {
                      if (!mounted) return;
                      setState(() {
                        error = 'QR konnte nicht verarbeitet werden: $e';
                      });
                      isHandlingScan = false;
                    }
                  },
                ),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 28,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.initialScreen == null
                            ? 'QR-Code am Screen scannen'
                            : 'QR-Code des bestehenden Screens erneut scannen',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'IP, Pairing Code und Screen-Infos werden automatisch übernommen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          child: const Text('Abbrechen'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() {
      isScannerOpen = false;
      isHandlingScan = false;
    });
  }

  Future<void> _handleQrPayload(String rawValue) async {
    final parsed = _parseQrPayload(rawValue);

    final ip = (parsed['ip'] ?? '').toString().trim();
    final pairingCode = (parsed['pairingCode'] ?? '').toString().trim();
    final qrScreenName = (parsed['screenName'] ?? '').toString().trim();
    final deviceId = (parsed['deviceId'] ?? '').toString().trim();
    final pairingInfoUrl = (parsed['pairingInfoUrl'] ?? '').toString().trim();
    final qrOrientation =
        (parsed['orientation'] ?? '').toString().trim().toLowerCase();

    if (ip.isEmpty || pairingCode.isEmpty) {
      throw Exception('IP oder Pairing Code fehlen im QR');
    }

    if (deviceId.isNotEmpty) {
      detectedDeviceId = deviceId;
    }

    ipController.text = ip;
    codeController.text = pairingCode;

    String resolvedOrientation = qrOrientation;
    String resolvedName = _isReconnectFlow
        ? (widget.initialScreen?.name.trim() ?? '')
        : qrScreenName;

    final liveInfo = await _fetchPairingInfoData(
      ip: ip,
      pairingInfoUrl: pairingInfoUrl,
      fallbackDeviceId: deviceId,
    );

    if (liveInfo.orientation == 'portrait' ||
        liveInfo.orientation == 'landscape') {
      resolvedOrientation = liveInfo.orientation;
    }

    if (_isReconnectFlow) {
      if (resolvedName.isEmpty) {
        resolvedName = widget.initialScreen?.name.trim() ?? '';
      }
    } else if (liveInfo.screenName.isNotEmpty) {
      resolvedName = liveInfo.screenName;
    }

    if (resolvedOrientation == 'portrait' || resolvedOrientation == 'landscape') {
      orientation = resolvedOrientation;
    }

    if (resolvedName.isEmpty) {
      resolvedName = widget.initialScreen?.name.isNotEmpty == true
          ? widget.initialScreen!.name
          : 'Screen ${ip.replaceAll('.', '-')}';
    }

    nameController.text = resolvedName;

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isReconnectFlow
              ? 'QR erkannt – bestehender Screen wird neu verbunden'
              : 'QR erkannt – ${orientation == 'portrait' ? 'Portrait' : 'Landscape'} übernommen',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    await pair();
  }

  Map<String, dynamic> _parseQrPayload(String rawValue) {
    try {
      final decoded = jsonDecode(rawValue);

      if (decoded is Map<String, dynamic>) {
        final type = decoded['type']?.toString();
        if (type != 'greenbird_pairing') {
          throw Exception('Unbekannter QR-Typ');
        }
        return decoded;
      }

      throw Exception('QR enthält kein gültiges Objekt');
    } catch (_) {
      throw Exception('QR enthält kein gültiges Greenbird-Pairing-Format');
    }
  }

  Future<_PairingInfoData> _fetchPairingInfoData({
    required String ip,
    required String pairingInfoUrl,
    required String fallbackDeviceId,
  }) async {
    final url =
        pairingInfoUrl.isNotEmpty ? pairingInfoUrl : 'http://$ip:8080/pairing-info';

    try {
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 4),
          );

      if (response.statusCode != 200) {
        return _PairingInfoData(
          screenName: _fallbackNameFromDeviceId(fallbackDeviceId),
          orientation: '',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return _PairingInfoData(
          screenName: _fallbackNameFromDeviceId(fallbackDeviceId),
          orientation: '',
        );
      }

      final screenName = decoded['screenName']?.toString().trim() ?? '';
      final deviceId = decoded['deviceId']?.toString().trim() ?? fallbackDeviceId;
      final orientation =
          decoded['orientation']?.toString().trim().toLowerCase() ?? '';

      if (deviceId.isNotEmpty) {
        detectedDeviceId = deviceId;
      }

      return _PairingInfoData(
        screenName:
            screenName.isNotEmpty ? screenName : _fallbackNameFromDeviceId(deviceId),
        orientation: orientation,
      );
    } catch (_) {
      return _PairingInfoData(
        screenName: _fallbackNameFromDeviceId(fallbackDeviceId),
        orientation: '',
      );
    }
  }

  String _fallbackNameFromDeviceId(String deviceId) {
    if (deviceId.isEmpty) return '';
    final suffix = deviceId.length > 6
        ? deviceId.substring(deviceId.length - 6).toUpperCase()
        : deviceId.toUpperCase();
    return 'Screen $suffix';
  }

  @override
  void dispose() {
    ipController.dispose();
    codeController.dispose();
    nameController.dispose();
    super.dispose();
  }

  InputDecoration _chalkInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: chalkMutedText.withOpacity(0.92),
        fontWeight: FontWeight.w700,
      ),
      filled: true,
      fillColor: chalkCreamSoft.withOpacity(0.96),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: chalkCream.withOpacity(0.55)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: chalkMutedText.withOpacity(0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: chalkText, width: 1.4),
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: chalkCream,
      foregroundColor: chalkText,
      disabledBackgroundColor: chalkCream.withOpacity(0.55),
      disabledForegroundColor: chalkText.withOpacity(0.45),
      elevation: 0,
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 15,
      ),
    );
  }

  ButtonStyle _secondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white.withOpacity(0.92),
      side: BorderSide(color: Colors.white.withOpacity(0.26)),
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
    );
  }

  Widget _orientationChip({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = orientation == value;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isLoading
            ? null
            : () {
                setState(() {
                  orientation = value;
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? chalkText : chalkCreamSoft.withOpacity(0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? chalkText
                  : chalkMutedText.withOpacity(0.18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? chalkCream : chalkMutedText,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? chalkCream : chalkText,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop();
    final title = widget.initialScreen == null
        ? 'Screen verbinden'
        : 'Screen neu verbinden';
    final subtitle = widget.initialScreen == null
        ? 'Scanne den QR-Code am Player oder gib die Daten manuell ein.'
        : 'Aktualisiere die Verbindung, wenn sich Netzwerk oder IP-Adresse geändert haben.';

    return Scaffold(
      backgroundColor: chalkInk,
      extendBodyBehindAppBar: false,
      appBar: chalkAppBar(title: title),
      body: ChalkBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.94),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.55),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.22),
                                  blurRadius: 26,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: chalkText,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Icon(
                                        widget.initialScreen == null
                                            ? Icons.add_to_queue_rounded
                                            : Icons.sync_rounded,
                                        color: chalkCream,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              color: chalkText,
                                              fontSize: 25,
                                              fontWeight: FontWeight.w900,
                                              height: 1.05,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            subtitle,
                                            style: TextStyle(
                                              color: chalkMutedText.withOpacity(0.92),
                                              fontSize: 14,
                                              height: 1.35,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: isLoading ? null : _openQrScanner,
                                    icon: const Icon(Icons.qr_code_scanner_rounded),
                                    label: Text(
                                      widget.initialScreen == null
                                          ? 'QR-Code scannen'
                                          : 'QR-Code erneut scannen',
                                    ),
                                    style: _primaryButtonStyle(),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: chalkMutedText.withOpacity(0.18),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        'oder manuell eingeben',
                                        style: TextStyle(
                                          color: chalkMutedText.withOpacity(0.82),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: chalkMutedText.withOpacity(0.18),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                TextField(
                                  controller: ipController,
                                  keyboardType: TextInputType.url,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(
                                    color: chalkText,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  cursorColor: chalkText,
                                  decoration: _chalkInputDecoration('IP-Adresse'),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: codeController,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.characters,
                                  style: const TextStyle(
                                    color: chalkText,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                  cursorColor: chalkText,
                                  decoration: _chalkInputDecoration('Pairing Code'),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: nameController,
                                  textInputAction: TextInputAction.done,
                                  style: const TextStyle(
                                    color: chalkText,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  cursorColor: chalkText,
                                  decoration: _chalkInputDecoration('Screen Name'),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Ausrichtung',
                                  style: TextStyle(
                                    color: chalkMutedText.withOpacity(0.95),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _orientationChip(
                                      value: 'landscape',
                                      label: 'Landscape',
                                      icon: Icons.stay_current_landscape_rounded,
                                    ),
                                    const SizedBox(width: 10),
                                    _orientationChip(
                                      value: 'portrait',
                                      label: 'Portrait',
                                      icon: Icons.stay_current_portrait_rounded,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Aktuell: ${orientation == 'portrait' ? 'Portrait' : 'Landscape'}',
                                  style: TextStyle(
                                    color: chalkMutedText.withOpacity(0.78),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (error != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF9B2D2D).withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0xFF9B2D2D).withOpacity(0.22),
                                      ),
                                    ),
                                    child: Text(
                                      error!,
                                      style: const TextStyle(
                                        color: Color(0xFF8E2323),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 22),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : pair,
                                    style: _primaryButtonStyle(),
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: chalkText,
                                            ),
                                          )
                                        : Text(
                                            widget.initialScreen == null
                                                ? 'Verbinden'
                                                : 'Neu verbinden',
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canGoBack) ...[
                            const SizedBox(height: 14),
                            OutlinedButton(
                              onPressed: isLoading ? null : () => Navigator.pop(context),
                              style: _secondaryButtonStyle(),
                              child: const Text('Zurück'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
