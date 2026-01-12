import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/expense_model.dart';

/// Expense repository for API calls
class ExpenseRepository {
  final DioClient _dioClient = DioClient();

  /// Get all expenses for a trip
  Future<ExpensesResponse> getExpenses({
    required String tripId,
    String? category,
  }) async {
    try {
      final queryParams = <String, dynamic>{'trip_id': tripId};
      if (category != null) {
        queryParams['category'] = category;
      }

      final response = await _dioClient.get(
        ApiConfig.expenses,
        queryParameters: queryParams,
      );

      return ExpensesResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get expense summary by category
  Future<ExpenseSummaryResponse> getExpenseSummary({
    required String tripId,
  }) async {
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

  /// Get expense by ID
  Future<ExpenseModel> getExpenseById(String id) async {
    try {
      final response = await _dioClient.get('${ApiConfig.expenses}/$id');
      return ExpenseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a new expense
  Future<ExpenseModel> createExpense(ExpenseRequest request) async {
    try {
      final response = await _dioClient.post(
        '${ApiConfig.expenses}/',
        data: request.toJson(),
      );

      return ExpenseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update expense
  Future<ExpenseModel> updateExpense(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _dioClient.patch(
        '${ApiConfig.expenses}/$id',
        data: updates,
      );

      return ExpenseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete expense
  Future<void> deleteExpense(String id) async {
    try {
      await _dioClient.delete('${ApiConfig.expenses}/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Refresh expense conversions to latest exchange rates
  Future<RefreshConversionsResponse> refreshConversions({
    required String tripId,
  }) async {
    try {
      final response = await _dioClient.post(
        '${ApiConfig.expenses}/refresh-conversions',
        queryParameters: {'trip_id': tripId},
      );

      return RefreshConversionsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle Dio errors
  String _handleError(DioException error) {
    if (error.response?.data != null && error.response!.data is Map) {
      final data = error.response!.data as Map<String, dynamic>;
      if (data.containsKey('detail')) {
        return data['detail'].toString();
      }
    }
    return error.error?.toString() ?? 'Operation failed';
  }
}
