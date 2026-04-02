import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/template.dart';
import '../models/saved_content.dart';
import '../services/api_service.dart';
import '../services/content_storage_service.dart';
import '../services/storage_service.dart';
import '../widgets/headline_board_widget.dart';

class TemplateEditorScreen extends StatefulWidget {
  final String ip;
  final String screenName;
  final TemplateType templateType;
  final SavedContent? initialContent;
  final String screenOrientation;

  const TemplateEditorScreen({
    super.key,
    required this.ip,
    required this.screenName,
    required this.screenOrientation,
    required this.templateType,
    this.initialContent,
  });

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _EditableSlide {
  TemplateType templateType;

  final TextEditingController titleController;
  final TextEditingController subtitleController;
  final TextEditingController footerController;
  final TextEditingController highlightTitleController;
  final TextEditingController highlightPriceController;
  final TextEditingController durationController;

  final List<TextEditingController> itemNameControllers;
  final List<TextEditingController> itemPriceControllers;
  final List<ValueNotifier<bool>> itemSoldOutControllers;
  double textScale;

  _EditableSlide({
    required this.templateType,
    required this.titleController,
    required this.subtitleController,
    required this.footerController,
    required this.highlightTitleController,
    required this.highlightPriceController,
    required this.durationController,
    required this.itemNameControllers,
    required this.itemPriceControllers,
    required this.itemSoldOutControllers,
    this.textScale = 1.0,
  });

  void dispose() {
    titleController.dispose();
    subtitleController.dispose();
    footerController.dispose();
    highlightTitleController.dispose();
    highlightPriceController.dispose();
    durationController.dispose();

    for (final c in itemNameControllers) {
      c.dispose();
    }
    for (final c in itemPriceControllers) {
      c.dispose();
    }
    for (final n in itemSoldOutControllers) {
      n.dispose();
    }
  }
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final libraryNameController = TextEditingController();
  String boardStyle = 'black';
  String fontStyle = 'chalk';

  final List<_EditableSlide> slides = [];
  int selectedSlideIndex = 0;

  bool isLoading = false;
  String? errorMessage;
  late final String contentId;

  @override
  void initState() {
    super.initState();

    contentId =
        widget.initialContent?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    if (widget.initialContent != null) {
      _applySavedContent(widget.initialContent!);
    } else {
      libraryNameController.text = 'Neuer Inhalt';
      slides.add(_createDefaultSlide(widget.templateType));
      boardStyle = 'black';
      fontStyle = 'chalk';
    }

    _attachLibraryListener();
  }

  void _attachLibraryListener() {
    libraryNameController.addListener(_refreshPreview);
  }

  void _attachSlideListeners(_EditableSlide slide) {
    for (final controller in [
      slide.titleController,
      slide.subtitleController,
      slide.footerController,
      slide.highlightTitleController,
      slide.highlightPriceController,
      slide.durationController,
      ...slide.itemNameControllers,
      ...slide.itemPriceControllers,
    ]) {
      controller.addListener(_refreshPreview);
    }
    for (final soldOut in slide.itemSoldOutControllers) {
      soldOut.addListener(_refreshPreview);
    }
  }

  void _refreshPreview() {
    if (!mounted) return;
    setState(() {});
  }

  _EditableSlide _createDefaultSlide(TemplateType type) {
    switch (type) {
      case TemplateType.menu:
        final slide = _EditableSlide(
          templateType: TemplateType.menu,
          titleController: TextEditingController(text: 'Tagesmenü'),
          subtitleController: TextEditingController(text: 'Heute frisch'),
          footerController:
              TextEditingController(text: 'Solange der Vorrat reicht'),
          highlightTitleController: TextEditingController(),
          highlightPriceController: TextEditingController(),
          durationController: TextEditingController(text: '10'),
          itemNameControllers: [
            TextEditingController(text: 'Pizza + Cola'),
            TextEditingController(text: 'Pasta Arrabiata'),
            TextEditingController(text: 'Tiramisu'),
          ],
          itemPriceControllers: [
            TextEditingController(text: '9,90 €'),
            TextEditingController(text: '8,50 €'),
            TextEditingController(text: '4,20 €'),
          ],
          itemSoldOutControllers: [
            ValueNotifier<bool>(false),
            ValueNotifier<bool>(false),
            ValueNotifier<bool>(false),
          ],
        );
        _attachSlideListeners(slide);
        return slide;

      case TemplateType.promo:
        final slide = _EditableSlide(
          templateType: TemplateType.promo,
          titleController: TextEditingController(text: 'Aktion'),
          subtitleController: TextEditingController(text: 'Happy Hour'),
          footerController: TextEditingController(text: 'Nur heute ab 18 Uhr'),
          highlightTitleController: TextEditingController(text: '2 Cocktails'),
          highlightPriceController: TextEditingController(text: '1 Gratis'),
          durationController: TextEditingController(text: '10'),
          itemNameControllers: [],
          itemPriceControllers: [],
          itemSoldOutControllers: [],
        );
        _attachSlideListeners(slide);
        return slide;

      case TemplateType.welcome:
        final slide = _EditableSlide(
          templateType: TemplateType.welcome,
          titleController: TextEditingController(text: 'Willkommen'),
          subtitleController:
              TextEditingController(text: 'Schön, dass Sie da sind'),
          footerController: TextEditingController(text: 'Guten Appetit'),
          highlightTitleController: TextEditingController(),
          highlightPriceController: TextEditingController(),
          durationController: TextEditingController(text: '10'),
          itemNameControllers: [],
          itemPriceControllers: [],
          itemSoldOutControllers: [],
        );
        _attachSlideListeners(slide);
        return slide;
    }
  }

  _EditableSlide _createSlideFromSaved(SavedSlide slideData) {
    final slide = _EditableSlide(
      templateType: slideData.templateType,
      titleController: TextEditingController(text: slideData.title),
      subtitleController: TextEditingController(text: slideData.subtitle),
      footerController: TextEditingController(text: slideData.footer),
      highlightTitleController:
          TextEditingController(text: slideData.highlightTitle ?? ''),
      highlightPriceController:
          TextEditingController(text: slideData.highlightPrice ?? ''),
      durationController:
          TextEditingController(text: slideData.durationSeconds.toString()),
      itemNameControllers:
          slideData.items.map((e) => TextEditingController(text: e.name)).toList(),
      itemPriceControllers:
          slideData.items.map((e) => TextEditingController(text: e.price)).toList(),
      itemSoldOutControllers:
          slideData.items.map((e) => ValueNotifier<bool>(e.soldOut)).toList(),
      textScale: slideData.textScale,
    );

    if (slide.templateType == TemplateType.menu &&
        slide.itemNameControllers.isEmpty) {
      slide.itemNameControllers.add(TextEditingController());
      slide.itemPriceControllers.add(TextEditingController());
      slide.itemSoldOutControllers.add(ValueNotifier<bool>(false));
    }

    _attachSlideListeners(slide);
    return slide;
  }

  void _applySavedContent(SavedContent content) {
    libraryNameController.text = content.name;
    boardStyle = content.boardStyle;
    fontStyle = _normalizeFontStyle(content.fontStyle);

    for (final slideData in content.slides) {
      slides.add(_createSlideFromSaved(slideData));
    }

    if (slides.isEmpty) {
      slides.add(_createDefaultSlide(widget.templateType));
    }
  }

  _EditableSlide get currentSlide => slides[selectedSlideIndex];

  String _normalizeFontStyle(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();

    switch (normalized) {
      case 'standard':
      case 'normal':
      case 'classic':
        return 'standard';
      case 'chalk':
      case 'chalk1':
      case 'chalk2':
      case 'chalk3':
      case 'kreide':
      case 'schrift 1':
      case 'schrift 2':
      case 'schrift 3':
      default:
        return 'chalk';
    }
  }

  String _templateLabel(TemplateType type) {
    switch (type) {
      case TemplateType.menu:
        return 'Menü';
      case TemplateType.promo:
        return 'Aktion';
      case TemplateType.welcome:
        return 'Willkommen';
    }
  }

  IconData _templateIcon(TemplateType type) {
    switch (type) {
      case TemplateType.menu:
        return Icons.restaurant_menu;
      case TemplateType.promo:
        return Icons.local_offer;
      case TemplateType.welcome:
        return Icons.waving_hand;
    }
  }

  Color _templateColor(TemplateType type) {
    switch (type) {
      case TemplateType.menu:
        return Colors.orange;
      case TemplateType.promo:
        return Colors.blue;
      case TemplateType.welcome:
        return Colors.green;
    }
  }

  Future<TemplateType?> _showTemplatePickerDialog() {
    return showDialog<TemplateType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Slide-Typ wählen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Menü'),
              onTap: () => Navigator.pop(context, TemplateType.menu),
            ),
            ListTile(
              leading: const Icon(Icons.local_offer),
              title: const Text('Aktion'),
              onTap: () => Navigator.pop(context, TemplateType.promo),
            ),
            ListTile(
              leading: const Icon(Icons.waving_hand),
              title: const Text('Willkommen'),
              onTap: () => Navigator.pop(context, TemplateType.welcome),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> addSlide() async {
    final selectedType = await _showTemplatePickerDialog();
    if (selectedType == null) return;

    setState(() {
      slides.add(_createDefaultSlide(selectedType));
      selectedSlideIndex = slides.length - 1;
    });
  }

  void removeCurrentSlide() {
    if (slides.length <= 1) return;

    setState(() {
      final slide = slides.removeAt(selectedSlideIndex);
      slide.dispose();

      if (selectedSlideIndex >= slides.length) {
        selectedSlideIndex = slides.length - 1;
      }
    });
  }

  void addMenuItem() {
    if (currentSlide.templateType != TemplateType.menu) return;

    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final soldOutNotifier = ValueNotifier<bool>(false);

    nameController.addListener(_refreshPreview);
    priceController.addListener(_refreshPreview);
    soldOutNotifier.addListener(_refreshPreview);

    setState(() {
      currentSlide.itemNameControllers.add(nameController);
      currentSlide.itemPriceControllers.add(priceController);
      currentSlide.itemSoldOutControllers.add(soldOutNotifier);
    });
  }

  void removeMenuItem(int index) {
    if (currentSlide.templateType != TemplateType.menu) return;
    if (currentSlide.itemNameControllers.length <= 1) return;

    setState(() {
      currentSlide.itemNameControllers[index].dispose();
      currentSlide.itemPriceControllers[index].dispose();
      currentSlide.itemSoldOutControllers[index].dispose();
      currentSlide.itemNameControllers.removeAt(index);
      currentSlide.itemPriceControllers.removeAt(index);
      currentSlide.itemSoldOutControllers.removeAt(index);
    });
  }

  String _screenTitle() {
    return 'Inhalt bearbeiten';
  }

  int _durationValue(_EditableSlide slide) {
    final value = int.tryParse(slide.durationController.text.trim());
    if (value == null || value <= 0) {
      return 10;
    }
    return value;
  }

  List<SavedSlide> _buildSavedSlides() {
    return List.generate(slides.length, (index) {
      final slide = slides[index];

      return SavedSlide(
        id: 'slide_${index + 1}',
        templateType: slide.templateType,
        title: slide.titleController.text.trim(),
        subtitle: slide.subtitleController.text.trim(),
        footer: slide.footerController.text.trim(),
        highlightTitle: slide.highlightTitleController.text.trim().isEmpty
            ? null
            : slide.highlightTitleController.text.trim(),
        highlightPrice: slide.highlightPriceController.text.trim().isEmpty
            ? null
            : slide.highlightPriceController.text.trim(),
        items: List.generate(slide.itemNameControllers.length, (itemIndex) {
          return SavedMenuItem(
            name: slide.itemNameControllers[itemIndex].text.trim(),
            price: slide.itemPriceControllers[itemIndex].text.trim(),
            soldOut: slide.itemSoldOutControllers[itemIndex].value,
          );
        }).where((e) => e.name.isNotEmpty || e.price.isNotEmpty).toList(),
        durationSeconds: _durationValue(slide),
        textScale: slide.textScale,
      );
    });
  }

  Future<void> saveContentLocally() async {
    final name = libraryNameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        errorMessage = 'Bitte einen Namen für die Bibliothek eingeben';
      });
      return;
    }

