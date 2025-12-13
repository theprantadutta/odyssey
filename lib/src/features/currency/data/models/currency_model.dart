/// Currency information
class CurrencyInfo {
  final String code;
  final String name;
  final String symbol;
  final String? flagEmoji;

  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
    this.flagEmoji,
  });

  factory CurrencyInfo.fromJson(Map<String, dynamic> json) {
    return CurrencyInfo(
      code: json['code'] as String,
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      flagEmoji: json['flag_emoji'] as String?,
    );
  }

  String get displayName => '$flagEmoji $code - $name';
}

/// Exchange rate response
class ExchangeRateResponse {
  final String base;
  final Map<String, double> rates;
  final DateTime fetchedAt;
  final DateTime expiresAt;

  const ExchangeRateResponse({
    required this.base,
    required this.rates,
    required this.fetchedAt,
    required this.expiresAt,
  });

  factory ExchangeRateResponse.fromJson(Map<String, dynamic> json) {
    return ExchangeRateResponse(
      base: json['base'] as String,
      rates: (json['rates'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  double? getRate(String currency) => rates[currency.toUpperCase()];
}

/// Currency conversion response
class ConversionResponse {
  final String fromCurrency;
  final String toCurrency;
  final double amount;
  final double convertedAmount;
  final double rate;
  final DateTime fetchedAt;

  const ConversionResponse({
    required this.fromCurrency,
    required this.toCurrency,
    required this.amount,
    required this.convertedAmount,
    required this.rate,
    required this.fetchedAt,
  });

  factory ConversionResponse.fromJson(Map<String, dynamic> json) {
    return ConversionResponse(
      fromCurrency: json['from_currency'] as String,
      toCurrency: json['to_currency'] as String,
      amount: (json['amount'] as num).toDouble(),
      convertedAmount: (json['converted_amount'] as num).toDouble(),
      rate: (json['rate'] as num).toDouble(),
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
    );
  }
}

/// Bulk conversion response
class BulkConversionResponse {
  final String targetCurrency;
  final List<ConversionResponse> conversions;
  final double total;
  final DateTime fetchedAt;

  const BulkConversionResponse({
    required this.targetCurrency,
    required this.conversions,
    required this.total,
    required this.fetchedAt,
  });

  factory BulkConversionResponse.fromJson(Map<String, dynamic> json) {
    return BulkConversionResponse(
      targetCurrency: json['target_currency'] as String,
      conversions: (json['conversions'] as List<dynamic>)
          .map((e) => ConversionResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toDouble(),
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
    );
  }
}

/// Common currencies for quick access
const List<CurrencyInfo> commonCurrencies = [
  CurrencyInfo(code: 'USD', name: 'US Dollar', symbol: '\$', flagEmoji: '🇺🇸'),
  CurrencyInfo(code: 'EUR', name: 'Euro', symbol: '€', flagEmoji: '🇪🇺'),
  CurrencyInfo(code: 'GBP', name: 'British Pound', symbol: '£', flagEmoji: '🇬🇧'),
  CurrencyInfo(code: 'JPY', name: 'Japanese Yen', symbol: '¥', flagEmoji: '🇯🇵'),
  CurrencyInfo(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$', flagEmoji: '🇦🇺'),
  CurrencyInfo(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$', flagEmoji: '🇨🇦'),
  CurrencyInfo(code: 'CHF', name: 'Swiss Franc', symbol: 'Fr', flagEmoji: '🇨🇭'),
  CurrencyInfo(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', flagEmoji: '🇨🇳'),
  CurrencyInfo(code: 'INR', name: 'Indian Rupee', symbol: '₹', flagEmoji: '🇮🇳'),
  CurrencyInfo(code: 'BDT', name: 'Bangladeshi Taka', symbol: '৳', flagEmoji: '🇧🇩'),
  CurrencyInfo(code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$', flagEmoji: '🇸🇬'),
  CurrencyInfo(code: 'THB', name: 'Thai Baht', symbol: '฿', flagEmoji: '🇹🇭'),
  CurrencyInfo(code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM', flagEmoji: '🇲🇾'),
  CurrencyInfo(code: 'KRW', name: 'South Korean Won', symbol: '₩', flagEmoji: '🇰🇷'),
  CurrencyInfo(code: 'MXN', name: 'Mexican Peso', symbol: '\$', flagEmoji: '🇲🇽'),
  CurrencyInfo(code: 'BRL', name: 'Brazilian Real', symbol: 'R\$', flagEmoji: '🇧🇷'),
  CurrencyInfo(code: 'ZAR', name: 'South African Rand', symbol: 'R', flagEmoji: '🇿🇦'),
  CurrencyInfo(code: 'NZD', name: 'New Zealand Dollar', symbol: 'NZ\$', flagEmoji: '🇳🇿'),
  CurrencyInfo(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', flagEmoji: '🇦🇪'),
  CurrencyInfo(code: 'SAR', name: 'Saudi Riyal', symbol: '﷼', flagEmoji: '🇸🇦'),
];

/// Get currency info by code
CurrencyInfo? getCurrencyByCode(String code) {
  try {
    return commonCurrencies.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
    );
  } catch (_) {
    return null;
  }
}

/// Format amount with currency symbol
String formatCurrency(double amount, String currencyCode) {
  final currency = getCurrencyByCode(currencyCode);
  final symbol = currency?.symbol ?? currencyCode;
  return '$symbol${amount.toStringAsFixed(2)}';
}
