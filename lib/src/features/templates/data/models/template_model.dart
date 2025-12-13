enum TemplateCategory {
  beach,
  adventure,
  city,
  cultural,
  roadTrip,
  backpacking,
  luxury,
  family,
  business,
  other;

  String get displayName {
    switch (this) {
      case TemplateCategory.beach:
        return 'Beach';
      case TemplateCategory.adventure:
        return 'Adventure';
      case TemplateCategory.city:
        return 'City Break';
      case TemplateCategory.cultural:
        return 'Cultural';
      case TemplateCategory.roadTrip:
        return 'Road Trip';
      case TemplateCategory.backpacking:
        return 'Backpacking';
      case TemplateCategory.luxury:
        return 'Luxury';
      case TemplateCategory.family:
        return 'Family';
      case TemplateCategory.business:
        return 'Business';
      case TemplateCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case TemplateCategory.beach:
        return '🏖️';
      case TemplateCategory.adventure:
        return '🧗';
      case TemplateCategory.city:
        return '🏙️';
      case TemplateCategory.cultural:
        return '🏛️';
      case TemplateCategory.roadTrip:
        return '🚗';
      case TemplateCategory.backpacking:
        return '🎒';
      case TemplateCategory.luxury:
        return '✨';
      case TemplateCategory.family:
        return '👨‍👩‍👧‍👦';
      case TemplateCategory.business:
        return '💼';
      case TemplateCategory.other:
        return '📋';
    }
  }

  String get apiValue {
    switch (this) {
      case TemplateCategory.roadTrip:
        return 'road_trip';
      default:
        return name;
    }
  }

  static TemplateCategory fromString(String value) {
    final normalized = value.toLowerCase().replaceAll('_', '');
    return TemplateCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized || e.apiValue == value,
      orElse: () => TemplateCategory.other,
    );
  }
}

class ActivityTemplate {
  final String title;
  final String category;
  final String? description;
  final String? location;
  final double? estimatedDurationHours;
  final double? estimatedCost;
  final String? notes;

  const ActivityTemplate({
    required this.title,
    required this.category,
    this.description,
    this.location,
    this.estimatedDurationHours,
    this.estimatedCost,
    this.notes,
  });

