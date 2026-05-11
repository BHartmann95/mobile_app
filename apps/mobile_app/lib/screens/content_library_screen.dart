import 'dart:io';
import 'package:flutter/material.dart';
import '../models/saved_content.dart';
import '../models/screen.dart';
import '../models/template.dart';
import '../services/api_service.dart';
import '../services/content_storage_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_chalk_style.dart';
import 'template_editor_screen.dart';
import 'template_selection_screen.dart';

enum ContentLibraryFilter {
  all,
  menu,
  drinks,
  promo,
  welcome,
  photo,
}

enum ContentOrientationFilter {
  all,
  portrait,
  landscape,
}

class ContentLibraryScreen extends StatefulWidget {
  final String ip;
  final String screenName;
  final String screenOrientation;

  const ContentLibraryScreen({
    super.key,
    required this.ip,
    required this.screenName,
    required this.screenOrientation,
  });

  @override
  State<ContentLibraryScreen> createState() => _ContentLibraryScreenState();
}

class _ContentLibraryScreenState extends State<ContentLibraryScreen> {
  List<SavedContent> contents = [];
  bool isLoading = true;
  String? sendingContentId;

  final searchController = TextEditingController();
  ContentLibraryFilter selectedFilter = ContentLibraryFilter.all;
  ContentOrientationFilter selectedOrientationFilter =
      ContentOrientationFilter.all;

  @override
  void initState() {
    super.initState();
    loadContents();
    searchController.addListener(_refreshFilter);
  }

  void _refreshFilter() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> loadContents() async {
    final storage = ContentStorageService();
    final loaded = await storage.loadContents();

    if (!mounted) return;

    setState(() {
      contents = loaded;
      isLoading = false;
    });
  }

  TemplateType _primaryTypeOf(SavedContent content) {
    if (content.slides.isNotEmpty) {
      return content.slides.first.templateType;
    }
    return content.templateType ?? TemplateType.menu;
  }

  String _normalizedContentOrientation(SavedContent content) {
    final normalized = content.orientation.trim().toLowerCase();
    if (normalized == 'portrait' || normalized == 'landscape') {
      return normalized;
    }
    return 'unknown';
  }

  String _resolvedEditorOrientation(SavedContent content) {
    final normalized = _normalizedContentOrientation(content);
    if (normalized == 'portrait' || normalized == 'landscape') {
      return normalized;
    }
    return widget.screenOrientation;
  }

  List<SavedContent> _filteredContents() {
    final query = searchController.text.trim().toLowerCase();

    return contents.where((content) {
      final primaryType = _primaryTypeOf(content);
      final contentOrientation = _normalizedContentOrientation(content);

      final matchesTemplateFilter = switch (selectedFilter) {
        ContentLibraryFilter.all => true,
        ContentLibraryFilter.menu => primaryType == TemplateType.menu,
        ContentLibraryFilter.drinks => primaryType == TemplateType.drinks,
        ContentLibraryFilter.promo => primaryType == TemplateType.promo,
        ContentLibraryFilter.welcome => primaryType == TemplateType.welcome,
        ContentLibraryFilter.photo => primaryType == TemplateType.photo,
      };

      final matchesOrientationFilter = switch (selectedOrientationFilter) {
        ContentOrientationFilter.all => true,
        ContentOrientationFilter.portrait => contentOrientation == 'portrait',
        ContentOrientationFilter.landscape => contentOrientation == 'landscape',
      };

      if (!matchesTemplateFilter || !matchesOrientationFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final slideText = content.slides.map((slide) {
        return [
          slide.title,
          slide.subtitle,
          slide.footer,
          slide.highlightTitle ?? '',
          slide.highlightPrice ?? '',
          ...slide.items.map((e) => e.name),
          ...slide.items.map((e) => e.price),
        ].join(' ');
      }).join(' ');

      final haystack = [
        content.name,
        contentOrientation,
        slideText,
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  Future<void> createNewTemplate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateSelectionScreen(
          ip: widget.ip,
          screenName: widget.screenName,
          screenOrientation: widget.screenOrientation,
        ),
      ),
    );
    await loadContents();
  }

  Future<void> openContent(SavedContent content) async {
    await Future.delayed(const Duration(milliseconds: 50));

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditorScreen(
          ip: widget.ip,
          screenName: widget.screenName,
          screenOrientation: _resolvedEditorOrientation(content),
          templateType: _primaryTypeOf(content),
          initialContent: content,
        ),
      ),
    ).then((_) => loadContents());
  }

