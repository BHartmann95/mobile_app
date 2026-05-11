import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/template.dart';
import '../models/saved_content.dart';
import '../services/api_service.dart';
import '../services/content_storage_service.dart';
import '../services/storage_service.dart';
import '../widgets/headline_board_widget.dart';
import '../widgets/menu_board_widget.dart';
import '../widgets/photo_board_widget.dart';
import '../widgets/app_chalk_style.dart';
import 'photo_position_editor_screen.dart';

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
  String logoMode;
  double logoOpacity;
  String? photoPath;
  String? photoFileName;
  String? imageAssetId;
  double photoScale;
  bool fullscreenPhoto;

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
    this.logoMode = 'none',
    this.logoOpacity = 0.12,
    this.photoPath,
    this.photoFileName,
    this.imageAssetId,
    this.photoScale = 1.0,
    this.fullscreenPhoto = false,
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
  final ImagePicker _imagePicker = ImagePicker();

  String boardStyle = 'black';
  String fontStyle = 'chalk';
  String? logoBase64;

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
    _recoverLostLogoSelection();
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

  String _normalizePriceInput(String? value) {
    if (value == null) return '';
    var normalized = value.trim();
    normalized = normalized.replaceAll('€', '');
    normalized = normalized.replaceAll(RegExp(r'\s+'), '');
    return normalized;
  }

  String _displayPrice(String? value) {
    final normalized = _normalizePriceInput(value);
    if (normalized.isEmpty) return '';
    return '$normalized €';
  }

  String _normalizeLogoMode(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'center':
      case 'centerwatermark':
      case 'watermark':
        return 'center';
      case 'topleft':
      case 'top_left':
      case 'top-left':
      case 'stamp':
        return 'topLeft';
      case 'none':
      default:
        return 'none';
    }
  }

  double _normalizeLogoOpacity(Object? value) {
    final parsed =
        value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      return 0.12;
    }
    final normalized = parsed > 1 ? parsed / 100.0 : parsed;
    return normalized.clamp(0.05, 0.8).toDouble();
  }

  Future<void> _pickLogo() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 100,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        logoBase64 = base64Encode(bytes);
        if (currentSlide.logoMode == 'none') {
          currentSlide.logoMode = 'center';
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logo konnte nicht geladen werden: $e')),
      );
    }
  }

  Future<void> _recoverLostLogoSelection() async {
    try {
      final response = await _imagePicker.retrieveLostData();
      if (response.isEmpty) return;

      final files = response.files;
      if (files != null && files.isNotEmpty) {
        final bytes = await files.first.readAsBytes();
        if (!mounted) return;

        setState(() {
          logoBase64 = base64Encode(bytes);
          if (currentSlide.logoMode == 'none') {
            currentSlide.logoMode = 'center';
          }
        });
      }
    } catch (_) {}
  }

  Future<Directory> _getManagedImageDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final target = Directory('${dir.path}/content_assets/$contentId');
    if (!(await target.exists())) {
      await target.create(recursive: true);
    }
    return target;
  }

  String _sanitizeFileName(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.isEmpty ? 'image.jpg' : cleaned;
  }


  Future<ImageSource?> _showPhotoSourceSheet() async {
    if (!mounted) return null;

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.52),
      builder: (context) => SafeArea(
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
              _buildModalAction(
                icon: Icons.photo_library_outlined,
                label: 'Mediathek',
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              _buildModalAction(
                icon: Icons.photo_camera_outlined,
                label: 'Foto aufnehmen',
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              _buildModalAction(
                icon: Icons.close_rounded,
                label: 'Abbrechen',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final accent = destructive ? const Color(0xFF9B2D2D) : chalkText;
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
                    color: destructive
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

  Future<Uint8List> _cropAndResizePhoto(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final targetWidth = _isPortraitPreview() ? 1080 : 1920;
    final targetHeight = _isPortraitPreview() ? 1920 : 1080;
    final targetAspect = targetWidth / targetHeight;

    final sourceWidth = image.width.toDouble();
    final sourceHeight = image.height.toDouble();
    final sourceAspect = sourceWidth / sourceHeight;

    double cropWidth = sourceWidth;
    double cropHeight = sourceHeight;
    double cropLeft = 0;
    double cropTop = 0;

    if (sourceAspect > targetAspect) {
      cropWidth = sourceHeight * targetAspect;
      cropLeft = (sourceWidth - cropWidth) / 2;
    } else if (sourceAspect < targetAspect) {
      cropHeight = sourceWidth / targetAspect;
      cropTop = (sourceHeight - cropHeight) / 2;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.high;

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(cropLeft, cropTop, cropWidth, cropHeight),
      Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
      paint,
    );

    final picture = recorder.endRecording();
    final resized = await picture.toImage(targetWidth, targetHeight);
    final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Bild konnte nicht verarbeitet werden');
    }

    return byteData.buffer.asUint8List();
  }

  Future<Map<String, String>?> _pickManagedPhotoFile({ImageSource? source}) async {
    try {
      final resolvedSource = source ?? await _showPhotoSourceSheet();
      if (resolvedSource == null) return null;

      final picked = await _imagePicker.pickImage(
        source: resolvedSource,
        imageQuality: 100,
      );
      if (picked == null) return null;

      final bytes = await picked.readAsBytes();
      final processedBytes = await _cropAndResizePhoto(bytes);

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(99999).toString().padLeft(5, '0')}.png';

      final targetDir = await _getManagedImageDirectory();
      final targetFile = File('${targetDir.path}/${_sanitizeFileName(fileName)}');
      await targetFile.writeAsBytes(processedBytes, flush: true);

      return {
        'path': targetFile.path,
        'fileName': targetFile.uri.pathSegments.isNotEmpty
            ? targetFile.uri.pathSegments.last
            : fileName,
      };
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bild konnte nicht geladen werden: $e')),
      );
      return null;
    }
  }


  AlertDialog _chalkEditorDialog({
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
        style: const TextStyle(color: chalkText, fontWeight: FontWeight.w900),
      ),
      content: content,
      actions: actions,
    );
  }

  ButtonStyle _chalkEditorActionStyle({bool destructive = false}) {
    return ElevatedButton.styleFrom(
      backgroundColor: destructive ? const Color(0xFF9B2D2D) : chalkCream,
      foregroundColor: destructive ? Colors.white : chalkText,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Future<bool?> _showPhotoDisplayModeDialog() async {
    if (!mounted) return null;

    return showDialog<bool>(
      context: context,
      builder: (context) => _chalkEditorDialog(
        title: 'Bilddarstellung',
        content: const Text(
          'Soll das Foto mit Tafelrand oder bildschirmfüllend angezeigt werden?',
          style: TextStyle(color: chalkMutedText, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: chalkMutedText),
            child: const Text('Mit Rahmen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: chalkCream,
              foregroundColor: chalkText,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text('Fullscreen'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhotoForCurrentSlide() async {
    final selected = await _pickManagedPhotoFile();
    if (selected == null) return;

    final fullscreen = await _showPhotoDisplayModeDialog();
    if (fullscreen == null) return;

    setState(() {
      currentSlide.photoPath = selected['path'];
      currentSlide.photoFileName = selected['fileName'];
      currentSlide.imageAssetId = null;
      currentSlide.fullscreenPhoto = fullscreen;
    });
  }

  void _removePhotoFromCurrentSlide() {
    setState(() {
      currentSlide.photoPath = null;
      currentSlide.photoFileName = null;
      currentSlide.imageAssetId = null;
      currentSlide.fullscreenPhoto = false;
    });
  }


  void _removeLogo() {
    setState(() {
      logoBase64 = null;
      for (final slide in slides) {
        slide.logoMode = 'none';
        slide.logoOpacity = 0.12;
      }
    });
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
          itemNameControllers: [],
          itemPriceControllers: [],
          itemSoldOutControllers: [],
          textScale: 1.0,
        );
        _attachSlideListeners(slide);
        return slide;

      case TemplateType.drinks:
        final slide = _EditableSlide(
          templateType: TemplateType.drinks,
          titleController: TextEditingController(text: 'Getränke'),
          subtitleController: TextEditingController(text: 'Kalt & Heiß'),
          footerController: TextEditingController(text: ''),
          highlightTitleController: TextEditingController(),
          highlightPriceController: TextEditingController(),
          durationController: TextEditingController(text: '10'),
          itemNameControllers: [],
          itemPriceControllers: [],
          itemSoldOutControllers: [],
          textScale: 1.0,
        );
        _attachSlideListeners(slide);
        return slide;

      case TemplateType.promo:
        final slide = _EditableSlide(
          templateType: TemplateType.promo,
          titleController: TextEditingController(text: 'Aktion'),
          subtitleController: TextEditingController(text: ''),
          footerController: TextEditingController(text: ''),
          highlightTitleController: TextEditingController(),
          highlightPriceController: TextEditingController(),
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
          subtitleController: TextEditingController(text: ''),
          footerController: TextEditingController(text: ''),
          highlightTitleController: TextEditingController(),
          highlightPriceController: TextEditingController(),
          durationController: TextEditingController(text: '10'),
          itemNameControllers: [],
          itemPriceControllers: [],
          itemSoldOutControllers: [],
        );
        _attachSlideListeners(slide);
        return slide;

      case TemplateType.photo:
        final slide = _EditableSlide(
          templateType: TemplateType.photo,
          titleController: TextEditingController(text: ''),
          subtitleController: TextEditingController(text: ''),
          footerController: TextEditingController(text: ''),
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
      textScale: 1.0,
      logoMode: _normalizeLogoMode(slideData.logoMode),
      logoOpacity: _normalizeLogoOpacity(slideData.logoOpacity),
      photoPath: slideData.photoPath,
      photoFileName: slideData.photoFileName,
      imageAssetId: slideData.imageAssetId,
      photoScale: slideData.photoScale,
      fullscreenPhoto: slideData.fullscreenPhoto,
    );

    if ((slide.templateType == TemplateType.menu ||
            slide.templateType == TemplateType.drinks) &&
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
    logoBase64 = content.logoBase64;

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
      case TemplateType.drinks:
        return 'Getränke';
      case TemplateType.promo:
        return 'Aktion';
      case TemplateType.welcome:
        return 'Willkommen';
      case TemplateType.photo:
        return 'Foto';
    }
  }

  IconData _templateIcon(TemplateType type) {
    switch (type) {
      case TemplateType.menu:
        return Icons.restaurant_rounded;
      case TemplateType.drinks:
        return Icons.local_cafe_rounded;
      case TemplateType.promo:
        return Icons.campaign_rounded;
      case TemplateType.welcome:
        return Icons.waving_hand_rounded;
      case TemplateType.photo:
        return Icons.image_rounded;
    }
  }

  Color _templateColor(TemplateType type) {
    switch (type) {
      case TemplateType.menu:
        return const Color(0xFF9A6A2F);
      case TemplateType.drinks:
        return const Color(0xFF2F7D73);
      case TemplateType.promo:
        return const Color(0xFF2F6FA3);
      case TemplateType.welcome:
        return const Color(0xFF2F8A57);
      case TemplateType.photo:
        return const Color(0xFF7A5E2C);
    }
  }

  Future<TemplateType?> _showTemplatePickerDialog() {
    final options = <TemplateType>[
      TemplateType.menu,
      TemplateType.drinks,
      TemplateType.promo,
      TemplateType.welcome,
      TemplateType.photo,
    ];

    return showDialog<TemplateType>(
      context: context,
      builder: (context) => _chalkEditorDialog(
        title: 'Slide-Typ wählen',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in options)
              _buildDialogTemplateTile(
                type: type,
                onTap: () => Navigator.pop(context, type),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: chalkMutedText),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTemplateTile({
    required TemplateType type,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withOpacity(0.46),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _templateColor(type).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(_templateIcon(type), size: 19, color: _templateColor(type)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _templateLabel(type),
                    style: const TextStyle(
                      color: chalkText,
                      fontSize: 15,
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
    if (currentSlide.templateType != TemplateType.menu &&
        currentSlide.templateType != TemplateType.drinks) return;

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
    if (currentSlide.templateType != TemplateType.menu &&
        currentSlide.templateType != TemplateType.drinks) return;
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
            price: _displayPrice(slide.itemPriceControllers[itemIndex].text),
            soldOut: slide.itemSoldOutControllers[itemIndex].value,
          );
        }).where((e) => e.name.isNotEmpty || e.price.isNotEmpty).toList(),
        durationSeconds: _durationValue(slide),
        textScale: 1.0,
        logoMode: _normalizeLogoMode(slide.logoMode),
        logoOpacity: _normalizeLogoOpacity(slide.logoOpacity),
        photoPath: slide.photoPath,
        photoFileName: slide.photoFileName,
        imageAssetId: slide.imageAssetId,
        photoScale: 1.0,
        fullscreenPhoto: slide.fullscreenPhoto,
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
      orientation: widget.screenOrientation,
      logoBase64: logoBase64,
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
      builder: (_) => _chalkEditorDialog(
        title: 'Screen offline',
        content: Text(
          '"${widget.screenName}" ist aktuell nicht erreichbar.\n\n'
          'Bitte prüfen, ob der Player geöffnet ist und sich das Gerät im selben WLAN befindet.',
          style: TextStyle(color: chalkMutedText.withOpacity(0.95), height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: _chalkEditorActionStyle(),
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
      builder: (_) => _chalkEditorDialog(
        title: title,
        content: Text(message, style: TextStyle(color: chalkMutedText.withOpacity(0.95), height: 1.35)),
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
            style: _chalkEditorActionStyle(),
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
      final int contentVersion = payload['contentVersion'] as int;

      final api = ApiService('http://${widget.ip}:8080');
      final assets = _buildUploadableAssets(contentVersion);
      final result = await api.sendContentPackage(payload, assets);

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
          logoBase64: logoBase64,
        );

        final contentStorage = ContentStorageService();
        await contentStorage.addOrUpdateContent(content);

        final screenStorage = StorageService();
        await screenStorage.markContentSent(
          ip: widget.ip,
          contentVersion: contentVersion,
          contentName: content.name,
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



  String? _resolvedImageAssetIdForSlide(
    _EditableSlide slide,
    int index,
    int contentVersion,
  ) {
    if (slide.templateType != TemplateType.photo) return null;

    final photoPath = slide.photoPath?.trim();
    final fileName = slide.photoFileName?.trim();

    if (photoPath != null && photoPath.isNotEmpty && fileName != null && fileName.isNotEmpty) {
      final file = File(photoPath);
      if (file.existsSync()) {
        return 'content_${contentVersion}_slide_${index + 1}_$fileName';
      }
    }

    final existingAssetId = slide.imageAssetId?.trim();
    if (existingAssetId != null && existingAssetId.isNotEmpty) {
      return existingAssetId;
    }

    return null;
  }

  List<UploadableAsset> _buildUploadableAssets(int contentVersion) {
    final assets = <UploadableAsset>[];

    for (var index = 0; index < slides.length; index++) {
      final slide = slides[index];
      if (slide.templateType != TemplateType.photo) continue;

      final photoPath = slide.photoPath?.trim();
      if (photoPath == null || photoPath.isEmpty) continue;

      final file = File(photoPath);
      if (!file.existsSync()) continue;

      final fileName = slide.photoFileName?.trim().isNotEmpty == true
          ? slide.photoFileName!.trim()
          : file.uri.pathSegments.last;
      final assetId = 'content_${contentVersion}_slide_${index + 1}_$fileName';

      assets.add(
        UploadableAsset(
          assetId: assetId,
          fileName: fileName,
          file: file,
        ),
      );
    }

    return assets;
  }

  Map<String, dynamic> _buildPayload() {
    final contentVersion = DateTime.now().millisecondsSinceEpoch;

    return {
      'contentVersion': contentVersion,
      'contentName': libraryNameController.text.trim().isEmpty
          ? 'Neuer Inhalt'
          : libraryNameController.text.trim(),
      'orientation': widget.screenOrientation,
      'boardStyle': boardStyle,
      'fontStyle': fontStyle,
      'logoBase64': logoBase64,
      'slides': List.generate(slides.length, (index) {
        final slide = slides[index];

        final items = List.generate(slide.itemNameControllers.length, (i) {
          final name = slide.itemNameControllers[i].text.trim();
          final price = _displayPrice(slide.itemPriceControllers[i].text);
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

        final fileName = slide.photoFileName?.trim().isNotEmpty == true
            ? slide.photoFileName!.trim()
            : null;
        final imageAssetId = _resolvedImageAssetIdForSlide(
          slide,
          index,
          contentVersion,
        );

        return {
          'slideId': 'slide_${index + 1}',
          'templateType': slide.templateType.name,
          'durationSeconds': _durationValue(slide),
          'textScale': 1.0,
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
          'logoMode': _normalizeLogoMode(slide.logoMode),
          'logoOpacity': _normalizeLogoOpacity(slide.logoOpacity),
          'imageAssetId': imageAssetId,
          'imageFileName': fileName,
          'photoPath': slide.photoPath,
          'photoScale': 1.0,
          'fullscreenPhoto': slide.fullscreenPhoto,
        };
      }),
    };
  }

  Widget _buildSlideSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Slides',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: chalkCream.withOpacity(0.72),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: chalkText.withOpacity(0.10)),
              ),
              child: Text(
                'Aktiv: Slide ${selectedSlideIndex + 1}',
                style: const TextStyle(
                  color: chalkText,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            ...List.generate(slides.length, (index) {
              final slide = slides[index];
              final isSelected = index == selectedSlideIndex;
              final typeColor = _templateColor(slide.templateType);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? chalkCream.withOpacity(0.92)
                        : Colors.white.withOpacity(0.50),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? typeColor.withOpacity(0.72)
                          : Colors.white.withOpacity(0.38),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isSelected ? 0.18 : 0.08),
                        blurRadius: isSelected ? 18 : 10,
                        offset: Offset(0, isSelected ? 8 : 4),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        selectedSlideIndex = index;
                      });
                    },
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 6,
                          height: 76,
                          decoration: BoxDecoration(
                            color: isSelected ? typeColor : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(isSelected ? 0.18 : 0.10),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: typeColor.withOpacity(0.24)),
                          ),
                          child: Icon(
                            _templateIcon(slide.templateType),
                            size: 23,
                            color: typeColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Slide ${index + 1} · ${_templateLabel(slide.templateType)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isSelected ? chalkText : chalkText.withOpacity(0.82),
                                        fontSize: isSelected ? 17 : 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: typeColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'wird bearbeitet',
                                        style: TextStyle(
                                          color: typeColor,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Dauer: ${_durationValue(slide)}s',
                                style: TextStyle(
                                  color: chalkMutedText.withOpacity(0.86),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_up_rounded),
                          color: isSelected ? chalkText : chalkMutedText.withOpacity(0.58),
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
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          color: isSelected ? chalkText : chalkMutedText.withOpacity(0.58),
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
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Slide hinzufügen'),
                    onPressed: addSlide,
                  ),
                ),
                const SizedBox(width: 12),
                if (slides.length > 1)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded),
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

  Widget _buildLogoPreviewOverlay({
    required bool isPortrait,
    required double width,
    required double height,
    required String logoMode,
    required double logoOpacity,
  }) {
    if (logoBase64 == null || logoBase64!.trim().isEmpty || logoMode == 'none') {
      return const SizedBox.shrink();
    }

    try {
      final image = Image.memory(
        base64Decode(logoBase64!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );

      final opacity = _normalizeLogoOpacity(logoOpacity);

      if (logoMode == 'topLeft') {
        final stampWidth = isPortrait ? width * 0.20 : width * 0.16;
        final topOffset = isPortrait ? height * 0.05 : height * 0.06;
        final leftOffset = isPortrait ? width * 0.06 : width * 0.05;

        return Positioned(
          top: topOffset,
          left: leftOffset,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: -0.16,
                child: SizedBox(
                  width: stampWidth,
                  child: image,
                ),
              ),
            ),
          ),
        );
      }

      final watermarkWidth = isPortrait ? width * 0.62 : width * 0.52;

      return Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: opacity,
              child: SizedBox(
                width: watermarkWidth,
                child: image,
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
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
        if (currentSlide.templateType != TemplateType.photo) ...[
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
        ],
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
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Logo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.image_outlined),
                label: Text(logoBase64 == null ? 'Logo auswählen' : 'Logo ersetzen'),
              ),
            ),
            const SizedBox(width: 12),
            if (logoBase64 != null)
              OutlinedButton.icon(
                onPressed: _removeLogo,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Entfernen'),
              ),
          ],
        ),
        if (logoBase64 != null) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _normalizeLogoMode(currentSlide.logoMode),
            decoration: const InputDecoration(labelText: 'Logo Position'),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('Kein Logo auf dieser Folie')),
              DropdownMenuItem(value: 'center', child: Text('Zentriert im Hintergrund')),
              DropdownMenuItem(value: 'topLeft', child: Text('Oben links leicht gedreht')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                currentSlide.logoMode = _normalizeLogoMode(value);
              });
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Logo Sichtbarkeit: ${(currentSlide.logoOpacity * 100).round()}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Slider(
            value: _normalizeLogoOpacity(currentSlide.logoOpacity),
            min: 0.05,
            max: 0.8,
            divisions: 15,
            label: '${(_normalizeLogoOpacity(currentSlide.logoOpacity) * 100).round()}%',
            onChanged: (value) {
              setState(() {
                currentSlide.logoOpacity = value;
              });
            },
          ),
        ],

        TextField(
          controller: currentSlide.durationController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Dauer in Sekunden'),
        ),
      ],
    );
  }

  Widget _buildItemRows({required String addLabel}) {
    return Column(
      children: [
        ...List.generate(currentSlide.itemNameControllers.length, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.34),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: chalkText.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: currentSlide.itemNameControllers[index],
                  minLines: 1,
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: 'Name ${index + 1}'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: currentSlide.itemPriceControllers[index],
                        decoration: InputDecoration(labelText: 'Preis ${index + 1}'),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ValueListenableBuilder<bool>(
                      valueListenable: currentSlide.itemSoldOutControllers[index],
                      builder: (context, soldOut, _) {
                        return FilterChip(
                          selected: soldOut,
                          label: const Text('Ausverkauft'),
                          avatar: Icon(
                            soldOut ? Icons.check_rounded : Icons.remove_circle_outline_rounded,
                            size: 17,
                          ),
                          selectedColor: chalkCream.withOpacity(0.9),
                          checkmarkColor: chalkText,
                          onSelected: (value) {
                            currentSlide.itemSoldOutControllers[index].value = value;
                          },
                        );
                      },
                    ),
                    IconButton(
                      onPressed: currentSlide.itemNameControllers.length > 1
                          ? () => removeMenuItem(index)
                          : null,
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Eintrag löschen',
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: addMenuItem,
            icon: const Icon(Icons.add),
            label: Text(addLabel),
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
        _buildItemRows(addLabel: 'Eintrag hinzufügen'),
      ],
    );
  }

  Widget _buildDrinksFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Getränke',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildItemRows(addLabel: 'Getränk hinzufügen'),
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



  Future<File?> _ensureCurrentPhotoIsLocal() async {
    final path = currentSlide.photoPath?.trim();
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        return file;
      }
    }

    final assetId = currentSlide.imageAssetId?.trim();
    if (assetId == null || assetId.isEmpty) {
      return null;
    }

    final fileName = currentSlide.photoFileName?.trim().isNotEmpty == true
        ? currentSlide.photoFileName!.trim()
        : 'screen_photo.jpg';

    final api = ApiService('http://${widget.ip}:8080');
    final downloaded = await api.downloadAssetToLocalCache(
      assetId: assetId,
      fileName: fileName,
      stableContentId: contentId,
    );

    if (downloaded == null || !(await downloaded.exists())) {
      return null;
    }

    if (mounted) {
      setState(() {
        currentSlide.photoPath = downloaded.path;
        currentSlide.photoFileName = fileName;
        currentSlide.imageAssetId = assetId;
      });
    }

    return downloaded;
  }

  String _downloadFileNameForCurrentPhoto(File sourceFile) {
    final original = currentSlide.photoFileName?.trim().isNotEmpty == true
        ? currentSlide.photoFileName!.trim()
        : sourceFile.uri.pathSegments.isNotEmpty
            ? sourceFile.uri.pathSegments.last
            : 'tafel_fix_foto.png';

    final dotIndex = original.lastIndexOf('.');
    final extension = dotIndex >= 0 ? original.substring(dotIndex) : '.png';
    final baseName = dotIndex >= 0 ? original.substring(0, dotIndex) : original;
    final safeBase = _sanitizeFileName(baseName).replaceAll(RegExp(r'\.+$'), '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return _sanitizeFileName('${safeBase.isEmpty ? 'tafel_fix_foto' : safeBase}_$timestamp$extension');
  }

  Future<File> _preparePhotoCopyForGallery(File sourceFile) async {
    final tempDir = await getTemporaryDirectory();
    final targetName = _downloadFileNameForCurrentPhoto(sourceFile);
    final targetFile = File('${tempDir.path}/$targetName');
    await sourceFile.copy(targetFile.path);
    return targetFile;
  }

  Future<void> _saveCurrentPhotoToGallery() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final sourceFile = await _ensureCurrentPhotoIsLocal();

      if (!mounted) return;

      if (sourceFile == null || !(await sourceFile.exists())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Es ist kein Foto zum Herunterladen verfügbar.')),
        );
        return;
      }

      final galleryFile = await _preparePhotoCopyForGallery(sourceFile);
      await Gal.putImage(galleryFile.path, album: 'TafelFix');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto wurde in der Galerie/Mediathek im Album „TafelFix“ gespeichert.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto konnte nicht in der Galerie gespeichert werden: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadCurrentPhotoFromScreen() async {
    final assetId = currentSlide.imageAssetId?.trim();
    final fileName = currentSlide.photoFileName?.trim().isNotEmpty == true
        ? currentSlide.photoFileName!.trim()
        : 'screen_photo.jpg';

    if (assetId == null || assetId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Für dieses Foto ist keine Screen-Datei hinterlegt.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final api = ApiService('http://${widget.ip}:8080');
      final file = await api.downloadAssetToLocalCache(
        assetId: assetId,
        fileName: fileName,
        stableContentId: contentId,
      );

      if (!mounted) return;

      if (file == null || !file.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto konnte nicht vom Screen geladen werden.')),
        );
        return;
      }

      setState(() {
        currentSlide.photoPath = file.path;
        currentSlide.photoFileName = fileName;
        currentSlide.imageAssetId = assetId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto wurde auf dieses Tablet geladen und kann jetzt bearbeitet werden.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _showPhotoSourceMenu() async {
    final hasScreenAsset = currentSlide.imageAssetId?.trim().isNotEmpty == true;
    final path = currentSlide.photoPath?.trim();
    final hasLocalPhoto = path != null && path.isNotEmpty && File(path).existsSync();

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: chalkCreamSoft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: chalkMutedText.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Aus Mediathek wählen'),
                  onTap: () => Navigator.pop(context, 'replace'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Foto aufnehmen'),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                if (hasLocalPhoto || hasScreenAsset)
                  ListTile(
                    leading: const Icon(Icons.download_rounded),
                    title: const Text('Foto herunterladen'),
                    subtitle: const Text('Speichert in Galerie/Mediathek im Album TafelFix'),
                    onTap: () => Navigator.pop(context, 'saveToTablet'),
                  ),
                if (hasLocalPhoto)
                  ListTile(
                    leading: const Icon(Icons.tune_rounded),
                    title: const Text('Aktuelles Foto bearbeiten'),
                    subtitle: const Text('Positionieren und Zoomen'),
                    onTap: () => Navigator.pop(context, 'editSoon'),
                  ),
                ListTile(
                  leading: const Icon(Icons.close_rounded),
                  title: const Text('Abbrechen'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null) return;

    if (action == 'saveToTablet') {
      await _saveCurrentPhotoToGallery();
      return;
    }

    if (action == 'editSoon') {
      await _openPhotoPositionEditor();
      return;
    }

    final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final selected = await _pickManagedPhotoFile(source: source);
    if (selected == null) return;

    final fullscreen = await _showPhotoDisplayModeDialog();
    if (fullscreen == null) return;

    setState(() {
      currentSlide.photoPath = selected['path'];
      currentSlide.photoFileName = selected['fileName'];
      currentSlide.imageAssetId = null;
      currentSlide.fullscreenPhoto = fullscreen;
    });
  }

  Future<void> _openPhotoPositionEditor() async {
    final path = currentSlide.photoPath?.trim();
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst ein Foto auswählen oder vom Screen laden.')),
      );
      return;
    }

    final result = await Navigator.push<EditedPhotoResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoPositionEditorScreen(
          imagePath: path,
          isPortrait: _isPortraitPreview(),
          fullscreenPhoto: currentSlide.fullscreenPhoto,
          title: currentSlide.titleController.text.trim(),
          fileNamePrefix: currentSlide.photoFileName?.trim().isNotEmpty == true
              ? currentSlide.photoFileName!.trim()
              : 'tafel_fix_foto.png',
        ),
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    setState(() {
      currentSlide.photoPath = result.path;
      currentSlide.photoFileName = result.fileName;
      currentSlide.imageAssetId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto wurde bearbeitet und lokal gespeichert.')),
    );
  }

  Widget _buildPhotoFields() {
    final path = currentSlide.photoPath?.trim();
    final file = (path != null && path.isNotEmpty) ? File(path) : null;
    final exists = file != null && file.existsSync();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Foto',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showPhotoSourceMenu,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(exists ? 'Foto ersetzen / bearbeiten' : 'Foto auswählen'),
                ),
              ),
              const SizedBox(width: 12),
              if (exists)
                OutlinedButton.icon(
                  onPressed: _removePhotoFromCurrentSlide,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Entfernen'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (exists)
            Text(
              'Foto ist lokal auf diesem Tablet gespeichert und kann weiterverwendet werden.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF18764C),
                    fontWeight: FontWeight.w700,
                  ),
            )
          else if (currentSlide.imageAssetId?.trim().isNotEmpty == true)
            TextButton.icon(
              onPressed: _downloadCurrentPhotoFromScreen,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Foto vom Screen auf dieses Tablet laden'),
            ),
          const SizedBox(height: 16),
          Text(
            'Bilddarstellung',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return chalkCream.withOpacity(0.95);
                }
                return Colors.white.withOpacity(0.42);
              }),
              foregroundColor: MaterialStateProperty.all(chalkText),
              side: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return BorderSide(color: chalkText.withOpacity(0.38), width: 1.2);
                }
                return BorderSide(color: chalkMutedText.withOpacity(0.22));
              }),
              overlayColor: MaterialStateProperty.all(chalkCream.withOpacity(0.18)),
            ),
            segments: const [
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.crop_16_9_rounded),
                label: Text('Mit Titel/Rahmen'),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.fullscreen_rounded),
                label: Text('Fullscreen'),
              ),
            ],
            selected: {currentSlide.fullscreenPhoto},
            onSelectionChanged: (values) {
              setState(() {
                currentSlide.fullscreenPhoto = values.first;
              });
            },
          ),
          const SizedBox(height: 12),
          Text(
            currentSlide.fullscreenPhoto
                ? 'Füllt den Screen ohne Überschrift.'
                : 'Zeigt Überschrift und Foto im Rahmen.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
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
      case TemplateType.drinks:
        return _buildDrinksFields();
      case TemplateType.promo:
        return _buildPromoFields();
      case TemplateType.welcome:
        return _buildWelcomeInfo();
      case TemplateType.photo:
        return _buildPhotoFields();
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
    final resolvedSize = fontSize;
    switch (_getPreviewFontMode()) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'broken',
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
    final resolvedSize = fontSize;
    switch (_getPreviewFontMode()) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'broken',
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
    final resolvedSize = fontSize;
    switch (_getPreviewFontMode()) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'broken',
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

  int _maxMenuItemsPerSlide({bool? portrait}) {
    final usePortrait = portrait ?? _isPortraitPreview();
    return usePortrait ? 10 : 6;
  }

  double _previewTextScale(Map<String, dynamic> slide) {
    return 1.0;
  }

  TextStyle _previewTitleStyleForSlide(
    Map<String, dynamic> slide, {
    required double fontSize,
  }) {
    final resolvedSize = fontSize;
    switch (_getPreviewFontMode()) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'broken',
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

  TextStyle _previewBodyStyleForSlide(
    Map<String, dynamic> slide, {
    required double fontSize,
  }) {
    final resolvedSize = fontSize;
    switch (_getPreviewFontMode()) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'broken',
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

  TextStyle _previewPriceStyleForSlide(
    Map<String, dynamic> slide, {
    required double fontSize,
  }) {
    final resolvedSize = fontSize;
    switch (_getPreviewFontMode()) {
      case 'chalk':
        return TextStyle(
          fontFamily: 'broken',
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

  List<List<T>> _chunkPreviewList<T>(List<T> items, int size) {
    if (items.isEmpty) return const [];
    final chunks = <List<T>>[];
    for (var i = 0; i < items.length; i += size) {
      final end = (i + size < items.length) ? i + size : items.length;
      chunks.add(items.sublist(i, end));
    }
    return chunks;
  }

  List<Map<String, dynamic>> _expandedPreviewSlides() {
    final payload = _buildPayload();
    final rawSlides = (payload['slides'] as List?) ?? [];
    final normalizedSlides = rawSlides
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final expandedSlides = <Map<String, dynamic>>[];
    final maxItems = _maxMenuItemsPerSlide();

    for (final slide in normalizedSlides) {
      final templateType = slide['templateType']?.toString() ?? 'menu';
      if (templateType != 'menu' && templateType != 'drinks') {
        expandedSlides.add(slide);
        continue;
      }

      final rawItems = (slide['items'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((e) =>
                  (e['name']?.toString().trim().isNotEmpty ?? false) ||
                  (e['price']?.toString().trim().isNotEmpty ?? false))
              .toList() ??
          <Map<String, dynamic>>[];

      if (rawItems.isEmpty) {
        expandedSlides.add({...slide, 'items': <Map<String, dynamic>>[]});
        continue;
      }

      final chunks = _chunkPreviewList(rawItems, maxItems);
      for (var i = 0; i < chunks.length; i++) {
        final cloned = Map<String, dynamic>.from(slide);
        cloned['items'] = chunks[i];
        cloned['menuChunkIndex'] = i + 1;
        cloned['menuChunkTotal'] = chunks.length;
        expandedSlides.add(cloned);
      }
    }

    return expandedSlides;
  }

  Map<String, dynamic> _currentPreviewSlide() {
    final expandedSlides = _expandedPreviewSlides();
    if (expandedSlides.isEmpty) {
      return {
        'templateType': currentSlide.templateType.name,
        'title': currentSlide.titleController.text.trim(),
        'subtitle': currentSlide.subtitleController.text.trim(),
        'footer': currentSlide.footerController.text.trim(),
        'highlightTitle': currentSlide.highlightTitleController.text.trim(),
        'highlightPrice': currentSlide.highlightPriceController.text.trim(),
        'items': const <Map<String, dynamic>>[],
        'textScale': 1.0,
        'logoMode': currentSlide.logoMode,
        'logoOpacity': currentSlide.logoOpacity,
        'photoPath': currentSlide.photoPath,
        'fullscreenPhoto': currentSlide.fullscreenPhoto,
        'imageFileName': currentSlide.photoFileName,
        'photoScale': 1.0,
      };
    }

    var previewIndex = 0;
    for (var i = 0; i < selectedSlideIndex && i < slides.length; i++) {
      final type = slides[i].templateType;
      if (type == TemplateType.menu || type == TemplateType.drinks) {
        final itemCount = List.generate(slides[i].itemNameControllers.length, (index) {
          final name = slides[i].itemNameControllers[index].text.trim();
          final price = _displayPrice(slides[i].itemPriceControllers[index].text);
          return {'name': name, 'price': price};
        }).where((e) => (e['name'] ?? '').toString().isNotEmpty || (e['price'] ?? '').toString().isNotEmpty).length;

        final pages = itemCount == 0 ? 1 : (itemCount / _maxMenuItemsPerSlide()).ceil();
        previewIndex += pages;
      } else {
        previewIndex += 1;
      }
    }

    if (previewIndex >= expandedSlides.length) {
      previewIndex = expandedSlides.length - 1;
    }

    return expandedSlides[previewIndex];
  }

  int _currentPreviewPageCountForSelectedSlide() {
    final type = currentSlide.templateType;
    if (type != TemplateType.menu && type != TemplateType.drinks) return 1;
    final itemCount = List.generate(currentSlide.itemNameControllers.length, (index) {
      final name = currentSlide.itemNameControllers[index].text.trim();
      final price = _displayPrice(currentSlide.itemPriceControllers[index].text);
      return {'name': name, 'price': price};
    }).where((e) => (e['name'] ?? '').toString().isNotEmpty || (e['price'] ?? '').toString().isNotEmpty).length;
    if (itemCount == 0) return 1;
    return (itemCount / _maxMenuItemsPerSlide()).ceil();
  }

  Widget _buildPreviewCard() {
    final isPortrait = _isPortraitPreview();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final targetWidth = isPortrait
            ? math.min(availableWidth, 420.0)
            : math.min(availableWidth, 1100.0);

        final virtualWidth = isPortrait ? 1080.0 : 1920.0;
        final virtualHeight = isPortrait ? 1920.0 : 1080.0;

        return Center(
          child: SizedBox(
            width: targetWidth,
            child: AspectRatio(
              aspectRatio: isPortrait ? 9 / 16 : 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: _getBoardColor(),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: virtualWidth,
                      height: virtualHeight,
                      child: Builder(
                        builder: (context) {
                          final usesHeadlinePreview =
                              currentSlide.templateType == TemplateType.promo ||
                              currentSlide.templateType == TemplateType.welcome;

                          final previewSlide = _currentPreviewSlide();
                          final isFullscreenPhotoPreview =
                              previewSlide['templateType']?.toString() == 'photo' &&
                              previewSlide['fullscreenPhoto'] == true;

                          return Stack(
                            children: [
                              if (!isFullscreenPhotoPreview &&
                                  !(previewSlide['templateType']?.toString() == 'photo' &&
                                      (previewSlide['title']?.toString().trim().isNotEmpty ?? false)))
                                _buildLogoPreviewOverlay(
                                  isPortrait: isPortrait,
                                  width: virtualWidth,
                                  height: virtualHeight,
                                  logoMode: _normalizeLogoMode(
                                    previewSlide['logoMode']?.toString(),
                                  ),
                                  logoOpacity: _normalizeLogoOpacity(
                                    previewSlide['logoOpacity'],
                                  ),
                                ),
                              Padding(
                                padding: isFullscreenPhotoPreview
                                    ? EdgeInsets.zero
                                    : usesHeadlinePreview
                                        ? EdgeInsets.symmetric(
                                            horizontal: virtualWidth * 0.07,
                                            vertical: virtualHeight * 0.055,
                                          )
                                        : EdgeInsets.symmetric(
                                            horizontal: isPortrait ? 80 : 120,
                                            vertical: isPortrait ? 60 : 70,
                                          ),
                                child: _buildPreviewSlideContent(1.0),
                              ),
                              if (!isFullscreenPhotoPreview)
                                Positioned(
                                left: 16,
                                bottom: 16,
                                child: Opacity(
                                  opacity: 0.35,
                                  child: Text(
                                    widget.screenName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              if (!isFullscreenPhotoPreview)
                                Positioned(
                                right: 16,
                                bottom: 16,
                                child: Opacity(
                                  opacity: 0.35,
                                  child: Text(
                                    'Vorschau · ${_templateLabel(currentSlide.templateType)} · ${_durationValue(currentSlide)}s',
                                    style: const TextStyle(
                                      fontSize: 14,
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
            ),
          ),
        );
      },
    );
  }

Widget _buildPreviewSlideContent(double scale) {
    final previewSlide = _currentPreviewSlide();
    final templateType =
        previewSlide['templateType']?.toString() ?? currentSlide.templateType.name;

    switch (templateType) {
      case 'menu':
      case 'drinks':
        return _buildMenuPreviewFromPayload(previewSlide);
      case 'promo':
        return _buildPromoPreviewFromPayload(previewSlide);
      case 'welcome':
        return _buildWelcomePreviewFromPayload(previewSlide);
      case 'photo':
        return _buildPhotoPreviewFromPayload(previewSlide);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMenuPreviewFromPayload(Map<String, dynamic> slide) {
    final items = ((slide['items'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final chunkIndex = (slide['menuChunkIndex'] as num?)?.toInt() ?? 1;
    final chunkTotal = (slide['menuChunkTotal'] as num?)?.toInt() ?? 1;

    return MenuBoardWidget(
      title: slide['title']?.toString() ?? '',
      subtitle: slide['subtitle']?.toString() ?? '',
      footer: slide['footer']?.toString() ?? '',
      items: items,
      isPortrait: _isPortraitPreview(),
      pageLabel: chunkTotal > 1 ? 'Teil $chunkIndex von $chunkTotal' : null,
      titleStyleBuilder: (base) =>
          _previewTitleStyleForSlide(slide, fontSize: base),
      bodyStyleBuilder: (base) =>
          _previewBodyStyleForSlide(slide, fontSize: base),
      priceStyleBuilder: (base) =>
          _previewPriceStyleForSlide(slide, fontSize: base),
    );
  }

  Widget _buildPromoPreviewFromPayload(Map<String, dynamic> slide) {
    return HeadlineBoardWidget(
      title: slide['title']?.toString() ?? '',
      subtitle: slide['subtitle']?.toString() ?? '',
      footer: slide['footer']?.toString() ?? '',
      highlightTitle: slide['highlightTitle']?.toString() ?? '',
      highlightPrice: slide['highlightPrice']?.toString() ?? '',
      isPortrait: _isPortraitPreview(),
      isWelcome: false,
      titleStyleBuilder: (base) =>
          _previewTitleStyleForSlide(slide, fontSize: base),
      bodyStyleBuilder: (base) =>
          _previewBodyStyleForSlide(slide, fontSize: base),
      priceStyleBuilder: (base) =>
          _previewPriceStyleForSlide(slide, fontSize: base),
    );
  }

  Widget _buildWelcomePreviewFromPayload(Map<String, dynamic> slide) {
    return HeadlineBoardWidget(
      title: slide['title']?.toString() ?? '',
      subtitle: slide['subtitle']?.toString() ?? '',
      footer: slide['footer']?.toString() ?? '',
      highlightTitle: '',
      highlightPrice: '',
      isPortrait: _isPortraitPreview(),
      isWelcome: true,
      titleStyleBuilder: (base) =>
          _previewTitleStyleForSlide(slide, fontSize: base),
      bodyStyleBuilder: (base) =>
          _previewBodyStyleForSlide(slide, fontSize: base),
      priceStyleBuilder: (base) =>
          _previewPriceStyleForSlide(slide, fontSize: base),
    );
  }


  Widget _buildPhotoFramedPreview({
    required bool isPortrait,
    required String title,
    required double titleScale,
    required double photoScale,
    required Widget child,
  }) {
    final hasTitle = title.trim().isNotEmpty;
    final baseWidth = isPortrait ? 0.82 : 0.86;
    final baseHeight = isPortrait ? 0.74 : 0.76;
    final widthFactor = (baseWidth * photoScale).clamp(0.70, 0.96);
    final heightFactor = ((hasTitle ? baseHeight - 0.06 : baseHeight) * photoScale)
        .clamp(0.58, hasTitle ? 0.78 : 0.86);

    return Column(
      children: [
        if (hasTitle) ...[
          SizedBox(height: isPortrait ? 8 : 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              title.trim(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _getTitleStyle(fontSize: isPortrait ? 22 : 18),
            ),
          ),
        ],
        Expanded(
          child: Center(
            child: FractionallySizedBox(
              widthFactor: widthFactor,
              heightFactor: heightFactor,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0x55F2E9DC),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPreviewFromPayload(Map<String, dynamic> slide) {
    final path = slide['photoPath']?.toString().trim();
    final file = (path != null && path.isNotEmpty) ? File(path) : null;
    final exists = file != null && file.existsSync();
    final isPortrait = _isPortraitPreview();

    return PhotoBoardWidget(
      title: slide['title']?.toString() ?? '',
      isPortrait: isPortrait,
      titleStyleBuilder: (base) => _previewTitleStyleForSlide(
        slide,
        fontSize: base,
      ),
      imageChild: exists
          ? Image.file(
              file,
              fit: BoxFit.cover,
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Kein Foto ausgewählt',
                  textAlign: TextAlign.center,
                  style: _previewBodyStyleForSlide(
                    slide,
                    fontSize: isPortrait ? 22 : 18,
                  ),
                ),
              ),
            ),
      fullscreenPhoto: slide['fullscreenPhoto'] == true,
    );
  }

  ThemeData _chalkEditorTheme(BuildContext context) {
    final base = Theme.of(context);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: chalkMutedText.withOpacity(0.18)),
    );

    return base.copyWith(
      scaffoldBackgroundColor: chalkInk,
      textTheme: base.textTheme.apply(
        bodyColor: chalkText,
        displayColor: chalkText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.52),
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
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return chalkText;
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(chalkCreamSoft),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: chalkCream,
        inactiveTrackColor: chalkCream.withOpacity(0.26),
        thumbColor: chalkCream,
        overlayColor: chalkCream.withOpacity(0.16),
        valueIndicatorColor: chalkInkSoft,
        valueIndicatorTextStyle: const TextStyle(color: chalkCream),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: chalkText,
          side: BorderSide(color: chalkText.withOpacity(0.18)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
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
        backgroundColor: chalkInk,
        body: Center(child: CircularProgressIndicator(color: chalkCream)),
      );
    }

    final editorTheme = _chalkEditorTheme(context);

    return Theme(
      data: editorTheme,
      child: Scaffold(
        backgroundColor: chalkInk,
        appBar: brandedChalkAppBar(title: 'TafelFix Studio', subtitle: _screenTitle()),
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saveContentLocally,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Speichern'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: Colors.white.withOpacity(0.34),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : sendContent,
                    icon: isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined, size: 18),
                    label: Text(isLoading ? 'Senden...' : 'An Screen'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: ChalkBackground(
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ChalkCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(16),
                    opacity: 0.90,
                    child: _buildSlideSelector(),
                  ),
                  const SizedBox(height: 16),
                  ChalkCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(18),
                    opacity: 0.94,
                    child: _buildCommonFields(),
                  ),
                  const SizedBox(height: 16),
                  ChalkCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(18),
                    opacity: 0.94,
                    child: _buildTemplateSpecificFields(),
                  ),
                  const SizedBox(height: 16),
                  ChalkCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(16),
                    opacity: 0.92,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vorschau',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: chalkText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPreviewCard(),
                      ],
                    ),
                  ),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFFFD3D3),
                          fontWeight: FontWeight.w700,
                        ),
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
