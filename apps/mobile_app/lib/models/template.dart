enum TemplateType {
  menu,
  drinks,
  promo,
  welcome,
  photo,
}

class Template {
  final String id;
  final String name;
  final TemplateType type;
  final String previewTitle;
  final String previewSubtitle;

  const Template({
    required this.id,
    required this.name,
    required this.type,
    required this.previewTitle,
    required this.previewSubtitle,
  });

  factory Template.fromJson(Map<String, dynamic> json) {
    return Template(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: _templateTypeFromString(json['type'] as String?),
      previewTitle: json['previewTitle'] as String? ?? '',
      previewSubtitle: json['previewSubtitle'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'previewTitle': previewTitle,
      'previewSubtitle': previewSubtitle,
    };
  }

  static TemplateType _templateTypeFromString(String? value) {
    switch (value) {
      case 'menu':
        return TemplateType.menu;
      case 'drinks':
        return TemplateType.drinks;
      case 'promo':
        return TemplateType.promo;
      case 'welcome':
        return TemplateType.welcome;
      case 'photo':
        return TemplateType.photo;
      default:
        return TemplateType.menu;
    }
  }
}