  Future<void> renameContent(SavedContent content) async {
    final controller = TextEditingController(text: content.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Inhalt umbenennen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Neuer Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (newName == null || newName.trim().isEmpty) return;

    final renamed = content.copyWith(name: newName.trim());

    final storage = ContentStorageService();
    await storage.addOrUpdateContent(renamed);
    await loadContents();
  }

  Future<void> deleteContent(SavedContent content) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Inhalt löschen'),
        content: Text('Soll "${content.name}" wirklich gelöscht werden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final storage = ContentStorageService();
    await storage.deleteContent(content.id);
    await loadContents();
  }

  Future<void> duplicateContent(SavedContent content) async {
    final controller = TextEditingController(text: '${content.name} Kopie');

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Inhalt duplizieren'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Name der Kopie',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Duplizieren'),
          ),
        ],
      ),
    );

    if (newName == null || newName.trim().isEmpty) return;

    final duplicatedSlides = content.slides.map<SavedSlide>((slide) {
      return slide.copyWith(
        items: slide.items.map<SavedMenuItem>((e) {
          return SavedMenuItem(
            name: e.name,
            price: e.price,
            soldOut: e.soldOut,
          );
        }).toList(),
      );
    }).toList();

    final duplicate = content.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: newName.trim(),
      lastUsedScreenIp: null,
      slides: duplicatedSlides,
    );

    final storage = ContentStorageService();
    await storage.addOrUpdateContent(duplicate);
    await loadContents();
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

  ({Map<String, dynamic> payload, List<UploadableAsset> assets})
      _buildPackageFromSavedContent(SavedContent content) {
    final contentVersion = DateTime.now().millisecondsSinceEpoch;
    final orientation = _normalizedContentOrientation(content);
    final assets = <UploadableAsset>[];

    final payload = {
      'contentVersion': contentVersion,
      'contentName': content.name,
      'orientation': orientation == 'unknown' ? widget.screenOrientation : orientation,
      'boardStyle': content.boardStyle,
      'fontStyle': content.fontStyle,
      'logoBase64': content.logoBase64,
      'slides': List.generate(content.slides.length, (index) {
        final slide = content.slides[index];
        String? imageAssetId;
        String? imageFileName;

        if (slide.templateType == TemplateType.photo) {
          final photoPath = slide.photoPath?.trim();
          if (photoPath != null && photoPath.isNotEmpty) {
            final file = File(photoPath);
            if (file.existsSync()) {
              imageFileName = slide.photoFileName?.trim().isNotEmpty == true
                  ? slide.photoFileName!.trim()
                  : file.uri.pathSegments.last;
              imageAssetId = 'content_${contentVersion}_slide_${index + 1}_$imageFileName';
              assets.add(
                UploadableAsset(
                  assetId: imageAssetId,
                  fileName: imageFileName,
                  file: file,
                ),
              );
            }
          }

          imageFileName ??= slide.photoFileName?.trim().isNotEmpty == true
              ? slide.photoFileName!.trim()
              : null;
          imageAssetId ??= slide.imageAssetId?.trim().isNotEmpty == true
              ? slide.imageAssetId!.trim()
              : null;
        }

        return {
          'slideId': 'slide_${(index + 1).toString().padLeft(3, '0')}',
          'templateType': slide.templateType.name,
          'durationSeconds': slide.durationSeconds,
          'textScale': slide.textScale,
          'title': slide.title,
          'subtitle': slide.subtitle,
          'items': slide.items
              .map(
                (e) => {
                  'name': e.name,
                  'price': e.price,
                  'soldOut': e.soldOut,
                },
              )
              .toList(),
          'footer': slide.footer,
          'highlightTitle': slide.highlightTitle,
          'highlightPrice': slide.highlightPrice,
          'logoMode': slide.logoMode,
          'logoOpacity': slide.logoOpacity,
          'imageAssetId': imageAssetId,
          'imageFileName': imageFileName,
          'photoPath': slide.photoPath,
          'photoScale': slide.photoScale,
          'fullscreenPhoto': slide.fullscreenPhoto,
        };
      }),
    };

    return (payload: payload, assets: assets);
  }

  Future<List<ScreenDevice>> _loadAvailableScreens() async {
    final storage = StorageService();
    return storage.loadScreens();
  }

  Future<List<ScreenDevice>?> _showMultiSendDialog(
    List<ScreenDevice> screens,
    SavedContent content,
  ) async {
    final selectedIps = <String>{};
    final contentOrientation = _normalizedContentOrientation(content);

    final matchingScreens = contentOrientation == 'unknown'
        ? screens
        : screens.where((screen) => screen.orientation == contentOrientation).toList();

    for (final screen in matchingScreens) {
      selectedIps.add(screen.ip);
    }

    return showDialog<List<ScreenDevice>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('An welche Screens senden?'),
            content: SizedBox(
              width: double.maxFinite,
              child: screens.isEmpty
                  ? const Text('Keine Screens gespeichert.')
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: screens.map((screen) {
                          final isSelected = selectedIps.contains(screen.ip);
                          final matchesOrientation = contentOrientation == 'unknown'
                              ? true
                              : screen.orientation == contentOrientation;

                          return CheckboxListTile(
                            value: isSelected,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: Text(screen.name),
                            subtitle: Text(
                              '${screen.ip} • ${screen.orientation == 'portrait' ? 'Portrait' : 'Landscape'}${matchesOrientation ? '' : ' • passt nicht'}',
                            ),
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedIps.add(screen.ip);
                                } else {
                                  selectedIps.remove(screen.ip);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: screens.isEmpty || selectedIps.isEmpty
                    ? null
                    : () {
                        final selectedScreens = screens
                            .where((screen) => selectedIps.contains(screen.ip))
                            .toList();
                        Navigator.pop(context, selectedScreens);
                      },
                child: const Text('Senden'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> sendContentToMultipleScreens(SavedContent content) async {
    setState(() {
      sendingContentId = content.id;
    });

    try {
      final screens = await _loadAvailableScreens();
      final selectedScreens = await _showMultiSendDialog(screens, content);

      if (selectedScreens == null || selectedScreens.isEmpty) {
        if (!mounted) return;
        setState(() {
          sendingContentId = null;
        });
        return;
      }

      int successCount = 0;
      int offlineCount = 0;
      int failedCount = 0;

      final contentStorage = ContentStorageService();
      final screenStorage = StorageService();

      for (final screen in selectedScreens) {
        try {
          final api = ApiService('http://${screen.ip}:8080');
          final status = await api.getStatus();

          if (!status.isOnline) {
            offlineCount++;
            continue;
          }

          final package = _buildPackageFromSavedContent(content);
          final payload = package.payload;
          final int contentVersion = payload['contentVersion'] as int;
          final result = await api.sendContentPackage(payload, package.assets);

          if (result.success) {
            successCount++;
            await screenStorage.markContentSent(
              ip: screen.ip,
              contentVersion: contentVersion,
              contentName: content.name,
            );
          } else {
            failedCount++;
          }
        } catch (_) {
          failedCount++;
        }
      }

      final updated = content.copyWith(
        lastUsedScreenIp: selectedScreens.length == 1 ? selectedScreens.first.ip : null,
      );
      await contentStorage.addOrUpdateContent(updated);
      await loadContents();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$successCount erfolgreich • $offlineCount offline • $failedCount fehlgeschlagen',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      await _showSendErrorDialog(
        title: 'Fehler beim Senden',
        message: 'Es ist ein unerwarteter Fehler aufgetreten:\n$e',
        onRetry: () => sendContentToMultipleScreens(content),
      );
    }

    if (!mounted) return;

    setState(() {
      sendingContentId = null;
    });
  }

  String templateLabel(TemplateType type) {
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

  String _filterLabel(ContentLibraryFilter filter) {
    switch (filter) {
      case ContentLibraryFilter.all:
        return 'Alle';
      case ContentLibraryFilter.menu:
        return 'Menü';
      case ContentLibraryFilter.drinks:
        return 'Getränke';
      case ContentLibraryFilter.promo:
        return 'Aktion';
      case ContentLibraryFilter.welcome:
        return 'Willkommen';
      case ContentLibraryFilter.photo:
        return 'Foto';
    }
  }

  String _orientationFilterLabel(ContentOrientationFilter filter) {
    switch (filter) {
      case ContentOrientationFilter.all:
        return 'Alle';
      case ContentOrientationFilter.portrait:
        return 'Portrait';
      case ContentOrientationFilter.landscape:
        return 'Landscape';
    }
  }

  String _orientationLabelForContent(SavedContent content) {
    switch (_normalizedContentOrientation(content)) {
      case 'portrait':
        return 'Portrait';
      case 'landscape':
        return 'Landscape';
      default:
        return 'Unbekannt';
    }
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Vorlagen suchen',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          searchController.clear();
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFFF7F5EF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Format',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ContentOrientationFilter.values.map((filter) {
                  final isSelected = selectedOrientationFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_orientationFilterLabel(filter)),
                      selected: isSelected,
                      selectedColor: chalkCream,
                      onSelected: (_) {
                        setState(() {
                          selectedOrientationFilter = filter;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Typ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ContentLibraryFilter.values.map((filter) {
                  final isSelected = selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_filterLabel(filter)),
                      selected: isSelected,
                      selectedColor: chalkCream,
                      onSelected: (_) {
                        setState(() {
                          selectedFilter = filter;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTile(SavedContent content) {
    final isSending = sendingContentId == content.id;
    final primaryType = _primaryTypeOf(content);
    final orientationLabel = _orientationLabelForContent(content);

    return ChalkCard(
      onTap: () => openContent(content),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: chalkCream.withOpacity(0.92),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              primaryType == TemplateType.photo
                  ? Icons.image_rounded
                  : primaryType == TemplateType.drinks
                      ? Icons.local_cafe_rounded
                      : primaryType == TemplateType.promo
                          ? Icons.campaign_rounded
                          : primaryType == TemplateType.welcome
                              ? Icons.waving_hand_rounded
                              : Icons.restaurant_menu_rounded,
              color: chalkText,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: chalkText,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChalkPill(
                      label: templateLabel(primaryType),
                      background: const Color(0xFFF2F0EA),
                      foreground: const Color(0xFF5D5549),
                    ),
                    ChalkPill(
                      label: '${content.slides.length} Slide(s)',
                      background: const Color(0xFFE5F7ED),
                      foreground: const Color(0xFF18764C),
                    ),
                    ChalkPill(
                      label: orientationLabel,
                      background: const Color(0xFFFFF0D6),
                      foreground: const Color(0xFF9A6400),
                    ),
                  ],
                ),
                if (content.lastUsedScreenIp != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'zuletzt: ${content.lastUsedScreenIp}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isSending)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: () => sendContentToMultipleScreens(content),
              tooltip: 'Vorlage an Screens senden',
            ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => showOptions(content),
          ),
        ],
      ),
    );
  }

  void showOptions(SavedContent content) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Bearbeiten'),
              onTap: () {
                Navigator.pop(context);
                openContent(content);
              },
            ),
            ListTile(
              title: const Text('Umbenennen'),
              onTap: () {
                Navigator.pop(context);
                renameContent(content);
              },
            ),
            ListTile(
              title: const Text('Duplizieren'),
              onTap: () {
                Navigator.pop(context);
                duplicateContent(content);
              },
            ),
            ListTile(
              title: const Text('Löschen'),
              onTap: () {
                Navigator.pop(context);
                deleteContent(content);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.removeListener(_refreshFilter);
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredContents = _filteredContents();

    if (isLoading) {
      return const Scaffold(
        backgroundColor: chalkInk,
        body: Center(child: CircularProgressIndicator(color: chalkCream)),
      );
    }

    return Scaffold(
      backgroundColor: chalkInk,
      appBar: brandedChalkAppBar(title: 'TafelFix Studio', subtitle: 'Meine Vorlagen'),
      body: ChalkBackground(
        child: Column(
          children: [
            _buildSearchAndFilters(),
            Expanded(
              child: filteredContents.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          contents.isEmpty
                              ? 'Noch keine Vorlagen vorhanden'
                              : 'Keine Vorlagen für diese Suche gefunden',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: filteredContents.length,
                      itemBuilder: (context, index) {
                        final content = filteredContents[index];
                        return _buildContentTile(content);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: chalkCream,
        foregroundColor: chalkText,
        onPressed: createNewTemplate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Neue Vorlage'),
      ),
    );
  }

}
