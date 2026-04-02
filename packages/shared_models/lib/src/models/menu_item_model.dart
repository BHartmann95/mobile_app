class MenuItemModel {
  final String name;
  final String price;

  const MenuItemModel({
    required this.name,
    required this.price,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      name: json['name'] as String? ?? '',
      price: json['price'] as String? ?? '',
    );
  }
}