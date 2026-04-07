import 'dart:convert';
import 'template.dart';

class SavedMenuItem {
  final String name;
  final String price;
  final bool soldOut;

  const SavedMenuItem({
    required this.name,
    required this.price,
    this.soldOut = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'soldOut': soldOut,
    };
  }

  factory SavedMenuItem.fromJson(Map<String, dynamic> json) {
    return SavedMenuItem(
      name: (json['name'] ?? '').toString(),
      price: (json['price'] ?? '').toString(),
      soldOut: json['soldOut'] == true,
    );
  }

  SavedMenuItem copyWith({
    String? name,
    String? price,
    bool? soldOut,
  }) {
    return SavedMenuItem(
      name: name ?? this.name,
      price: price ?? this.price,
      soldOut: soldOut ?? this.soldOut,
    );
  }
}

class SavedSlide {
  final String id;
  final TemplateType templateType;
  final String title;
  final String subtitle;
  final String footer;
  final String? highlightTitle;
  final String? highlightPrice;
  final List<SavedMenuItem> items;
  final int durationSeconds;
  final double textScale;

  const SavedSlide({
    required this.id,
    required this.templateType,
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.highlightTitle,
    required this.highlightPrice,
    required this.items,
    required this.durationSeconds,
    this.textScale = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templateType': templateType.name,
      'title': title,
      'subtitle': subtitle,
      'footer': footer,
      'highlightTitle': highlightTitle,
      'highlightPrice': highlightPrice,
      'items': items.map((e) => e.toJson()).toList(),
      'durationSeconds': durationSeconds,
      'textScale': textScale,
    };
  }

  factory SavedSlide.fromJson(Map<String, dynamic> json) {
    return SavedSlide(
      id: (json['id'] ?? '').toString(),
      templateType: _templateTypeFromString((json['templateType'] ?? 'menu').toString()),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      footer: (json['footer'] ?? '').toString(),
      highlightTitle: json['highlightTitle']?.toString(),
      highlightPrice: json['highlightPrice']?.toString(),
      items: ((json['items'] as List?) ?? [])
          .map((e) => SavedMenuItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 10,
      textScale: ((json['textScale'] as num?)?.toDouble() ?? 1.0).clamp(0.8, 1.25),
    );
  }

  SavedSlide copyWith({
    String? id,
    TemplateType? templateType,
    String? title,
    String? subtitle,
    String? footer,
    String? highlightTitle,
    String? highlightPrice,
    List<SavedMenuItem>? items,
    int? durationSeconds,
    double? textScale,
  }) {
    return SavedSlide(
      id: id ?? this.id,
      templateType: templateType ?? this.templateType,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      footer: footer ?? this.footer,
      highlightTitle: highlightTitle ?? this.highlightTitle,
      highlightPrice: highlightPrice ?? this.highlightPrice,
      items: items ?? this.items,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      textScale: textScale ?? this.textScale,
    );
  }

  static TemplateType _templateTypeFromString(String value) {
    switch (value) {
      case 'drinks':
        return TemplateType.drinks;
      case 'promo':
        return TemplateType.promo;
      case 'welcome':
        return TemplateType.welcome;
      case 'menu':
      default:
        return TemplateType.menu;
    }
  }
}

class SavedContent {
  final String id;
  final String name;
  final TemplateType? templateType;
  final String? lastUsedScreenIp;
  final List<SavedSlide> slides;
  final String boardStyle;
  final String fontStyle;
  final String orientation;

  const SavedContent({
    required this.id,
    required this.name,
    this.templateType,
    this.lastUsedScreenIp,
    required this.slides,
    this.boardStyle = 'black',
    this.fontStyle = 'chalk',
    this.orientation = 'unknown',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'templateType': templateType?.name,
      'lastUsedScreenIp': lastUsedScreenIp,
      'slides': slides.map((e) => e.toJson()).toList(),
      'boardStyle': boardStyle,
      'fontStyle': fontStyle,
      'orientation': orientation,
    };
  }

  factory SavedContent.fromJson(Map<String, dynamic> json) {
    final rawSlides = ((json['slides'] as List?) ?? [])
        .map((e) => SavedSlide.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return SavedContent(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      templateType: rawSlides.isNotEmpty ? rawSlides.first.templateType : TemplateType.menu,
      lastUsedScreenIp: json['lastUsedScreenIp']?.toString(),
      slides: rawSlides,
      boardStyle: (json['boardStyle'] ?? 'black').toString(),
      fontStyle: _normalizeFontStyle(json['fontStyle']?.toString()),
      orientation: _normalizeOrientation(json['orientation']?.toString()),
    );
  }

  static String _normalizeFontStyle(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'standard':
      case 'normal':
      case 'classic':
        return 'standard';
      case 'chalk':
      case 'kreide':
      case 'chalk1':
      case 'chalk2':
      case 'chalk3':
      case 'schrift 1':
      case 'schrift 2':
      case 'schrift 3':
      default:
        return 'chalk';
    }
  }


  static String _normalizeOrientation(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized == 'portrait') return 'portrait';
    if (normalized == 'landscape') return 'landscape';
    return 'unknown';
  }

  SavedContent copyWith({
    String? id,
    String? name,
    TemplateType? templateType,
    String? lastUsedScreenIp,
    List<SavedSlide>? slides,
    String? boardStyle,
    String? fontStyle,
    String? orientation,
  }) {
    return SavedContent(
      id: id ?? this.id,
      name: name ?? this.name,
      templateType: templateType ?? this.templateType,
      lastUsedScreenIp: lastUsedScreenIp ?? this.lastUsedScreenIp,
      slides: slides ?? this.slides,
      boardStyle: boardStyle ?? this.boardStyle,
      fontStyle: fontStyle ?? this.fontStyle,
      orientation: orientation ?? this.orientation,
    );
  }

  static List<SavedContent> decodeList(String raw) {
    if (raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .map((e) => SavedContent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static String encodeList(List<SavedContent> contents) {
    return jsonEncode(contents.map((e) => e.toJson()).toList());
  }
}
