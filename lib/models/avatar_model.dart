class AvatarModel {
  final String id;
  final String name;
  final String imagePath;
  final int price;
  final bool isLocked;

  AvatarModel({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.price,
    this.isLocked = true,
  });

  AvatarModel copyWith({
    String? id,
    String? name,
    String? imagePath,
    int? price,
    bool? isLocked,
  }) {
    return AvatarModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      price: price ?? this.price,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}
