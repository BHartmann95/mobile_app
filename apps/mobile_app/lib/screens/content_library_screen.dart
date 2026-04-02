import 'package:flutter/material.dart';
import '../models/saved_content.dart';
import '../models/template.dart';
import '../services/api_service.dart';
import '../services/content_storage_service.dart';
import '../services/storage_service.dart';
import 'template_editor_screen.dart';

enum ContentLibraryFilter {
  all,
  menu,
  promo,
  welcome,
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

  List<SavedContent> _filteredContents() {
    final query = searchController.text.trim().toLowerCase();

    return contents.where((content) {
      final primaryType = _primaryTypeOf(content);

      final matchesFilter = switch (selectedFilter) {
        ContentLibraryFilter.all => true,
        ContentLibraryFilter.menu => primaryType == TemplateType.menu,
        ContentLibraryFilter.promo => primaryType == TemplateType.promo,
        ContentLibraryFilter.welcome => primaryType == TemplateType.welcome,
      };

      if (!matchesFilter) {
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
        slideText,
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  void openContent(SavedContent content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditorScreen(
          ip: widget.ip,
          screenName: widget.screenName,
          screenOrientation: widget.screenOrientation,
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

    final renamed = content.copyWith(
      name: newName.trim(),
    );

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

  Future<void> sendContentToScreen(SavedContent content) async {
    setState(() {
      sendingContentId = content.id;
    });

    try {
      final isOnline = await _ensureScreenOnline();

      if (!isOnline) {
        if (!mounted) return;

        await _showSendErrorDialog(
          title: 'Senden nicht möglich',
          message:
              'Der Screen "${widget.screenName}" ist offline oder antwortet nicht.',
          onRetry: () => sendContentToScreen(content),
        );

        if (!mounted) return;
        setState(() {
          sendingContentId = null;
        });
        return;
      }

      final api = ApiService('http://${widget.ip}:8080');
      final payload = _buildPayloadFromSavedContent(content);
      print('LIBRARY PAYLOAD: $payload');
      print('LIBRARY ORIENTATION: ${payload['orientation']}');
      
      final int contentVersion = payload['contentVersion'] as int;

      final result = await api.sendContent(payload);

      if (!mounted) return;

      if (result.success) {
        final updated = content.copyWith(
          lastUsedScreenIp: widget.ip,
        );

        final contentStorage = ContentStorageService();
        await contentStorage.addOrUpdateContent(updated);

        final screenStorage = StorageService();
        await screenStorage.markContentSent(
          ip: widget.ip,
          contentVersion: contentVersion,
        );

        await loadContents();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${content.name}" mit ${content.slides.length} Slide(s) wurde gesendet',
            ),
          ),
        );
      } else {
        await _showSendErrorDialog(
          title: 'Senden fehlgeschlagen',
          message: result.error ?? 'Content konnte nicht gesendet werden.',
          onRetry: () => sendContentToScreen(content),
        );
      }
    } catch (e) {
      if (!mounted) return;

      await _showSendErrorDialog(
        title: 'Fehler beim Senden',
        message: 'Es ist ein unerwarteter Fehler aufgetreten:\n$e',
        onRetry: () => sendContentToScreen(content),
      );
    }

    if (!mounted) return;

    setState(() {
      sendingContentId = null;
    });
  }

  Map<String, dynamic> _buildPayloadFromSavedContent(SavedContent content) {
    final contentVersion = DateTime.now().millisecondsSinceEpoch;

    return {
      'contentVersion': contentVersion,
      'orientation': widget.screenOrientation,
      'boardStyle': content.boardStyle,
      'fontStyle': content.fontStyle,
      'slides': List.generate(content.slides.length, (index) {
        final slide = content.slides[index];

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
        };
      }),
    };
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

  String templateLabel(TemplateType type) {
    switch (type) {
      case TemplateType.menu:
        return 'Menü';
      case TemplateType.promo:
        return 'Aktion';
      case TemplateType.welcome:
        return 'Willkommen';
    }
  }

  String _filterLabel(ContentLibraryFilter filter) {
    switch (filter) {
      case ContentLibraryFilter.all:
        return 'Alle';
      case ContentLibraryFilter.menu:
        return 'Menü';
      case ContentLibraryFilter.promo:
        return 'Aktion';
      case ContentLibraryFilter.welcome:
        return 'Willkommen';
    }
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Inhalte suchen',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
    );
  }

  Widget _buildContentTile(SavedContent content) {
    final isSending = sendingContentId == content.id;
    final primaryType = _primaryTypeOf(content);
    final orientationLabel =
        widget.screenOrientation == 'portrait' ? 'Portrait' : 'Landscape';

    return ListTile(
      title: Text(content.name),
      subtitle: Text(
        '${templateLabel(primaryType)}'
        ' • ${content.slides.length} Slide(s)'
        ' • $orientationLabel'
        '${content.lastUsedScreenIp != null ? " • zuletzt: ${content.lastUsedScreenIp}" : ""}',
      ),
      onTap: () => openContent(content),
      onLongPress: () => showOptions(content),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSending)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => sendContentToScreen(content),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => showOptions(content),
          ),
        ],
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Bibliothek'),
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: filteredContents.isEmpty
                ? Center(
                    child: Text(
                      contents.isEmpty
                          ? 'Keine Inhalte vorhanden'
                          : 'Keine Inhalte für diese Suche oder diesen Filter gefunden',
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredContents.length,
                    itemBuilder: (context, index) {
                      final content = filteredContents[index];
                      return _buildContentTile(content);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}