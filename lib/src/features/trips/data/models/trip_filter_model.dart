/// Trip filter model for search and filtering
class TripFilterModel {
  final String? search;
  final List<String>? status;
  final DateTime? startDateFrom;
  final DateTime? startDateTo;
  final List<String>? tags;
  final TripSortField sortBy;
  final TripSortOrder sortOrder;

  const TripFilterModel({
    this.search,
    this.status,
    this.startDateFrom,
    this.startDateTo,
    this.tags,
    this.sortBy = TripSortField.createdAt,
    this.sortOrder = TripSortOrder.desc,
  });

  /// Check if any filter is active
  bool get hasActiveFilters =>
      search != null && search!.isNotEmpty ||
      status != null && status!.isNotEmpty ||
      startDateFrom != null ||
      startDateTo != null ||
      tags != null && tags!.isNotEmpty;

  /// Check if sorting is non-default
  bool get hasCustomSorting =>
      sortBy != TripSortField.createdAt || sortOrder != TripSortOrder.desc;

  /// Count of active filters (excluding sorting)
  int get activeFilterCount {
    int count = 0;
    if (search != null && search!.isNotEmpty) count++;
    if (status != null && status!.isNotEmpty) count += status!.length;
    if (startDateFrom != null) count++;
    if (startDateTo != null) count++;
    if (tags != null && tags!.isNotEmpty) count += tags!.length;
    return count;
  }

  /// Copy with new values
  TripFilterModel copyWith({
    String? search,
    List<String>? status,
    DateTime? startDateFrom,
    DateTime? startDateTo,
    List<String>? tags,
    TripSortField? sortBy,
    TripSortOrder? sortOrder,
    bool clearSearch = false,
    bool clearStatus = false,
    bool clearStartDateFrom = false,
    bool clearStartDateTo = false,
    bool clearTags = false,
  }) {
    return TripFilterModel(
      search: clearSearch ? null : search ?? this.search,
      status: clearStatus ? null : status ?? this.status,
      startDateFrom:
          clearStartDateFrom ? null : startDateFrom ?? this.startDateFrom,
      startDateTo: clearStartDateTo ? null : startDateTo ?? this.startDateTo,
      tags: clearTags ? null : tags ?? this.tags,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Clear all filters (reset to default)
  TripFilterModel clear() {
    return const TripFilterModel();
  }

  /// Convert to query parameters map
  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};

    if (search != null && search!.isNotEmpty) {
      params['search'] = search;
    }

    if (status != null && status!.isNotEmpty) {
      params['status'] = status;
    }

    if (startDateFrom != null) {
      params['start_date_from'] =
          startDateFrom!.toIso8601String().split('T')[0];
    }

    if (startDateTo != null) {
      params['start_date_to'] = startDateTo!.toIso8601String().split('T')[0];
    }

    if (tags != null && tags!.isNotEmpty) {
      params['tags'] = tags;
    }

    params['sort_by'] = sortBy.apiValue;
    params['sort_order'] = sortOrder.apiValue;

    return params;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TripFilterModel &&
        other.search == search &&
        _listEquals(other.status, status) &&
        other.startDateFrom == startDateFrom &&
        other.startDateTo == startDateTo &&
        _listEquals(other.tags, tags) &&
        other.sortBy == sortBy &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode =>
      search.hashCode ^
      status.hashCode ^
      startDateFrom.hashCode ^
      startDateTo.hashCode ^
      tags.hashCode ^
      sortBy.hashCode ^
      sortOrder.hashCode;

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Sort field options
enum TripSortField {
  createdAt('created_at', 'Date Created'),
  startDate('start_date', 'Start Date'),
  title('title', 'Title'),
  updatedAt('updated_at', 'Last Updated');

  final String apiValue;
  final String displayName;

  const TripSortField(this.apiValue, this.displayName);
}

/// Sort order options
enum TripSortOrder {
  asc('asc', 'Ascending'),
  desc('desc', 'Descending');

  final String apiValue;
  final String displayName;

  const TripSortOrder(this.apiValue, this.displayName);
}