    final content = SavedContent(
      id: contentId,
      name: name,
      templateType:
          slides.isNotEmpty ? slides.first.templateType : widget.templateType,
      lastUsedScreenIp: widget.initialContent?.lastUsedScreenIp,
      slides: _buildSavedSlides(),
      boardStyle: boardStyle,
      fontStyle: fontStyle,
    );

    final storage = ContentStorageService();
    await storage.addOrUpdateContent(content);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inhalt gespeichert')),
    );
  }

  Future<bool> _ensureScreenOnline() async {
    final api = ApiService('http://${widget.ip}:8080');
    final status = await api.getStatus();

    if (status.isOnline) {
      return true;
    }

    if (!mounted) return false;

    final retry = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Screen offline'),
        content: Text(
          '"${widget.screenName}" ist aktuell nicht erreichbar.\n\n'
          'Bitte prüfen, ob der Player geöffnet ist und sich das Gerät im selben WLAN befindet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Erneut prüfen'),
          ),
        ],
      ),
    );

    if (retry != true) {
      return false;
    }

    final retryStatus = await api.getStatus();
    return retryStatus.isOnline;
  }

  Future<void> _showSendErrorDialog({
    required String title,
    required String message,
    required VoidCallback onRetry,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            child: const Text('Erneut versuchen'),
          ),
        ],
      ),
    );
  }

  Future<void> sendContent() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final isOnline = await _ensureScreenOnline();

      if (!isOnline) {
        if (!mounted) return;

        await _showSendErrorDialog(
          title: 'Senden nicht möglich',
          message:
              'Der Screen "${widget.screenName}" ist offline oder antwortet nicht.',
          onRetry: () {
            sendContent();
          },
        );

        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
        return;
      }

      final payload = _buildPayload();
      print('EDITOR PAYLOAD: $payload');
      print('EDITOR ORIENTATION: ${payload['orientation']}');

      final int contentVersion = payload['contentVersion'] as int;

      final api = ApiService('http://${widget.ip}:8080');
      final result = await api.sendContent(payload);

      if (!mounted) return;

      if (result.success) {
        final content = SavedContent(
          id: contentId,
          name: libraryNameController.text.trim().isEmpty
              ? 'Neuer Inhalt'
              : libraryNameController.text.trim(),
          templateType:
              slides.isNotEmpty ? slides.first.templateType : widget.templateType,
          lastUsedScreenIp: widget.ip,
          slides: _buildSavedSlides(),
          boardStyle: boardStyle,
          fontStyle: fontStyle,
        );

        final contentStorage = ContentStorageService();
        await contentStorage.addOrUpdateContent(content);

        final screenStorage = StorageService();
        await screenStorage.markContentSent(
          ip: widget.ip,
          contentVersion: contentVersion,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content erfolgreich gesendet')),
        );
      } else {
        await _showSendErrorDialog(
          title: 'Senden fehlgeschlagen',
          message: result.error ?? 'Content konnte nicht gesendet werden.',
          onRetry: () {
            sendContent();
          },
        );
      }
    } catch (e) {
      if (!mounted) return;

      await _showSendErrorDialog(
        title: 'Fehler beim Senden',
        message: 'Es ist ein unerwarteter Fehler aufgetreten:\n$e',
        onRetry: () {
          sendContent();
        },
      );
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Map<String, dynamic> _buildPayload() {
    final contentVersion = DateTime.now().millisecondsSinceEpoch;

    return {
      'contentVersion': contentVersion,
      'orientation': widget.screenOrientation,
      'boardStyle': boardStyle,
      'fontStyle': fontStyle,
      'slides': List.generate(slides.length, (index) {
        final slide = slides[index];

        final items = List.generate(slide.itemNameControllers.length, (i) {
          final name = slide.itemNameControllers[i].text.trim();
          final price = slide.itemPriceControllers[i].text.trim();
          final soldOut = slide.itemSoldOutControllers[i].value;

          return <String, dynamic>{
            'name': name,
            'price': price,
            'soldOut': soldOut,
          };
        }).where((e) {
          final name = (e['name'] ?? '').toString();
          final price = (e['price'] ?? '').toString();
          return name.isNotEmpty || price.isNotEmpty;
        }).toList();

        return {
          'slideId': 'slide_${index + 1}',
          'templateType': slide.templateType.name,
          'durationSeconds': _durationValue(slide),
          'textScale': slide.textScale,
          'title': slide.titleController.text.trim(),
          'subtitle': slide.subtitleController.text.trim(),
          'items': items,
          'footer': slide.footerController.text.trim(),
          'highlightTitle': slide.highlightTitleController.text.trim().isEmpty
              ? null
              : slide.highlightTitleController.text.trim(),
          'highlightPrice': slide.highlightPriceController.text.trim().isEmpty
              ? null
              : slide.highlightPriceController.text.trim(),
        };
      }),
    };
  }

  Widget _buildSlideSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Slides',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            ...List.generate(slides.length, (index) {
              final slide = slides[index];
              final isSelected = index == selectedSlideIndex;

              return Card(
                elevation: isSelected ? 4 : 1,
                child: ListTile(
                  leading: Icon(
                    _templateIcon(slide.templateType),
                    color: _templateColor(slide.templateType),
                  ),
                  title: Text(
                    'Slide ${index + 1} · ${_templateLabel(slide.templateType)}',
                  ),
                  subtitle: Text(
                    'Dauer: ${_durationValue(slide)}s',
                  ),
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      selectedSlideIndex = index;
                    });
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: index > 0
                            ? () {
                                setState(() {
                                  final temp = slides[index - 1];
                                  slides[index - 1] = slides[index];
                                  slides[index] = temp;

                                  selectedSlideIndex = index - 1;
                                });
                              }
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward),
                        onPressed: index < slides.length - 1
                            ? () {
                                setState(() {
                                  final temp = slides[index + 1];
                                  slides[index + 1] = slides[index];
                                  slides[index] = temp;

                                  selectedSlideIndex = index + 1;
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Slide hinzufügen'),
                    onPressed: addSlide,
                  ),
                ),
                const SizedBox(width: 12),
                if (slides.length > 1)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Aktuelle löschen'),
                      onPressed: removeCurrentSlide,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommonFields() {
    return Column(
      children: [
        TextField(
          controller: libraryNameController,
          decoration: const InputDecoration(labelText: 'Name in Bibliothek'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: currentSlide.titleController,
          decoration: InputDecoration(
            labelText:
                'Titel (Slide ${selectedSlideIndex + 1} · ${_templateLabel(currentSlide.templateType)})',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: currentSlide.subtitleController,
          decoration: const InputDecoration(labelText: 'Untertitel'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: currentSlide.footerController,
          decoration: const InputDecoration(labelText: 'Footer'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: boardStyle,
          decoration: const InputDecoration(labelText: 'Kreidetafel'),
          items: const [
            DropdownMenuItem(value: 'black', child: Text('Schwarz')),
            DropdownMenuItem(value: 'green', child: Text('Grün')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              boardStyle = value;
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: fontStyle,
          decoration: const InputDecoration(labelText: 'Schriftstil'),
          items: const [
            DropdownMenuItem(value: 'chalk', child: Text('Kreide')),
            DropdownMenuItem(value: 'standard', child: Text('Standard')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              fontStyle = value;
            });
          },
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Textgröße für diese Folie: ${(currentSlide.textScale * 100).round()}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Slider(
              value: currentSlide.textScale,
              min: 0.8,
              max: 1.25,
              divisions: 9,
              label: '${(currentSlide.textScale * 100).round()}%',
              onChanged: (value) {
                setState(() {
                  currentSlide.textScale = value;
                });
              },
            ),
          ],
        ),
        TextField(
          controller: currentSlide.durationController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Dauer in Sekunden',
          ),
        ),
      ],
    );
  }

  Widget _buildMenuFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Menüpunkte',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...List.generate(currentSlide.itemNameControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: currentSlide.itemNameControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Name ${index + 1}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: currentSlide.itemPriceControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Preis ${index + 1}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: currentSlide.itemSoldOutControllers[index],
                  builder: (context, soldOut, _) {
                    return Column(
                      children: [
                        Checkbox(
                          value: soldOut,
                          onChanged: (value) {
                            currentSlide.itemSoldOutControllers[index].value =
                                value ?? false;
                          },
                        ),
                        const Text(
                          'Ausverkauft',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    );
                  },
                ),
                IconButton(
                  onPressed: currentSlide.itemNameControllers.length > 1
                      ? () => removeMenuItem(index)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: addMenuItem,
          icon: const Icon(Icons.add),
          label: const Text('Eintrag hinzufügen'),
        ),
        const SizedBox(height: 8),
        Text(
          _isPortraitPreview()
              ? 'Im Portrait werden maximal 10 Einträge pro Menü-Slide angezeigt. Weitere Einträge werden automatisch auf zusätzliche Slides verteilt.'
              : 'Im Landscape werden maximal 6 Einträge pro Menü-Slide angezeigt. Weitere Einträge werden automatisch auf zusätzliche Slides verteilt.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildPromoFields() {
    return Column(
      children: [
        const SizedBox(height: 24),
        TextField(
          controller: currentSlide.highlightTitleController,
          decoration: const InputDecoration(labelText: 'Highlight Titel'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: currentSlide.highlightPriceController,
          decoration: const InputDecoration(labelText: 'Highlight Preis/Text'),
        ),
      ],
    );
  }

  Widget _buildWelcomeInfo() {
    return const Padding(
      padding: EdgeInsets.only(top: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Willkommens-Slide nutzt nur Titel, Untertitel, Footer und Dauer.',
        ),
      ),
    );
  }

  Widget _buildTemplateSpecificFields() {
    switch (currentSlide.templateType) {
      case TemplateType.menu:
        return _buildMenuFields();
      case TemplateType.promo:
        return _buildPromoFields();
      case TemplateType.welcome:
        return _buildWelcomeInfo();
    }
  }

  bool _isPortraitPreview() {
    return widget.screenOrientation.toLowerCase() == 'portrait';
  }

  Color _getBoardColor() {
    if (boardStyle == 'green') {
      return const Color(0xFF1B5E20);
    }
    return const Color(0xFF111111);
  }

  String _getPreviewFontMode() {
    return _normalizeFontStyle(fontStyle);
  }

  TextStyle _getTitleStyle({
    required double fontSize,
  }) {
    final resolvedSize = fontSize * currentSlide.textScale;
    switch (_getPreviewFontMode()) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'Gobsmacked',
          fontFamilyFallback: const ['Roboto', 'Noto Sans', 'Arial'],
          fontSize: resolvedSize,
          color: const Color(0xFFF2E9DC),
          height: 1.0,
        );
      default:
        return TextStyle(
          fontFamily: 'Roboto',
          fontFamilyFallback: const ['Noto Sans', 'Arial'],
          fontSize: resolvedSize,
          color: const Color(0xFFF2E9DC),
          height: 1.0,
          fontWeight: FontWeight.w700,
        );
    }
  }

  TextStyle _getBodyStyle({
    required double fontSize,
  }) {
    final resolvedSize = fontSize * currentSlide.textScale;
    switch (_getPreviewFontMode()) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'Gobsmacked',
          fontFamilyFallback: const ['Roboto', 'Noto Sans', 'Arial'],
          fontSize: resolvedSize,
          color: const Color(0xFFF2E9DC),
          height: 1.12,
        );
      default:
        return TextStyle(
          fontFamily: 'Roboto',
          fontFamilyFallback: const ['Noto Sans', 'Arial'],
          fontSize: resolvedSize,
          color: const Color(0xFFF2E9DC),
          height: 1.18,
          fontWeight: FontWeight.w500,
        );
    }
  }

  TextStyle _getPriceStyle({
    required double fontSize,
  }) {
    final resolvedSize = fontSize * currentSlide.textScale;
    switch (_getPreviewFontMode()) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'Gobsmacked',
          fontFamilyFallback: const ['Roboto', 'Noto Sans', 'Arial'],
          fontSize: resolvedSize,
          color: const Color(0xFFF2E9DC),
          height: 1.0,
        );
      default:
        return TextStyle(
          fontFamily: 'Roboto',
          fontFamilyFallback: const ['Noto Sans', 'Arial'],
          fontSize: resolvedSize,
          color: const Color(0xFFF2E9DC),
          height: 1.0,
          fontWeight: FontWeight.w700,
        );
    }
  }

  Widget _buildFittedHeadline(
    String text, {
    required TextStyle style,
    Color? color,
  }) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              textAlign: TextAlign.center,
              softWrap: false,
              maxLines: 1,
              style: style.copyWith(color: color ?? style.color),
            ),
          ),
        );
      },
    );
  }

  int _maxMenuItemsPerSlide({bool? portrait}) {
    final usePortrait = portrait ?? _isPortraitPreview();
    return usePortrait ? 10 : 6;
  }

  int _menuPreviewPageCount() {
    if (currentSlide.templateType != TemplateType.menu) return 1;
    final items = _visiblePreviewMenuItems();
    final maxItems = _maxMenuItemsPerSlide();
    if (items.isEmpty) return 1;
    return (items.length / maxItems).ceil();
  }

  List<Map<String, String>> _visiblePreviewMenuItems() {
    final items = _visiblePreviewMenuItems();
    final maxItems = _maxMenuItemsPerSlide();
    if (items.length <= maxItems) return items;
    return items.take(maxItems).toList();
  }

  Map<String, double> _getMenuScaleConfig(int itemCount, {required bool portrait}) {
    if (portrait) {
      return {
        'title': 64,
        'subtitle': 24,
        'item': 42,
        'price': 40,
        'footer': 18,
        'gap': 20,
        'top': 38,
        'bottom': 28,
        'blockWidth': 0.92,
      };
    }

    return {
      'title': 64,
      'subtitle': 24,
      'item': 36,
      'price': 34,
      'footer': 18,
      'gap': 18,
      'top': 18,
      'bottom': 20,
      'blockWidth': 0.78,
    };
  }

  List<Map<String, String>> _currentMenuItems() {
    return List.generate(currentSlide.itemNameControllers.length, (index) {
      return {
        'name': currentSlide.itemNameControllers[index].text.trim(),
        'price': currentSlide.itemPriceControllers[index].text.trim(),
      };
    }).where((e) => e['name']!.isNotEmpty || e['price']!.isNotEmpty).toList();
  }

  Widget _buildPreviewCard() {
    final isPortrait = _isPortraitPreview();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final targetWidth = isPortrait
            ? math.min(availableWidth, 320.0)
            : math.min(availableWidth, 900.0);

        return Center(
          child: SizedBox(
            width: targetWidth,
            child: AspectRatio(
              aspectRatio: isPortrait ? 9 / 16 : 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: _getBoardColor(),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final previewScale = isPortrait
                          ? math.min(box.maxWidth / 1080, box.maxHeight / 1920)
                          : math.min(box.maxWidth / 1920, box.maxHeight / 1080);

                      return Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 80 * previewScale,
                              vertical: 60 * previewScale,
                            ),
                            child: _buildPreviewSlideContent(previewScale),
                          ),
                          Positioned(
                            left: 16 * previewScale,
                            bottom: 16 * previewScale,
                            child: Opacity(
                              opacity: 0.35,
                              child: Text(
                                widget.screenName,
                                style: TextStyle(
                                  fontSize: 14 * previewScale,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 16 * previewScale,
                            bottom: 16 * previewScale,
                            child: Opacity(
                              opacity: 0.35,
                              child: Text(
                                currentSlide.templateType == TemplateType.menu && _menuPreviewPageCount() > 1
                                    ? 'Vorschau · ${_templateLabel(currentSlide.templateType)} · Teil 1 von ${_menuPreviewPageCount()} · ${_durationValue(currentSlide)}s'
                                    : 'Vorschau · ${_templateLabel(currentSlide.templateType)} · ${_durationValue(currentSlide)}s',
                                style: TextStyle(
                                  fontSize: 14 * previewScale,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewSlideContent(double scale) {
    switch (currentSlide.templateType) {
      case TemplateType.menu:
        return _buildMenuPreview(scale);
      case TemplateType.promo:
        return _buildPromoPreview(scale);
      case TemplateType.welcome:
        return _buildWelcomePreview(scale);
    }
  }

  Widget _buildMenuPreview(double scale) {
    return _isPortraitPreview()
        ? _buildMenuPortraitPreview(scale)
        : _buildMenuLandscapePreview(scale);
  }

  Widget _buildMenuLandscapePreview(double scale) {
    final items = _currentMenuItems();
    final config = _getMenuScaleConfig(items.length, portrait: false);

    final titleFontSize = config['title']!;
    final subtitleFontSize = config['subtitle']!;
    final itemFontSize = config['item']!;
    final priceFontSize = config['price']!;
    final footerFontSize = config['footer']!;
    final rowGap = config['gap']! * scale;
    final topGap = config['top']! * scale;
    final blockWidth = config['blockWidth']!;

    return Center(
      child: FractionallySizedBox(
        widthFactor: blockWidth,
        child: Column(
          children: [
            SizedBox(height: topGap),
            Text(
              currentSlide.titleController.text.trim(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _getTitleStyle(fontSize: titleFontSize),
            ),
            SizedBox(height: 22 * scale),
            Text(
              currentSlide.subtitleController.text.trim(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _getBodyStyle(fontSize: subtitleFontSize),
            ),
            SizedBox(height: 26 * scale),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: items.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int index = 0; index < items.length; index++) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    items[index]['name'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: _getBodyStyle(fontSize: itemFontSize),
                                  ),
                                ),
                                SizedBox(width: 28 * scale),
                                Text(
                                  items[index]['price'] ?? '',
                                  style: _getPriceStyle(fontSize: priceFontSize),
                                ),
                              ],
                            ),
                            if (index != items.length - 1)
                              SizedBox(height: rowGap),
                          ],
                        ],
                      ),
              ),
            ),
            if (currentSlide.footerController.text.trim().isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 34 * scale),
                child: Text(
                  currentSlide.footerController.text.trim(),
                  textAlign: TextAlign.center,
                  style: _getBodyStyle(fontSize: footerFontSize),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuPortraitPreview(double scale) {
    final items = _currentMenuItems();
    final config = _getMenuScaleConfig(items.length, portrait: true);

    final titleFontSize = config['title']!;
    final subtitleFontSize = config['subtitle']!;
    final itemFontSize = config['item']!;
    final priceFontSize = config['price']!;
    final footerFontSize = config['footer']!;
    final rowGap = config['gap']! * scale;
    final topGap = config['top']! * scale;
    final blockWidth = config['blockWidth']!;

    return Center(
      child: FractionallySizedBox(
        widthFactor: blockWidth,
        child: Column(
          children: [
            SizedBox(height: topGap),
            Text(
              currentSlide.titleController.text.trim(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _getTitleStyle(fontSize: titleFontSize),
            ),
            SizedBox(height: 18 * scale),
            Text(
              currentSlide.subtitleController.text.trim(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _getBodyStyle(fontSize: subtitleFontSize),
            ),
            SizedBox(height: 22 * scale),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: items.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < items.length; i++) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    items[i]['name'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: _getBodyStyle(fontSize: itemFontSize),
                                  ),
                                ),
                                SizedBox(width: 18 * scale),
                                Text(
                                  items[i]['price'] ?? '',
                                  textAlign: TextAlign.right,
                                  style: _getPriceStyle(fontSize: priceFontSize),
                                ),
                              ],
                            ),
                            if (i != items.length - 1)
                              SizedBox(height: rowGap),
                          ],
                        ],
                      ),
              ),
            ),
            if (currentSlide.footerController.text.trim().isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 24 * scale),
                child: Text(
                  currentSlide.footerController.text.trim(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _getBodyStyle(fontSize: footerFontSize),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoPreview(double scale) {
    return _isPortraitPreview()
        ? _buildPromoPortraitPreview(scale)
        : _buildPromoLandscapePreview(scale);
  }

  Widget _buildPromoLandscapePreview(double scale) {
    return HeadlineBoardWidget(
      title: currentSlide.titleController.text.trim(),
      subtitle: currentSlide.subtitleController.text.trim(),
      footer: currentSlide.footerController.text.trim(),
      highlightTitle: currentSlide.highlightTitleController.text.trim(),
      highlightPrice: currentSlide.highlightPriceController.text.trim(),
      isPortrait: false,
      isWelcome: false,
      titleStyleBuilder: (base) => _getTitleStyle(fontSize: base),
      bodyStyleBuilder: (base) => _getBodyStyle(fontSize: base),
      priceStyleBuilder: (base) => _getPriceStyle(fontSize: base),
    );
  }

  Widget _buildPromoPortraitPreview(double scale) {
    return HeadlineBoardWidget(
      title: currentSlide.titleController.text.trim(),
      subtitle: currentSlide.subtitleController.text.trim(),
      footer: currentSlide.footerController.text.trim(),
      highlightTitle: currentSlide.highlightTitleController.text.trim(),
      highlightPrice: currentSlide.highlightPriceController.text.trim(),
      isPortrait: true,
      isWelcome: false,
      titleStyleBuilder: (base) => _getTitleStyle(fontSize: base),
      bodyStyleBuilder: (base) => _getBodyStyle(fontSize: base),
      priceStyleBuilder: (base) => _getPriceStyle(fontSize: base),
    );
  }

  Widget _buildWelcomePreview(double scale) {
    return _isPortraitPreview()
        ? _buildWelcomePortraitPreview(scale)
        : _buildWelcomeLandscapePreview(scale);
  }

  Widget _buildWelcomeLandscapePreview(double scale) {
    return HeadlineBoardWidget(
      title: currentSlide.titleController.text.trim(),
      subtitle: currentSlide.subtitleController.text.trim(),
      footer: currentSlide.footerController.text.trim(),
      highlightTitle: '',
      highlightPrice: '',
      isPortrait: false,
      isWelcome: true,
      titleStyleBuilder: (base) => _getTitleStyle(fontSize: base),
      bodyStyleBuilder: (base) => _getBodyStyle(fontSize: base),
      priceStyleBuilder: (base) => _getPriceStyle(fontSize: base),
    );
  }

  Widget _buildWelcomePortraitPreview(double scale) {
    return HeadlineBoardWidget(
      title: currentSlide.titleController.text.trim(),
      subtitle: currentSlide.subtitleController.text.trim(),
      footer: currentSlide.footerController.text.trim(),
      highlightTitle: '',
      highlightPrice: '',
      isPortrait: true,
      isWelcome: true,
      titleStyleBuilder: (base) => _getTitleStyle(fontSize: base),
      bodyStyleBuilder: (base) => _getBodyStyle(fontSize: base),
      priceStyleBuilder: (base) => _getPriceStyle(fontSize: base),
    );
  }

  @override
  void dispose() {
    libraryNameController.dispose();

    for (final slide in slides) {
      slide.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (slides.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSlideSelector(),
            const SizedBox(height: 20),
            _buildCommonFields(),
            _buildTemplateSpecificFields(),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Vorschau',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            _buildPreviewCard(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: saveContentLocally,
                    child: const Text('Speichern'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
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
              ],
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
