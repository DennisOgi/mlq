enum AvatarItemCategory {
  hair,
  face,
  outfit,
  accessory,
  background,
}

enum AvatarItemRarity {
  common,
  rare,
  epic,
  legendary,
}

class AvatarItemModel {
  final String id;
  final String name;
  final AvatarItemCategory category;
  final AvatarItemRarity rarity;
  final String imageAsset;
  final int coinCost;
  final bool isPremium;
  final String? unlockCondition; // e.g., "100_day_streak", "level_10"
  final bool isSeasonalItem;
  final DateTime? availableUntil;

  AvatarItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.rarity,
    required this.imageAsset,
    required this.coinCost,
    this.isPremium = false,
    this.unlockCondition,
    this.isSeasonalItem = false,
    this.availableUntil,
  });

  factory AvatarItemModel.fromJson(Map<String, dynamic> json) {
    return AvatarItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: AvatarItemCategory.values.firstWhere(
        (e) => e.toString() == 'AvatarItemCategory.${json['category']}',
      ),
      rarity: AvatarItemRarity.values.firstWhere(
        (e) => e.toString() == 'AvatarItemRarity.${json['rarity']}',
      ),
      imageAsset: json['image_asset'] as String,
      coinCost: json['coin_cost'] as int,
      isPremium: json['is_premium'] as bool? ?? false,
      unlockCondition: json['unlock_condition'] as String?,
      isSeasonalItem: json['is_seasonal_item'] as bool? ?? false,
      availableUntil: json['available_until'] != null
          ? DateTime.parse(json['available_until'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.toString().split('.').last,
      'rarity': rarity.toString().split('.').last,
      'image_asset': imageAsset,
      'coin_cost': coinCost,
      'is_premium': isPremium,
      'unlock_condition': unlockCondition,
      'is_seasonal_item': isSeasonalItem,
      'available_until': availableUntil?.toIso8601String(),
    };
  }

  bool get isAvailable {
    if (!isSeasonalItem) return true;
    if (availableUntil == null) return true;
    return DateTime.now().isBefore(availableUntil!);
  }
}

class UserAvatarModel {
  final String userId;
  final String? selectedHair;
  final String? selectedFace;
  final String? selectedOutfit;
  final String? selectedAccessory;
  final String? selectedBackground;
  final List<String> ownedItemIds;

  UserAvatarModel({
    required this.userId,
    this.selectedHair,
    this.selectedFace,
    this.selectedOutfit,
    this.selectedAccessory,
    this.selectedBackground,
    required this.ownedItemIds,
  });

  factory UserAvatarModel.fromJson(Map<String, dynamic> json) {
    return UserAvatarModel(
      userId: json['user_id'] as String,
      selectedHair: json['selected_hair'] as String?,
      selectedFace: json['selected_face'] as String?,
      selectedOutfit: json['selected_outfit'] as String?,
      selectedAccessory: json['selected_accessory'] as String?,
      selectedBackground: json['selected_background'] as String?,
      ownedItemIds: (json['owned_item_ids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'selected_hair': selectedHair,
      'selected_face': selectedFace,
      'selected_outfit': selectedOutfit,
      'selected_accessory': selectedAccessory,
      'selected_background': selectedBackground,
      'owned_item_ids': ownedItemIds,
    };
  }

  bool ownsItem(String itemId) {
    return ownedItemIds.contains(itemId);
  }

  UserAvatarModel copyWith({
    String? selectedHair,
    String? selectedFace,
    String? selectedOutfit,
    String? selectedAccessory,
    String? selectedBackground,
    List<String>? ownedItemIds,
  }) {
    return UserAvatarModel(
      userId: userId,
      selectedHair: selectedHair ?? this.selectedHair,
      selectedFace: selectedFace ?? this.selectedFace,
      selectedOutfit: selectedOutfit ?? this.selectedOutfit,
      selectedAccessory: selectedAccessory ?? this.selectedAccessory,
      selectedBackground: selectedBackground ?? this.selectedBackground,
      ownedItemIds: ownedItemIds ?? this.ownedItemIds,
    );
  }
}
