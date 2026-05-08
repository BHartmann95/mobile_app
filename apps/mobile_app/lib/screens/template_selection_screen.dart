import 'package:flutter/material.dart';
import '../models/template.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Layout wählen'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Menü'),
            subtitle: const Text('Mehrere Gerichte mit Preisen'),
            onTap: () => openTemplate(context, TemplateType.menu),
          ),
          ListTile(
            title: const Text('Getränke'),
            subtitle: const Text('Getränke / Bar Karte'),
            onTap: () => openTemplate(context, TemplateType.drinks),
          ),
          ListTile(
            title: const Text('Aktion'),
            subtitle: const Text('Promo / Angebot'),
            onTap: () => openTemplate(context, TemplateType.promo),
          ),
          ListTile(
            title: const Text('Willkommen'),
            subtitle: const Text('Begrüßung / Info'),
            onTap: () => openTemplate(context, TemplateType.welcome),
          ),
          ListTile(
            title: const Text('Foto'),
            subtitle: const Text('Bild / Fullscreen-Foto'),
            onTap: () => openTemplate(context, TemplateType.photo),
          ),
        ],
      ),
    );
  }
}