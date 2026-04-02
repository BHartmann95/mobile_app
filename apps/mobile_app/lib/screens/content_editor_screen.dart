import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
  final footerController = TextEditingController(text: 'Solange der Vorrat reicht');
  final backgroundColorController = TextEditingController(text: '#111111');

  final List<TextEditingController> itemNameControllers = [
    TextEditingController(text: 'Pizza + Cola'),
    TextEditingController(text: 'Pasta Arrabiata'),
    TextEditingController(text: 'Tiramisu'),
  ];

  final List<TextEditingController> itemPriceControllers = [
    TextEditingController(text: '9,90 €'),
    TextEditingController(text: '8,50 €'),
    TextEditingController(text: '4,20 €'),
  ];

  bool isLoading = false;
  String? errorMessage;

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
          }
        ]
      };

      final api = ApiService('http://${widget.ip}:8080');
      final success = await api.sendContent(payload);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content erfolgreich gesendet')),
        );
      } else {
        setState(() {
          errorMessage = 'Content konnte nicht gesendet werden';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Fehler: $e';
      });
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  void addItem() {
    setState(() {
      itemNameControllers.add(TextEditingController());
      itemPriceControllers.add(TextEditingController());
    });
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Content für ${widget.screenName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 24),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Menüpunkte',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            ...List.generate(itemNameControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: itemNameControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Name ${index + 1}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: itemPriceControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Preis ${index + 1}',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: addItem,
                icon: const Icon(Icons.add),
                label: const Text('Eintrag hinzufügen'),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : sendContent,
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('An Screen senden'),
              ),
            ),

            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}