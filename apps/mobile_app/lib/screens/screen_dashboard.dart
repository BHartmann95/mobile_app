import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/saved_content.dart';
import '../services/api_service.dart';
import '../services/content_storage_service.dart';
import 'template_selection_screen.dart';
import 'content_library_screen.dart';
import 'template_editor_screen.dart';
import '../widgets/app_chalk_style.dart';

class ScreenDashboardPage extends StatefulWidget {
  final String ip;
  final String screenName;
  final String screenOrientation;

  const ScreenDashboardPage({
    super.key,
    required this.ip,
    required this.screenName,
    required this.screenOrientation,
  });

  @override
  State<ScreenDashboardPage> createState() => _ScreenDashboardPageState();
}

class _ScreenDashboardPageState extends State<ScreenDashboardPage> {
  String appVersion = '';
  bool isOpeningCurrentContent = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();

    if (!mounted) return;

    setState(() {
      appVersion = 'v${info.version}';
    });
  }

  void _openTemplateSelection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateSelectionScreen(
          ip: widget.ip,
          screenName: widget.screenName,
          screenOrientation: widget.screenOrientation,
        ),
      ),
    );
  }

  void _openContentLibrary(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContentLibraryScreen(
          ip: widget.ip,
          screenName: widget.screenName,
          screenOrientation: widget.screenOrientation,
        ),
      ),
    );
  }

  Future<SavedContent?> _loadLocallyAssignedContent() async {
    final storage = ContentStorageService();
    final contents = await storage.loadContents();

    final matches = contents.where((content) => content.lastUsedScreenIp == widget.ip).toList();

    if (matches.isEmpty) {
      return null;
    }

    matches.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return matches.first;
  }

  Future<ScreenContentResult> _loadCurrentScreenContentLive() async {
    final api = ApiService('http://${widget.ip}:8080');

    return api.getCurrentContent(
      fallbackName: widget.screenName,
      fallbackOrientation: widget.screenOrientation,
      stableContentId: 'screen_content_${widget.ip}',
    );
  }

  Future<void> _openAssignedContentEditor(BuildContext context) async {
    if (isOpeningCurrentContent) return;

    setState(() {
      isOpeningCurrentContent = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final liveResult = await _loadCurrentScreenContentLive();

      if (!context.mounted) return;

      if (liveResult.success && liveResult.savedContent != null) {
        final liveContent = liveResult.savedContent!;

        final storage = ContentStorageService();
        await storage.addOrUpdateContent(liveContent);

        if (!context.mounted) return;

        setState(() {
          isOpeningCurrentContent = false;
        });

        navigator.push(
          MaterialPageRoute(
            builder: (_) => TemplateEditorScreen(
              ip: widget.ip,
              screenName: widget.screenName,
              screenOrientation: widget.screenOrientation,
              templateType: liveContent.slides.isNotEmpty
                  ? liveContent.slides.first.templateType
                  : liveContent.templateType!,
              initialContent: liveContent,
            ),
          ),
        );
        return;
      }

      final assigned = await _loadLocallyAssignedContent();

      if (!context.mounted) return;

      if (assigned != null) {
        setState(() {
          isOpeningCurrentContent = false;
        });

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              liveResult.error == null || liveResult.error!.trim().isEmpty
                  ? 'Live-Inhalt konnte nicht geladen werden. Lokale Version wird geöffnet.'
                  : 'Live-Inhalt konnte nicht geladen werden (${liveResult.error}). Lokale Version wird geöffnet.',
            ),
          ),
        );

        navigator.push(
          MaterialPageRoute(
            builder: (_) => TemplateEditorScreen(
              ip: widget.ip,
              screenName: widget.screenName,
              screenOrientation: widget.screenOrientation,
              templateType: assigned.slides.isNotEmpty
                  ? assigned.slides.first.templateType
                  : assigned.templateType!,
              initialContent: assigned,
            ),
          ),
        );
        return;
      }

      setState(() {
        isOpeningCurrentContent = false;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            liveResult.error == null || liveResult.error!.trim().isEmpty
                ? 'Am Screen ist aktuell kein gespeicherter Inhalt vorhanden.'
                : 'Kein aktueller Screen-Inhalt verfügbar: ${liveResult.error}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        isOpeningCurrentContent = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Screen-Inhalt konnte nicht geladen werden: $e')),
      );
    }
  }

  Widget _buildInfoCard() {
    final orientationLabel =
        widget.screenOrientation == 'portrait' ? 'Portrait' : 'Landscape';

    return ChalkCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: chalkCream.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.monitor_rounded,
              size: 31,
              color: chalkText,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.screenName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: chalkText,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChalkPill(
                      label: widget.ip,
                      icon: Icons.wifi_rounded,
                      background: const Color(0xFFF2F0EA),
                      foreground: const Color(0xFF5D5549),
                    ),
                    ChalkPill(
                      label: orientationLabel,
                      icon: widget.screenOrientation == 'portrait'
                          ? Icons.stay_current_portrait_rounded
                          : Icons.stay_current_landscape_rounded,
                      background: const Color(0xFFE5F7ED),
                      foreground: const Color(0xFF18764C),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Inhalt bearbeiten, Vorlagen erstellen oder senden.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Colors.grey.shade700,
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

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool primary,
  }) {
    return ChalkCard(
      margin: EdgeInsets.zero,
      opacity: primary ? 1 : 0.96,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: primary ? chalkInk : const Color(0xFFF1EEE7),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              size: 28,
              color: primary ? chalkCream : const Color(0xFF66736C),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: chalkText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.25,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 17, color: Color(0xFF7A766F)),
        ],
      ),
    );
  }


  PreferredSizeWidget _buildBrandedAppBar() {
    return brandedChalkAppBar(title: 'TafelFix Studio', subtitle: 'Screen Dashboard');
  }

  Widget _buildAppFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          appVersion.isEmpty ? 'v...' : appVersion,
          style: const TextStyle(
            color: Color(0xFFA89F8E),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Text(
          '© Greenbird.fm',
          style: TextStyle(
            color: Color(0xFFA89F8E),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chalkInk,
      appBar: _buildBrandedAppBar(),
      body: ChalkBackground(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: [
            _buildInfoCard(),
            const SizedBox(height: 22),
            _buildActionCard(
              icon: Icons.edit_note_rounded,
              title: 'Aktuellen Screen-Inhalt bearbeiten',
              subtitle: 'Live-Inhalt laden und bearbeiten',
              onTap: () => _openAssignedContentEditor(context),
              primary: true,
            ),
            const SizedBox(height: 14),
            _buildActionCard(
              icon: Icons.add_circle_outline_rounded,
              title: 'Neue Vorlage erstellen',
              subtitle: 'Neue Inhalte gestalten',
              onTap: () => _openTemplateSelection(context),
              primary: false,
            ),
            const SizedBox(height: 14),
            _buildActionCard(
              icon: Icons.folder_copy_rounded,
              title: 'Meine Vorlagen',
              subtitle: 'Vorlagen öffnen oder senden',
              onTap: () => _openContentLibrary(context),
              primary: false,
            ),
            const SizedBox(height: 28),
                _buildAppFooter(),
              ],
            ),
            if (isOpeningCurrentContent)
              Container(
                color: Colors.black.withOpacity(0.34),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                    decoration: BoxDecoration(
                      color: chalkCreamSoft.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.6, color: chalkText),
                        ),
                        SizedBox(width: 14),
                        Text(
                          'Screen-Inhalt wird geladen …',
                          style: TextStyle(color: chalkText, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

}
