import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets/app_chalk_style.dart';
import '../widgets/photo_board_widget.dart';

class EditedPhotoResult {
  final String path;
  final String fileName;

  const EditedPhotoResult({
    required this.path,
    required this.fileName,
  });
}

class PhotoPositionEditorScreen extends StatefulWidget {
  final String imagePath;
  final bool isPortrait;
  final bool fullscreenPhoto;
  final String title;
  final String fileNamePrefix;

  const PhotoPositionEditorScreen({
    super.key,
    required this.imagePath,
    required this.isPortrait,
    required this.fullscreenPhoto,
    required this.title,
    required this.fileNamePrefix,
  });

  @override
  State<PhotoPositionEditorScreen> createState() => _PhotoPositionEditorScreenState();
}

class _PhotoPositionEditorScreenState extends State<PhotoPositionEditorScreen> {
  final GlobalKey _captureKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  bool _isSaving = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  String _sanitizeFileName(String raw) {
    final sanitized = raw.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return sanitized.isEmpty ? 'tafel_fix_foto' : sanitized;
  }

  String _editedFileName() {
    final prefix = _sanitizeFileName(widget.fileNamePrefix);
    final base = prefix.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${base}_bearbeitet_$timestamp.png';
  }

  void _resetTransform() {
    _transformController.value = Matrix4.identity();
  }

  Future<void> _saveEditedPhoto() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 60));

      final boundaryContext = _captureKey.currentContext;
      final renderObject = boundaryContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw Exception('Bildbereich konnte nicht erfasst werden.');
      }

      final size = renderObject.size;
      final targetWidth = widget.isPortrait ? 1080 : 1920;
      final targetHeight = widget.isPortrait ? 1920 : 1080;
      final pixelRatio = math.max(
        targetWidth / math.max(size.width, 1),
        targetHeight / math.max(size.height, 1),
      ).clamp(1.0, 6.0).toDouble();

      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Bild konnte nicht gespeichert werden.');
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${docsDir.path}/managed_photos/edited');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final fileName = _editedFileName();
      final targetFile = File('${targetDir.path}/$fileName');
      await targetFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      if (!mounted) return;
      Navigator.pop(
        context,
        EditedPhotoResult(path: targetFile.path, fileName: fileName),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto konnte nicht bearbeitet gespeichert werden: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildEditableImage() {
    final file = File(widget.imagePath);

    return RepaintBoundary(
      key: _captureKey,
      child: Container(
        color: Colors.black,
        child: ClipRect(
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 1.0,
            maxScale: 5.0,
            boundaryMargin: const EdgeInsets.all(260),
            clipBehavior: Clip.none,
            child: SizedBox.expand(
              child: Image.file(
                file,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewAspect = widget.isPortrait ? 9 / 16 : 16 / 9;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: chalkInk,
        appBarTheme: const AppBarTheme(
          backgroundColor: chalkInk,
          foregroundColor: chalkCream,
          elevation: 0,
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
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: chalkCream,
            side: BorderSide(color: chalkCream.withOpacity(0.55)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      child: Scaffold(
        appBar: brandedChalkAppBar(
          title: 'TafelFix Studio',
          subtitle: 'Foto positionieren',
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _resetTransform,
              child: const Text('Zurücksetzen'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                child: Text(
                  'Bild mit zwei Fingern zoomen und verschieben.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: chalkCream.withOpacity(0.84),
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: AspectRatio(
                      aspectRatio: previewAspect,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.32),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: PhotoBoardWidget(
                          title: widget.title,
                          isPortrait: widget.isPortrait,
                          fullscreenPhoto: widget.fullscreenPhoto,
                          titleStyleBuilder: (base) => TextStyle(
                            fontSize: base,
                            color: chalkCream,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                          imageChild: _buildEditableImage(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: chalkCreamSoft.withOpacity(0.92),
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
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Abbrechen'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: chalkText,
                          side: BorderSide(color: chalkText.withOpacity(0.18)),
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveEditedPhoto,
                        icon: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_isSaving ? 'Speichern...' : 'Speichern'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
