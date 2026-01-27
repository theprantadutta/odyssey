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

/// Converts nullable amount from various types to double
double? _nullableAmountFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is String) return double.tryParse(value);
  return null;
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
  @JsonKey(name: 'converted_amount', fromJson: _nullableAmountFromJson)
  final double? convertedAmount;
  @JsonKey(name: 'converted_currency')
  final String? convertedCurrency;
  @JsonKey(name: 'exchange_rate', fromJson: _nullableAmountFromJson)
  final double? exchangeRate;
  @JsonKey(name: 'converted_at')
  final String? convertedAt;
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
    this.convertedAmount,
    this.convertedCurrency,
    this.exchangeRate,
    this.convertedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) =>
      _$ExpenseModelFromJson(json);

  Map<String, dynamic> toJson() => _$ExpenseModelToJson(this);

  /// Get amount as formatted string with 2 decimal places
  String get formattedAmount => amount.toStringAsFixed(2);

  /// Get converted amount as formatted string with 2 decimal places
  String get formattedConvertedAmount =>
      convertedAmount?.toStringAsFixed(2) ?? formattedAmount;

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
        convertedAmount,
        convertedCurrency,
        exchangeRate,
        convertedAt,
        createdAt,
        updatedAt,
      ];
}

/// Create/Update expense request
@JsonSerializable(createFactory: false)
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
  @JsonKey(name: 'converted_total_amount', fromJson: _amountFromJson)
  final double convertedTotalAmount;
  @JsonKey(name: 'display_currency')
  final String displayCurrency;
  @JsonKey(fromJson: _nullableAmountFromJson)
  final double? budget;
  @JsonKey(name: 'budget_remaining', fromJson: _nullableAmountFromJson)
  final double? budgetRemaining;
  @JsonKey(name: 'budget_used_percentage')
  final double? budgetUsedPercentage;
  @JsonKey(name: 'by_currency')
  final List<CurrencyBreakdown> byCurrency;
  @JsonKey(name: 'rates_last_updated')
  final String? ratesLastUpdated;

  const ExpenseSummaryResponse({
    required this.byCategory,
    required this.totalAmount,
    required this.currency,
    this.convertedTotalAmount = 0.0,
    this.displayCurrency = 'USD',
    this.budget,
    this.budgetRemaining,
    this.budgetUsedPercentage,
    this.byCurrency = const [],
    this.ratesLastUpdated,
  });

  factory ExpenseSummaryResponse.fromJson(Map<String, dynamic> json) =>
      _$ExpenseSummaryResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ExpenseSummaryResponseToJson(this);

  /// Check if budget is set
  bool get hasBudget => budget != null && budget! > 0;

  /// Check if over budget
  bool get isOverBudget => hasBudget && budgetRemaining != null && budgetRemaining! < 0;
}

/// Currency breakdown for multi-currency expenses
@JsonSerializable()
class CurrencyBreakdown {
  final String currency;
  @JsonKey(name: 'original_amount', fromJson: _amountFromJson)
  final double originalAmount;
  @JsonKey(name: 'converted_amount', fromJson: _amountFromJson)
  final double convertedAmount;
  @JsonKey(name: 'exchange_rate', fromJson: _amountFromJson)
  final double exchangeRate;
  @JsonKey(name: 'expense_count')
  final int expenseCount;

  const CurrencyBreakdown({
    required this.currency,
    required this.originalAmount,
    required this.convertedAmount,
    required this.exchangeRate,
    required this.expenseCount,
  });

  factory CurrencyBreakdown.fromJson(Map<String, dynamic> json) =>
      _$CurrencyBreakdownFromJson(json);

  Map<String, dynamic> toJson() => _$CurrencyBreakdownToJson(this);
}

/// Response for refresh conversions endpoint
@JsonSerializable()
class RefreshConversionsResponse {
  @JsonKey(name: 'expenses_updated')
  final int expensesUpdated;
  @JsonKey(name: 'display_currency')
  final String displayCurrency;
  @JsonKey(name: 'refreshed_at')
  final String refreshedAt;

  const RefreshConversionsResponse({
    required this.expensesUpdated,
    required this.displayCurrency,
    required this.refreshedAt,
  });

  factory RefreshConversionsResponse.fromJson(Map<String, dynamic> json) =>
      _$RefreshConversionsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RefreshConversionsResponseToJson(this);
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
