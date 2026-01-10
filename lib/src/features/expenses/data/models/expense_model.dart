import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'expense_model.g.dart';

/// Converts amount from various types (int, double, String) to double
double _amountFromJson(dynamic value) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

/// Expense model matching backend schema
@JsonSerializable()
class ExpenseModel extends Equatable {
  final String id;
  @JsonKey(name: 'trip_id')
  final String tripId;
  final String title;
  @JsonKey(fromJson: _amountFromJson)
  final double amount;
  final String currency;
  final String category;
  final String date;
  final String? notes;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  const ExpenseModel({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amount,
    required this.currency,
    required this.category,
    required this.date,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) =>
      _$ExpenseModelFromJson(json);

  Map<String, dynamic> toJson() => _$ExpenseModelToJson(this);

  /// Get amount as formatted string with 2 decimal places
  String get formattedAmount => amount.toStringAsFixed(2);

  @override
  List<Object?> get props => [
        id,
        tripId,
        title,
        amount,
        currency,
        category,
        date,
        notes,
        createdAt,
        updatedAt,
      ];
}

/// Create/Update expense request
@JsonSerializable()
class ExpenseRequest {
  @JsonKey(name: 'trip_id')
  final String tripId;
  final String title;
  final double amount;
  final String currency;
  final String category;
  final String date;
  final String? notes;

  const ExpenseRequest({
    required this.tripId,
    required this.title,
    required this.amount,
    required this.currency,
    required this.category,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toJson() => _$ExpenseRequestToJson(this);
}

/// Expenses list response
@JsonSerializable()
class ExpensesResponse {
  final List<ExpenseModel> expenses;
  final int total;
  @JsonKey(name: 'total_amount', fromJson: _amountFromJson)
  final double totalAmount;

  const ExpensesResponse({
    required this.expenses,
    required this.total,
    required this.totalAmount,
  });

  factory ExpensesResponse.fromJson(Map<String, dynamic> json) =>
      _$ExpensesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ExpensesResponseToJson(this);
}

/// Expense summary by category
@JsonSerializable()
class ExpenseSummary {
  final String category;
  @JsonKey(name: 'total_amount', fromJson: _amountFromJson)
  final double totalAmount;
  final int count;
  final String currency;

  const ExpenseSummary({
    required this.category,
    required this.totalAmount,
    required this.count,
    required this.currency,
  });

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) =>
      _$ExpenseSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$ExpenseSummaryToJson(this);
}

/// Expense summary response
@JsonSerializable()
class ExpenseSummaryResponse {
  @JsonKey(name: 'by_category')
  final List<ExpenseSummary> byCategory;
  @JsonKey(name: 'total_amount', fromJson: _amountFromJson)
  final double totalAmount;
  final String currency;

  const ExpenseSummaryResponse({
    required this.byCategory,
    required this.totalAmount,
    required this.currency,
  });

  factory ExpenseSummaryResponse.fromJson(Map<String, dynamic> json) =>
      _$ExpenseSummaryResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ExpenseSummaryResponseToJson(this);
}

/// Expense category enum
enum ExpenseCategory {
  food,
  transport,
  accommodation,
  activities,
  shopping,
  other;

  String get displayName {
    switch (this) {
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.accommodation:
        return 'Accommodation';
      case ExpenseCategory.activities:
        return 'Activities';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case ExpenseCategory.food:
        return '🍔';
      case ExpenseCategory.transport:
        return '🚗';
      case ExpenseCategory.accommodation:
        return '🏨';
      case ExpenseCategory.activities:
        return '🎯';
      case ExpenseCategory.shopping:
        return '🛍️';
      case ExpenseCategory.other:
        return '📝';
    }
  }
}
