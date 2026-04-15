import 'package:flutter/material.dart';
import '../models/saved_content.dart';
import '../services/api_service.dart';
import '../services/content_storage_service.dart';
import 'template_selection_screen.dart';
import 'content_library_screen.dart';
import 'template_editor_screen.dart';

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
            screenOrientation: liveResult.orientation ?? screenOrientation,
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.tv,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    screenName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'IP-Adresse: $ip',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ausrichtung: $orientationLabel',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Wähle aus, ob du neuen Content erstellen, bereits gespeicherte Inhalte senden oder den aktuellen Inhalt direkt vom Screen laden und bearbeiten möchtest.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
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

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool primary,
  }) {
    final cardChild = Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: primary ? Colors.white24 : Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 28,
              color: primary ? Colors.white : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primary ? Colors.white : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: primary ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 18,
            color: primary ? Colors.white70 : Colors.grey.shade600,
          ),
        ],
      ),
    );

    if (primary) {
      return Material(
        color: Colors.blueGrey,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: cardChild,
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: cardChild,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 20),
          _buildActionCard(
            icon: Icons.edit_note,
            title: 'Aktuellen Screen-Inhalt bearbeiten',
            subtitle:
                'Lädt den aktuellen Inhalt direkt live vom Screen und öffnet ihn im Editor',
            onTap: () => _openAssignedContentEditor(context),
            primary: true,
          ),
          const SizedBox(height: 14),
          _buildActionCard(
            icon: Icons.add_circle_outline,
            title: 'Neuen Inhalt erstellen',
            subtitle: 'Neues Menü, Aktion oder Willkommens-Screen anlegen',
            onTap: () => _openTemplateSelection(context),
            primary: false,
          ),
          const SizedBox(height: 14),
          _buildActionCard(
            icon: Icons.library_books_outlined,
            title: 'Gespeicherte Inhalte',
            subtitle: 'Bestehende Inhalte öffnen, bearbeiten oder senden',
            onTap: () => _openContentLibrary(context),
            primary: false,
          ),
        ],
      ),
    );
  }
}