  factory ActivityTemplate.fromJson(Map<String, dynamic> json) {
    return ActivityTemplate(
      title: json['title'] as String,
      category: json['category'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      estimatedDurationHours: (json['estimated_duration_hours'] as num?)?.toDouble(),
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'category': category,
        if (description != null) 'description': description,
        if (location != null) 'location': location,
        if (estimatedDurationHours != null) 'estimated_duration_hours': estimatedDurationHours,
        if (estimatedCost != null) 'estimated_cost': estimatedCost,
        if (notes != null) 'notes': notes,
      };
}

class PackingItemTemplate {
  final String name;
  final String category;
  final int quantity;
  final String? notes;

  const PackingItemTemplate({
    required this.name,
    required this.category,
    this.quantity = 1,
    this.notes,
  });

  factory PackingItemTemplate.fromJson(Map<String, dynamic> json) {
    return PackingItemTemplate(
      name: json['name'] as String,
      category: json['category'] as String,
      quantity: json['quantity'] as int? ?? 1,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'quantity': quantity,
        if (notes != null) 'notes': notes,
      };
}

class TemplateStructure {
  final int? durationDays;
  final String? defaultTitle;
  final String? defaultDescription;
  final List<String> suggestedTags;
  final List<ActivityTemplate> activities;
  final List<PackingItemTemplate> packingItems;
  final List<String> budgetCategories;
  final List<String> tips;

  const TemplateStructure({
    this.durationDays,
    this.defaultTitle,
    this.defaultDescription,
    this.suggestedTags = const [],
    this.activities = const [],
    this.packingItems = const [],
    this.budgetCategories = const [],
    this.tips = const [],
  });

  factory TemplateStructure.fromJson(Map<String, dynamic> json) {
    return TemplateStructure(
      durationDays: json['duration_days'] as int?,
      defaultTitle: json['default_title'] as String?,
      defaultDescription: json['default_description'] as String?,
      suggestedTags: (json['suggested_tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      activities: (json['activities'] as List<dynamic>?)
              ?.map((e) => ActivityTemplate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      packingItems: (json['packing_items'] as List<dynamic>?)
              ?.map((e) => PackingItemTemplate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      budgetCategories: (json['budget_categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      tips: (json['tips'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        if (durationDays != null) 'duration_days': durationDays,
        if (defaultTitle != null) 'default_title': defaultTitle,
        if (defaultDescription != null) 'default_description': defaultDescription,
        'suggested_tags': suggestedTags,
        'activities': activities.map((e) => e.toJson()).toList(),
        'packing_items': packingItems.map((e) => e.toJson()).toList(),
        'budget_categories': budgetCategories,
        'tips': tips,
      };
}

class TripTemplateModel {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final TemplateStructure structure;
  final bool isPublic;
  final TemplateCategory? category;
  final int useCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TripTemplateModel({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.structure,
    required this.isPublic,
    this.category,
    required this.useCount,
    required this.createdAt,
    this.updatedAt,
  });

  factory TripTemplateModel.fromJson(Map<String, dynamic> json) {
    return TripTemplateModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      structure: TemplateStructure.fromJson(
          json['structure_json'] as Map<String, dynamic>? ?? {}),
      isPublic: json['is_public'] as bool,
      category: json['category'] != null
          ? TemplateCategory.fromString(json['category'] as String)
          : null,
      useCount: json['use_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'description': description,
        'structure_json': structure.toJson(),
        'is_public': isPublic,
        'category': category?.apiValue,
        'use_count': useCount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}

class TemplateCreateRequest {
  final String name;
  final String? description;
  final TemplateStructure structure;
  final bool isPublic;
  final TemplateCategory? category;

  const TemplateCreateRequest({
    required this.name,
    this.description,
    this.structure = const TemplateStructure(),
    this.isPublic = false,
    this.category,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'structure_json': structure.toJson(),
        'is_public': isPublic,
        if (category != null) 'category': category!.apiValue,
      };
}

class TemplateFromTripRequest {
  final String tripId;
  final String name;
  final String? description;
  final bool isPublic;
  final TemplateCategory? category;
  final bool includeActivities;
  final bool includePackingItems;

  const TemplateFromTripRequest({
    required this.tripId,
    required this.name,
    this.description,
    this.isPublic = false,
    this.category,
    this.includeActivities = true,
    this.includePackingItems = true,
  });

  Map<String, dynamic> toJson() => {
        'trip_id': tripId,
        'name': name,
        if (description != null) 'description': description,
        'is_public': isPublic,
        if (category != null) 'category': category!.apiValue,
        'include_activities': includeActivities,
        'include_packing_items': includePackingItems,
      };
}

class TripFromTemplateRequest {
  final String templateId;
  final String title;
  final String startDate;
  final String? endDate;
  final String? description;

  const TripFromTemplateRequest({
    required this.templateId,
    required this.title,
    required this.startDate,
    this.endDate,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'template_id': templateId,
        'title': title,
        'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (description != null) 'description': description,
      };
}

class TemplatesResponse {
  final List<TripTemplateModel> templates;
  final int total;

  const TemplatesResponse({
    required this.templates,
    required this.total,
  });

  factory TemplatesResponse.fromJson(Map<String, dynamic> json) {
    return TemplatesResponse(
      templates: (json['templates'] as List<dynamic>)
          .map((e) => TripTemplateModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
    );
  }
}

class CategoryInfo {
  final String value;
  final String label;

  const CategoryInfo({required this.value, required this.label});

  factory CategoryInfo.fromJson(Map<String, dynamic> json) {
    return CategoryInfo(
      value: json['value'] as String,
      label: json['label'] as String,
    );
  }
}
