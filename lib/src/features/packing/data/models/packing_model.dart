import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'packing_model.g.dart';

/// Packing item model matching backend schema
@JsonSerializable()
class PackingItemModel extends Equatable {
  final String id;
  @JsonKey(name: 'trip_id')
  final String tripId;
  final String name;
  final String category;
  @JsonKey(name: 'is_packed')
  final bool isPacked;
  final int quantity;
  final String? notes;
  @JsonKey(name: 'sort_order')
  final int sortOrder;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const PackingItemModel({
    required this.id,
    required this.tripId,
    required this.name,
    required this.category,
    required this.isPacked,
    required this.quantity,
    this.notes,
    required this.sortOrder,
    required this.createdAt,
    this.updatedAt,
  });

  factory PackingItemModel.fromJson(Map<String, dynamic> json) =>
      _$PackingItemModelFromJson(json);

  Map<String, dynamic> toJson() => _$PackingItemModelToJson(this);

  PackingItemModel copyWith({
    String? id,
    String? tripId,
    String? name,
    String? category,
    bool? isPacked,
    int? quantity,
    String? notes,
    int? sortOrder,
    String? createdAt,
    String? updatedAt,
  }) {
    return PackingItemModel(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      name: name ?? this.name,
      category: category ?? this.category,
      isPacked: isPacked ?? this.isPacked,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tripId,
        name,
        category,
        isPacked,
        quantity,
        notes,
        sortOrder,
        createdAt,
        updatedAt,
      ];
}

/// Create packing item request
@JsonSerializable()
class PackingItemRequest {
  @JsonKey(name: 'trip_id')
  final String tripId;
  final String name;
  final String category;
  @JsonKey(name: 'is_packed')
  final bool isPacked;
  final int quantity;
  final String? notes;

  const PackingItemRequest({
    required this.tripId,
    required this.name,
    required this.category,
    this.isPacked = false,
    this.quantity = 1,
    this.notes,
  });

  Map<String, dynamic> toJson() => _$PackingItemRequestToJson(this);
}

/// Packing list response
@JsonSerializable()
class PackingListResponse {
  final List<PackingItemModel> items;
  final int total;
  @JsonKey(name: 'packed_count')
  final int packedCount;
  @JsonKey(name: 'unpacked_count')
  final int unpackedCount;

  const PackingListResponse({
    required this.items,
    required this.total,
    required this.packedCount,
    required this.unpackedCount,
  });

  factory PackingListResponse.fromJson(Map<String, dynamic> json) =>
      _$PackingListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PackingListResponseToJson(this);
}

/// Category progress for packing
@JsonSerializable()
class CategoryProgress {
  final String category;
  final int total;
  final int packed;
  @JsonKey(name: 'progress_percent')
  final double progressPercent;

  const CategoryProgress({
    required this.category,
    required this.total,
    required this.packed,
    required this.progressPercent,
  });

  factory CategoryProgress.fromJson(Map<String, dynamic> json) =>
      _$CategoryProgressFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryProgressToJson(this);
}

/// Packing progress response
@JsonSerializable()
class PackingProgressResponse {
  @JsonKey(name: 'total_items')
  final int totalItems;
  @JsonKey(name: 'packed_items')
  final int packedItems;
  @JsonKey(name: 'progress_percent')
  final double progressPercent;
  @JsonKey(name: 'by_category')
  final List<CategoryProgress> byCategory;

  const PackingProgressResponse({
    required this.totalItems,
    required this.packedItems,
    required this.progressPercent,
    required this.byCategory,
  });

  factory PackingProgressResponse.fromJson(Map<String, dynamic> json) =>
      _$PackingProgressResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PackingProgressResponseToJson(this);
}

/// Item reorder request
@JsonSerializable()
class ItemOrderData {
  final String id;
  @JsonKey(name: 'sort_order')
  final int sortOrder;

  const ItemOrderData({
    required this.id,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() => _$ItemOrderDataToJson(this);
}

/// Packing category enum
enum PackingCategory {
  clothes,
  toiletries,
  electronics,
  documents,
  medicine,
  other;

  String get displayName {
    switch (this) {
      case PackingCategory.clothes:
        return 'Clothes';
      case PackingCategory.toiletries:
        return 'Toiletries';
      case PackingCategory.electronics:
        return 'Electronics';
      case PackingCategory.documents:
        return 'Documents';
      case PackingCategory.medicine:
        return 'Medicine';
      case PackingCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case PackingCategory.clothes:
        return '👕';
      case PackingCategory.toiletries:
        return '🧴';
      case PackingCategory.electronics:
        return '📱';
      case PackingCategory.documents:
        return '📄';
      case PackingCategory.medicine:
        return '💊';
      case PackingCategory.other:
        return '📦';
    }
  }

  static PackingCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'clothes':
        return PackingCategory.clothes;
      case 'toiletries':
        return PackingCategory.toiletries;
      case 'electronics':
        return PackingCategory.electronics;
      case 'documents':
        return PackingCategory.documents;
      case 'medicine':
        return PackingCategory.medicine;
      default:
        return PackingCategory.other;
    }
  }
}
