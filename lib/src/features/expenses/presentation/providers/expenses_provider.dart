import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/expense_model.dart';
import '../../data/repositories/expense_repository.dart';

part 'expenses_provider.g.dart';

/// Expenses state for a specific trip
class ExpensesState {
  final List<ExpenseModel> expenses;
  final bool isLoading;
  final String? error;
  final int total;
  final double totalAmount;
  final ExpenseSummaryResponse? summary;

  const ExpensesState({
    this.expenses = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.totalAmount = 0.0,
    this.summary,
  });

  /// Get formatted total amount with 2 decimal places
  String get formattedTotalAmount => totalAmount.toStringAsFixed(2);

  ExpensesState copyWith({
    List<ExpenseModel>? expenses,
    bool? isLoading,
    String? error,
    int? total,
    double? totalAmount,
    ExpenseSummaryResponse? summary,
  }) {
    return ExpensesState(
      expenses: expenses ?? this.expenses,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
      totalAmount: totalAmount ?? this.totalAmount,
      summary: summary ?? this.summary,
    );
  }
}

/// Expense repository provider
@riverpod
ExpenseRepository expenseRepository(Ref ref) {
  return ExpenseRepository();
}

/// Expenses list provider for a specific trip
@riverpod
class TripExpenses extends _$TripExpenses {
  ExpenseRepository get _expenseRepository => ref.read(expenseRepositoryProvider);

  @override
  ExpensesState build(String tripId) {
    Future.microtask(() => _loadExpenses());
    return const ExpensesState(isLoading: true);
  }

  /// Load expenses for the trip
  Future<void> _loadExpenses() async {
    AppLogger.state('Expenses', 'Loading expenses for trip: $tripId');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _expenseRepository.getExpenses(tripId: tripId);
      if (!ref.mounted) return;
      final summary = await _expenseRepository.getExpenseSummary(tripId: tripId);
      if (!ref.mounted) return;

      AppLogger.state(
          'Expenses', 'Loaded ${response.expenses.length} expenses');

      state = state.copyWith(
        expenses: response.expenses,
        total: response.total,
        totalAmount: response.totalAmount,
        summary: summary,
        isLoading: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to load expenses: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh expenses
  Future<void> refresh() async {
    await _loadExpenses();
  }

  /// Create a new expense
  Future<void> createExpense(ExpenseRequest request) async {
    AppLogger.action('Creating expense');

    try {
      final newExpense = await _expenseRepository.createExpense(request);
      if (!ref.mounted) return;

      AppLogger.info('Expense created successfully');

      // Add to list and update total
      final updatedExpenses = [newExpense, ...state.expenses];

      // Reload summary
      final summary = await _expenseRepository.getExpenseSummary(tripId: tripId);
      if (!ref.mounted) return;

      state = state.copyWith(
        expenses: updatedExpenses,
        total: state.total + 1,
        summary: summary,
        totalAmount: summary.totalAmount,
      );
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to create expense: $e');
      rethrow;
    }
  }

  /// Update expense
  Future<void> updateExpense(String id, Map<String, dynamic> updates) async {
    AppLogger.action('Updating expense: $id');

    try {
      final updatedExpense = await _expenseRepository.updateExpense(id, updates);
      if (!ref.mounted) return;

      AppLogger.info('Expense updated successfully');

      // Update in list
      final updatedExpenses = state.expenses.map((expense) {
        return expense.id == id ? updatedExpense : expense;
      }).toList();

      // Reload summary
      final summary = await _expenseRepository.getExpenseSummary(tripId: tripId);
      if (!ref.mounted) return;

      state = state.copyWith(
        expenses: updatedExpenses,
        summary: summary,
        totalAmount: summary.totalAmount,
      );
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to update expense: $e');
      rethrow;
    }
  }

  /// Delete expense
  Future<void> deleteExpense(String id) async {
    AppLogger.action('Deleting expense: $id');

    try {
      await _expenseRepository.deleteExpense(id);
      if (!ref.mounted) return;

      final updatedExpenses =
          state.expenses.where((expense) => expense.id != id).toList();

      // Reload summary
      final summary = await _expenseRepository.getExpenseSummary(tripId: tripId);
      if (!ref.mounted) return;

      AppLogger.info('Expense deleted successfully');

      state = state.copyWith(
        expenses: updatedExpenses,
        total: state.total - 1,
        summary: summary,
        totalAmount: summary.totalAmount,
      );
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to delete expense: $e');
      rethrow;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}
