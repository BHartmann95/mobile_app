import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_chalk_style.dart';

class ContentEditorScreen extends StatefulWidget {
  final String ip;
  final String screenName;

  const ContentEditorScreen({
    super.key,
    required this.ip,
    required this.screenName,
  });

  @override
  State<ContentEditorScreen> createState() => _ContentEditorScreenState();
}

class _ContentEditorScreenState extends State<ContentEditorScreen> {
  final titleController = TextEditingController(text: 'Tagesmenü');
  final subtitleController = TextEditingController(text: 'Heute frisch');
  final footerController = TextEditingController(text: '');
  final backgroundColorController = TextEditingController(text: '#111111');

  final List<TextEditingController> itemNameControllers = [];
  final List<TextEditingController> itemPriceControllers = [];

  bool isLoading = false;
  String? errorMessage;

  ThemeData _chalkTheme(BuildContext context) {
    final base = Theme.of(context);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: chalkMutedText.withOpacity(0.18)),
    );

    return base.copyWith(
      scaffoldBackgroundColor: chalkInk,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.54),
        labelStyle: TextStyle(color: chalkMutedText.withOpacity(0.9)),
        floatingLabelStyle: const TextStyle(color: chalkText, fontWeight: FontWeight.w800),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: chalkCream, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: chalkCream,
          foregroundColor: chalkText,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: chalkText),
      ),
    );
  }

  void addItem() {
    setState(() {
      itemNameControllers.add(TextEditingController());
      itemPriceControllers.add(TextEditingController());
    });
  }

  void removeItem(int index) {
    setState(() {
      itemNameControllers.removeAt(index).dispose();
      itemPriceControllers.removeAt(index).dispose();
    });
  }

  Future<void> sendContent() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final items = <Map<String, String>>[];

      for (int i = 0; i < itemNameControllers.length; i++) {
        final name = itemNameControllers[i].text.trim();
        final price = itemPriceControllers[i].text.trim();

        if (name.isNotEmpty && price.isNotEmpty) {
          items.add({
            'name': name,
            'price': price,
          });
        }
      }

      final payload = {
        'contentVersion': 1,
        'slides': [
          {
            'slideId': 'slide_001',
            'durationSeconds': 6,
            'title': titleController.text.trim(),
            'subtitle': subtitleController.text.trim(),
            'items': items,
            'footer': footerController.text.trim(),
            'backgroundColor': backgroundColorController.text.trim(),
            'templateType': 'menu',
          }
        ],
      };

      final api = ApiService('http://${widget.ip}:8080');
      final result = await api.sendContent(payload);

      if (!mounted) return;

      if (!result.success) {
        setState(() {
          errorMessage = result.error ?? 'Unbekannter Fehler';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content erfolgreich gesendet')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    subtitleController.dispose();
    footerController.dispose();
    backgroundColorController.dispose();

    for (final c in itemNameControllers) {
      c.dispose();
    }
    for (final c in itemPriceControllers) {
      c.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _chalkTheme(context),
      child: Scaffold(
        backgroundColor: chalkInk,
        appBar: chalkAppBar(title: 'Content für ${widget.screenName}'),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: chalkCreamSoft.withOpacity(0.88),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.38)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.24),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : sendContent,
              icon: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined, size: 18),
              label: Text(isLoading ? 'Senden...' : 'An Screen senden'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ),
        ),
        body: ChalkBackground(
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ChalkCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(18),
                    opacity: 0.94,
                    child: Column(
                      children: [
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(labelText: 'Titel'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: subtitleController,
                          decoration: const InputDecoration(labelText: 'Untertitel'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: footerController,
                          decoration: const InputDecoration(labelText: 'Footer'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: backgroundColorController,
                          decoration: const InputDecoration(labelText: 'Hintergrundfarbe (#111111)'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ChalkCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(18),
                    opacity: 0.94,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Menüpunkte',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: chalkText,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (itemNameControllers.isEmpty)
                          Text(
                            'Noch keine Einträge angelegt.',
                            style: TextStyle(color: chalkMutedText.withOpacity(0.9)),
                          ),
                        ...List.generate(itemNameControllers.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: itemNameControllers[index],
                                    decoration: InputDecoration(labelText: 'Name ${index + 1}'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: itemPriceControllers[index],
                                    decoration: InputDecoration(labelText: 'Preis ${index + 1}'),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => removeItem(index),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  color: chalkMutedText,
                                ),
                              ],
                            ),
                          );
                        }),
                        TextButton.icon(
                          onPressed: addItem,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Eintrag hinzufügen'),
                        ),
                      ],
                    ),
                  ),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Color(0xFFFFD3D3), fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
