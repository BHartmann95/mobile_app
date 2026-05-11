import 'package:flutter/material.dart';
import '../models/template.dart';
import '../widgets/app_chalk_style.dart';
import 'template_editor_screen.dart';

class TemplateSelectionScreen extends StatelessWidget {
  final String ip;
  final String screenName;
  final String screenOrientation;

  const TemplateSelectionScreen({
    super.key,
    required this.ip,
    required this.screenName,
    required this.screenOrientation,
  });

  void openTemplate(BuildContext context, TemplateType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditorScreen(
          ip: ip,
          screenName: screenName,
          screenOrientation: screenOrientation,
          templateType: type,
        ),
      ),
    );
  }

  Widget _templateCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required TemplateType type,
  }) {
    return ChalkCard(
      onTap: () => openTemplate(context, type),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: chalkCream.withOpacity(0.92),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: chalkText, size: 28),
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
                const SizedBox(height: 5),
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
      appBar: brandedChalkAppBar(title: 'TafelFix Studio', subtitle: 'Neue Vorlage'),
      body: ChalkBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Vorlage auswählen',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _templateCard(
              context: context,
              icon: Icons.flatware_rounded,
              title: 'Menü',
              subtitle: 'Gerichte und Preise',
              type: TemplateType.menu,
            ),
            _templateCard(
              context: context,
              icon: Icons.wine_bar_rounded,
              title: 'Getränke',
              subtitle: 'Getränke und Preise',
              type: TemplateType.drinks,
            ),
            _templateCard(
              context: context,
              icon: Icons.local_offer_rounded,
              title: 'Aktion',
              subtitle: 'Angebot oder Hinweis',
              type: TemplateType.promo,
            ),
            _templateCard(
              context: context,
              icon: Icons.front_hand_rounded,
              title: 'Willkommen',
              subtitle: 'Begrüßung oder Info',
              type: TemplateType.welcome,
            ),
            _templateCard(
              context: context,
              icon: Icons.image_rounded,
              title: 'Foto',
              subtitle: 'Bild mit Rahmen oder als Fullscreen-Foto',
              type: TemplateType.photo,
            ),
          ],
        ),
      ),
    );
  }
}
