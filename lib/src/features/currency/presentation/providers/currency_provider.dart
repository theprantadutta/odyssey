import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:odyssey/src/features/currency/data/models/currency_model.dart';
import 'package:odyssey/src/features/currency/data/repositories/currency_repository.dart';

part 'currency_provider.g.dart';

/// Currency repository provider
@riverpod
CurrencyRepository currencyRepository(Ref ref) {
  return CurrencyRepository();
}

/// Exchange rates for a base currency
@riverpod
class ExchangeRates extends _$ExchangeRates {
  @override
  Future<ExchangeRateResponse?> build(String baseCurrency) async {
    try {
      final repository = ref.read(currencyRepositoryProvider);
      return await repository.getExchangeRates(base: baseCurrency);
    } catch (e) {
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(currencyRepositoryProvider);
      return repository.getExchangeRates(base: baseCurrency);
    });
  }
}

/// Supported currencies
@riverpod
class SupportedCurrencies extends _$SupportedCurrencies {
  @override
  Future<List<CurrencyInfo>> build() async {
    try {
      final repository = ref.read(currencyRepositoryProvider);
      return await repository.getSupportedCurrencies();
    } catch (e) {
      // Return local list on error
      return commonCurrencies;
    }
  }
}

/// Currency conversion state
class CurrencyConversionState {
  final String fromCurrency;
  final String toCurrency;
  final double amount;
  final ConversionResponse? result;
  final bool isLoading;
  final String? error;

  const CurrencyConversionState({
    this.fromCurrency = 'USD',
    this.toCurrency = 'EUR',
    this.amount = 0,
    this.result,
    this.isLoading = false,
    this.error,
  });

  CurrencyConversionState copyWith({
    String? fromCurrency,
    String? toCurrency,
    double? amount,
    ConversionResponse? result,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return CurrencyConversionState(
      fromCurrency: fromCurrency ?? this.fromCurrency,
      toCurrency: toCurrency ?? this.toCurrency,
      amount: amount ?? this.amount,
      result: clearResult ? null : (result ?? this.result),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Currency converter
@riverpod
class CurrencyConverter extends _$CurrencyConverter {
  @override
  CurrencyConversionState build() {
    return const CurrencyConversionState();
  }

  void setFromCurrency(String currency) {
    state = state.copyWith(fromCurrency: currency, clearResult: true);
  }

  void setToCurrency(String currency) {
    state = state.copyWith(toCurrency: currency, clearResult: true);
  }

  void setAmount(double amount) {
    state = state.copyWith(amount: amount, clearResult: true);
  }

  void swapCurrencies() {
    state = state.copyWith(
      fromCurrency: state.toCurrency,
      toCurrency: state.fromCurrency,
      clearResult: true,
    );
  }

  Future<void> convert() async {
    if (state.amount <= 0) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repository = ref.read(currencyRepositoryProvider);
      final result = await repository.convert(
        fromCurrency: state.fromCurrency,
        toCurrency: state.toCurrency,
        amount: state.amount,
      );
      state = state.copyWith(result: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}
