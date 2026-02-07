import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/database/model_converters.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/sync/sync_queue_service.dart';
import '../models/expense_model.dart';

/// Expense repository - local-first with background API sync
class ExpenseRepository {
  final DioClient _dioClient = DioClient();
  AppDatabase get _db => DatabaseService().database;

  /// Get all expenses for a trip - reads from local DB, triggers background API refresh
  Future<ExpensesResponse> getExpenses({
    required String tripId,
    String? category,
  }) async {
    final localExpenses = await _db.expensesDao.getByTrip(tripId);

    if (localExpenses.isNotEmpty || !ConnectivityService().isOnline) {
      var expenses = localExpenses.map(expenseFromLocal).toList();

      // Apply local category filtering
      if (category != null) {
        expenses = expenses.where((e) => e.category == category).toList();
      }

      final totalAmount = expenses.fold<double>(0, (sum, e) => sum + e.amount);

      if (ConnectivityService().isOnline) {
        _refreshFromApi(tripId);
      }

      return ExpensesResponse(expenses: expenses, total: expenses.length, totalAmount: totalAmount);
    }

    // No local data - fetch from API
    return _fetchFromApi(tripId: tripId, category: category);
  }

  /// Get expense summary by category - online only with local fallback
  Future<ExpenseSummaryResponse> getExpenseSummary({
    required String tripId,
  }) async {
    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.get(
          '${ApiConfig.expenses}/summary',
          queryParameters: {'trip_id': tripId},
        );
        return ExpenseSummaryResponse.fromJson(response.data);
      } on DioException catch (e) {
        throw _handleError(e);
      }
    }

    // Offline fallback - compute basic summary from local data
    final localExpenses = await _db.expensesDao.getByTrip(tripId);
    final expenses = localExpenses.map(expenseFromLocal).toList();
    final totalAmount = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    // Group by category
    final categoryMap = <String, List<ExpenseModel>>{};
    for (final expense in expenses) {
      categoryMap.putIfAbsent(expense.category, () => []).add(expense);
    }

    final byCategory = categoryMap.entries.map((entry) {
      final catTotal = entry.value.fold<double>(0, (sum, e) => sum + e.amount);
      return ExpenseSummary(
        category: entry.key,
        totalAmount: catTotal,
        count: entry.value.length,
        currency: entry.value.first.currency,
      );
    }).toList();

    return ExpenseSummaryResponse(
      byCategory: byCategory,
      totalAmount: totalAmount,
      currency: expenses.isNotEmpty ? expenses.first.currency : 'USD',
    );
  }

  /// Get expense by ID - reads from local DB first
  Future<ExpenseModel> getExpenseById(String id) async {
    final local = await _db.expensesDao.getById(id);
    if (local != null && !local.isDeleted) {
      if (ConnectivityService().isOnline) {
        _refreshExpenseFromApi(id);
      }
      return expenseFromLocal(local);
    }

    try {
      final response = await _dioClient.get('${ApiConfig.expenses}/$id');
      final expense = ExpenseModel.fromJson(response.data);
      await _db.expensesDao.upsert(expenseToLocal(expense));
      return expense;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a new expense - writes to local DB immediately, syncs in background
  Future<ExpenseModel> createExpense(ExpenseRequest request) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final expense = ExpenseModel(
      id: id,
      tripId: request.tripId,
      title: request.title,
      amount: request.amount,
      currency: request.currency,
      category: request.category,
      date: request.date,
      notes: request.notes,
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );

    await _db.expensesDao.upsert(expenseToLocal(expense, isDirty: true, isLocalOnly: true));

    await SyncQueueService().enqueue(
      entityType: 'expense',
      entityId: id,
      operation: 'create',
      payload: request.toJson(),
    );

    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.post('${ApiConfig.expenses}/', data: request.toJson());
        final serverExpense = ExpenseModel.fromJson(response.data);
        await _db.expensesDao.upsert(expenseToLocal(serverExpense));
        await _db.syncQueueDao.removeForEntity('expense', id);
        return serverExpense;
      } catch (e) {
        AppLogger.warning('Failed to sync expense create, will retry: $e');
      }
    }

    return expense;
  }

  /// Update expense - writes to local DB immediately, syncs in background
  Future<ExpenseModel> updateExpense(String id, Map<String, dynamic> updates) async {
    final existing = await _db.expensesDao.getById(id);
    if (existing != null) {
      final updatedCompanion = LocalExpensesCompanion(
        id: Value(id),
        title: updates.containsKey('title') ? Value(updates['title'] as String) : const Value.absent(),
        amount: updates.containsKey('amount') ? Value((updates['amount'] as num).toDouble()) : const Value.absent(),
        currency: updates.containsKey('currency') ? Value(updates['currency'] as String) : const Value.absent(),
        category: updates.containsKey('category') ? Value(updates['category'] as String) : const Value.absent(),
        date: updates.containsKey('date') ? Value(updates['date'] as String) : const Value.absent(),
        notes: updates.containsKey('notes') ? Value(updates['notes'] as String?) : const Value.absent(),
        updatedAt: Value(DateTime.now().toUtc()),
        isDirty: const Value(true),
      );
      await ((_db.update(_db.localExpenses))..where((t) => t.id.equals(id))).write(updatedCompanion);
    }

    await SyncQueueService().enqueue(
      entityType: 'expense',
      entityId: id,
      operation: 'update',
      payload: {...updates, '_base_version': existing?.updatedAt.toIso8601String()},
    );

    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.patch('${ApiConfig.expenses}/$id', data: updates);
        final serverExpense = ExpenseModel.fromJson(response.data);
        await _db.expensesDao.upsert(expenseToLocal(serverExpense));
        await _db.syncQueueDao.removeForEntity('expense', id);
        return serverExpense;
      } catch (e) {
        AppLogger.warning('Failed to sync expense update, will retry: $e');
      }
    }

    final updated = await _db.expensesDao.getById(id);
    return updated != null ? expenseFromLocal(updated) : throw 'Expense not found';
  }

  /// Delete expense - soft deletes locally, syncs in background
  Future<void> deleteExpense(String id) async {
    await _db.expensesDao.softDelete(id);

    await SyncQueueService().enqueue(
      entityType: 'expense',
      entityId: id,
      operation: 'delete',
      payload: {},
    );

    if (ConnectivityService().isOnline) {
      try {
        await _dioClient.delete('${ApiConfig.expenses}/$id');
        await _db.expensesDao.hardDelete(id);
        await _db.syncQueueDao.removeForEntity('expense', id);
      } catch (e) {
        AppLogger.warning('Failed to sync expense delete, will retry: $e');
      }
    }
  }

  /// Refresh expense conversions to latest exchange rates - online only
  Future<RefreshConversionsResponse> refreshConversions({
    required String tripId,
  }) async {
    try {
      final response = await _dioClient.post(
        '${ApiConfig.expenses}/refresh-conversions',
        queryParameters: {'trip_id': tripId},
      );

      final result = RefreshConversionsResponse.fromJson(response.data);

      // Refresh local data after conversion update
      _refreshFromApi(tripId);

      return result;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Private Methods ──────────────────────────────────────────

  Future<ExpensesResponse> _fetchFromApi({
    required String tripId,
    String? category,
  }) async {
    try {
      final queryParams = <String, dynamic>{'trip_id': tripId};
      if (category != null) queryParams['category'] = category;

      final response = await _dioClient.get(ApiConfig.expenses, queryParameters: queryParams);
      final expensesResponse = ExpensesResponse.fromJson(response.data);

      for (final expense in expensesResponse.expenses) {
        await _db.expensesDao.upsert(expenseToLocal(expense));
      }

      return expensesResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void _refreshFromApi(String tripId) async {
    try {
      final response = await _dioClient.get(
        ApiConfig.expenses,
        queryParameters: {'trip_id': tripId},
      );
      final expensesResponse = ExpensesResponse.fromJson(response.data);
      for (final expense in expensesResponse.expenses) {
        final existing = await _db.expensesDao.getById(expense.id);
        if (existing == null || !existing.isDirty) {
          await _db.expensesDao.upsert(expenseToLocal(expense));
        }
      }
    } catch (e) {
      AppLogger.warning('Background expense refresh failed: $e');
    }
  }

  void _refreshExpenseFromApi(String id) async {
    try {
      final response = await _dioClient.get('${ApiConfig.expenses}/$id');
      final expense = ExpenseModel.fromJson(response.data);
      final existing = await _db.expensesDao.getById(id);
      if (existing == null || !existing.isDirty) {
        await _db.expensesDao.upsert(expenseToLocal(expense));
      }
    } catch (e) {
      AppLogger.warning('Background expense detail refresh failed: $e');
    }
  }

  String _handleError(DioException error) {
    if (error.response?.data != null && error.response!.data is Map) {
      final data = error.response!.data as Map<String, dynamic>;
      if (data.containsKey('detail')) return data['detail'].toString();
    }
    return error.error?.toString() ?? 'Operation failed';
  }
}
