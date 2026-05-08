import 'package:flutter/material.dart';
import '../models/saved_content.dart';
import '../services/api_service.dart';
import '../services/content_storage_service.dart';
import 'template_selection_screen.dart';
import 'content_library_screen.dart';
import 'template_editor_screen.dart';
import '../widgets/app_chalk_style.dart';

class ScreenDashboardPage extends StatelessWidget {
  final String ip;
  final String screenName;
  final String screenOrientation;

  const ScreenDashboardPage({
    super.key,
    required this.ip,
    required this.screenName,
    required this.screenOrientation,
  });

  void _openTemplateSelection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateSelectionScreen(
          ip: ip,
          screenName: screenName,
          screenOrientation: screenOrientation,
        ),
      ),
    );
  }

  void _openContentLibrary(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContentLibraryScreen(
          ip: ip,
          screenName: screenName,
          screenOrientation: screenOrientation,
        ),
      ),
    );
  }

  Future<SavedContent?> _loadLocallyAssignedContent() async {
    final storage = ContentStorageService();
    final contents = await storage.loadContents();

    final matches = contents.where((content) => content.lastUsedScreenIp == ip).toList();

    if (matches.isEmpty) {
      return null;
    }

    matches.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return matches.first;
  }

  Future<ScreenContentResult> _loadCurrentScreenContentLive() async {
    final api = ApiService('http://$ip:8080');

    return api.getCurrentContent(
      fallbackName: screenName,
      fallbackOrientation: screenOrientation,
      stableContentId: 'screen_content_$ip',
    );
  }

  Future<void> _openAssignedContentEditor(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final liveResult = await _loadCurrentScreenContentLive();

    if (!context.mounted) return;

    if (liveResult.success && liveResult.savedContent != null) {
      final liveContent = liveResult.savedContent!;

      final storage = ContentStorageService();
      await storage.addOrUpdateContent(liveContent);

      if (!context.mounted) return;

      navigator.push(
        MaterialPageRoute(
          builder: (_) => TemplateEditorScreen(
            ip: ip,
            screenName: screenName,
            screenOrientation: screenOrientation,
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            liveResult.error == null || liveResult.error!.trim().isEmpty
                ? 'Live-Inhalt vom Screen konnte nicht geladen werden. Es wird der lokal gespeicherte Inhalt geöffnet.'
                : 'Live-Inhalt vom Screen konnte nicht geladen werden (${liveResult.error}). Es wird der lokal gespeicherte Inhalt geöffnet.',
          ),
        ),
      );

      navigator.push(
        MaterialPageRoute(
          builder: (_) => TemplateEditorScreen(
            ip: ip,
            screenName: screenName,
            screenOrientation: screenOrientation,
            templateType: assigned.slides.isNotEmpty
                ? assigned.slides.first.templateType
                : assigned.templateType!,
            initialContent: assigned,
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          liveResult.error == null || liveResult.error!.trim().isEmpty
              ? 'Am Screen ist aktuell kein gespeicherter Inhalt vorhanden.'
              : 'Kein aktueller Screen-Inhalt verfügbar: ${liveResult.error}',
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final orientationLabel =
        screenOrientation == 'portrait' ? 'Portrait' : 'Landscape';

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
                  screenName,
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
                      label: ip,
                      icon: Icons.wifi_rounded,
                      background: const Color(0xFFF2F0EA),
                      foreground: const Color(0xFF5D5549),
                    ),
                    ChalkPill(
                      label: orientationLabel,
                      icon: screenOrientation == 'portrait'
                          ? Icons.stay_current_portrait_rounded
                          : Icons.stay_current_landscape_rounded,
                      background: const Color(0xFFE5F7ED),
                      foreground: const Color(0xFF18764C),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Bearbeite den aktuellen Screen-Inhalt, erstelle eine neue Vorlage oder sende eine vorhandene Vorlage an diesen Screen.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chalkInk,
      appBar: chalkAppBar(title: 'Screen Dashboard'),
      body: ChalkBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            _buildInfoCard(),
            const SizedBox(height: 22),
            _buildActionCard(
              icon: Icons.edit_note_rounded,
              title: 'Aktuellen Screen-Inhalt bearbeiten',
              subtitle: 'Live vom Screen laden und direkt im Editor weiterbearbeiten',
              onTap: () => _openAssignedContentEditor(context),
              primary: true,
            ),
            const SizedBox(height: 14),
            _buildActionCard(
              icon: Icons.add_circle_outline_rounded,
              title: 'Neue Vorlage erstellen',
              subtitle: 'Menü, Getränke, Aktion, Willkommen oder Foto neu gestalten',
              onTap: () => _openTemplateSelection(context),
              primary: false,
            ),
            const SizedBox(height: 14),
            _buildActionCard(
              icon: Icons.folder_copy_rounded,
              title: 'Meine Vorlagen',
              subtitle: 'Bestehende Vorlagen öffnen, bearbeiten oder an Screens senden',
              onTap: () => _openContentLibrary(context),
              primary: false,
            ),
          ],
        ),
      ),
    );
  }

}
