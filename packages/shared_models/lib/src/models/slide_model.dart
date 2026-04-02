import '../enums/background_type.dart';
import 'menu_item_model.dart';

class SlideModel {
  final String slideId;
  final String templateId;
  final int durationSeconds;
  final String title;
  final String subtitle;
  final List<MenuItemModel> items;
  final String footer;
  final BackgroundType backgroundType;
  final String backgroundValue;
  final int sortOrder;

  const SlideModel({
    required this.slideId,
    required this.templateId,
    required this.durationSeconds,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.footer,
    required this.backgroundType,
    required this.backgroundValue,
    required this.sortOrder,
  });

  factory SlideModel.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];

    return SlideModel(
      slideId: json['slideId'] as String? ?? '',
      templateId: json['templateId'] as String? ?? '',
      durationSeconds: json['durationSeconds'] as int? ?? 5,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      items: itemsJson
          .map((item) => MenuItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      footer: json['footer'] as String? ?? '',
      backgroundType: BackgroundType.fromString(
        json['backgroundType'] as String? ?? 'color',
      ),
      backgroundValue: json['backgroundValue'] as String? ?? '#000000',
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}