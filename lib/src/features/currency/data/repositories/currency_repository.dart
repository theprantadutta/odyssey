import 'package:odyssey/src/core/network/dio_client.dart';
import 'package:odyssey/src/features/currency/data/models/currency_model.dart';

class CurrencyRepository {
  final DioClient _dioClient = DioClient();

  /// Get exchange rates for a base currency
  Future<ExchangeRateResponse> getExchangeRates({
    String base = 'USD',
  }) async {
    final response = await _dioClient.get(
      '/currency/rates',
      queryParameters: {'base': base},
    );
    return ExchangeRateResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Convert amount from one currency to another
  Future<ConversionResponse> convert({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
  }) async {
    final response = await _dioClient.get(
      '/currency/convert',
      queryParameters: {
        'from': fromCurrency,
        'to': toCurrency,
        'amount': amount,
      },
    );
    return ConversionResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Bulk convert multiple amounts to a target currency
  Future<BulkConversionResponse> bulkConvert({
    required List<Map<String, double>> amounts,
    required String targetCurrency,
  }) async {
    final response = await _dioClient.post(
      '/currency/bulk-convert',
      data: {
        'amounts': amounts,
        'target_currency': targetCurrency,
      },
    );
    return BulkConversionResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  /// Get list of supported currencies
  Future<List<CurrencyInfo>> getSupportedCurrencies() async {
    final response = await _dioClient.get('/currency/supported');
    return (response.data as List<dynamic>)
        .map((e) => CurrencyInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
