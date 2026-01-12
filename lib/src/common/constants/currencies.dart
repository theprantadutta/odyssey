/// Common currencies with code, name, and symbol
const List<({String code, String name, String symbol})> commonCurrencies = [
  (code: 'USD', name: 'US Dollar', symbol: '\$'),
  (code: 'EUR', name: 'Euro', symbol: '\u20AC'),
  (code: 'GBP', name: 'British Pound', symbol: '\u00A3'),
  (code: 'JPY', name: 'Japanese Yen', symbol: '\u00A5'),
  (code: 'AUD', name: 'Australian Dollar', symbol: 'A\$'),
  (code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$'),
  (code: 'CHF', name: 'Swiss Franc', symbol: 'CHF'),
  (code: 'CNY', name: 'Chinese Yuan', symbol: '\u00A5'),
  (code: 'INR', name: 'Indian Rupee', symbol: '\u20B9'),
  (code: 'BDT', name: 'Bangladeshi Taka', symbol: '\u09F3'),
  (code: 'MXN', name: 'Mexican Peso', symbol: '\$'),
  (code: 'BRL', name: 'Brazilian Real', symbol: 'R\$'),
  (code: 'KRW', name: 'South Korean Won', symbol: '\u20A9'),
  (code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$'),
  (code: 'HKD', name: 'Hong Kong Dollar', symbol: 'HK\$'),
  (code: 'NOK', name: 'Norwegian Krone', symbol: 'kr'),
  (code: 'SEK', name: 'Swedish Krona', symbol: 'kr'),
  (code: 'DKK', name: 'Danish Krone', symbol: 'kr'),
  (code: 'NZD', name: 'New Zealand Dollar', symbol: 'NZ\$'),
  (code: 'ZAR', name: 'South African Rand', symbol: 'R'),
  (code: 'THB', name: 'Thai Baht', symbol: '\u0E3F'),
  (code: 'AED', name: 'UAE Dirham', symbol: '\u062F.\u0625'),
  (code: 'SAR', name: 'Saudi Riyal', symbol: '\uFDFC'),
  (code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM'),
  (code: 'PHP', name: 'Philippine Peso', symbol: '\u20B1'),
  (code: 'IDR', name: 'Indonesian Rupiah', symbol: 'Rp'),
  (code: 'TRY', name: 'Turkish Lira', symbol: '\u20BA'),
  (code: 'RUB', name: 'Russian Ruble', symbol: '\u20BD'),
  (code: 'PLN', name: 'Polish Zloty', symbol: 'z\u0142'),
  (code: 'CZK', name: 'Czech Koruna', symbol: 'K\u010D'),
];

/// Get currency symbol by code
String getCurrencySymbol(String code) {
  final currency = commonCurrencies.where((c) => c.code == code).firstOrNull;
  return currency?.symbol ?? code;
}

/// Get currency name by code
String getCurrencyName(String code) {
  final currency = commonCurrencies.where((c) => c.code == code).firstOrNull;
  return currency?.name ?? code;
}
