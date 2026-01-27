import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odyssey/src/common/theme/app_colors.dart';
import 'package:odyssey/src/common/theme/app_sizes.dart';
import 'package:odyssey/src/features/currency/data/models/currency_model.dart';
import 'package:odyssey/src/features/currency/presentation/providers/currency_provider.dart';

class CurrencyConverterWidget extends ConsumerStatefulWidget {
  final String? initialFromCurrency;
  final String? initialToCurrency;
  final double? initialAmount;

  const CurrencyConverterWidget({
    super.key,
    this.initialFromCurrency,
    this.initialToCurrency,
    this.initialAmount,
  });

  @override
  ConsumerState<CurrencyConverterWidget> createState() =>
      _CurrencyConverterWidgetState();
}

class _CurrencyConverterWidgetState
    extends ConsumerState<CurrencyConverterWidget> {
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount.toString();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialFromCurrency != null) {
        ref
            .read(currencyConverterProvider.notifier)
            .setFromCurrency(widget.initialFromCurrency!);
      }
      if (widget.initialToCurrency != null) {
        ref
            .read(currencyConverterProvider.notifier)
            .setToCurrency(widget.initialToCurrency!);
      }
      if (widget.initialAmount != null) {
        ref
            .read(currencyConverterProvider.notifier)
            .setAmount(widget.initialAmount!);
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(currencyConverterProvider);

    return Container(
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: theme.hintColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.currency_exchange, color: AppColors.oceanTeal),
              const SizedBox(width: AppSizes.space8),
              Text(
                'Currency Converter',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space16),

          // Amount input
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              prefixText:
                  '${getCurrencyByCode(state.fromCurrency)?.symbol ?? ''} ',
            ),
            onChanged: (value) {
              final amount = double.tryParse(value) ?? 0;
              ref.read(currencyConverterProvider.notifier).setAmount(amount);
            },
          ),
          const SizedBox(height: AppSizes.space16),

          // Currency selectors
          Row(
            children: [
              Expanded(
                child: _CurrencyDropdown(
                  label: 'From',
                  value: state.fromCurrency,
                  onChanged: (currency) {
                    ref
                        .read(currencyConverterProvider.notifier)
                        .setFromCurrency(currency);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                onPressed: () {
                  ref.read(currencyConverterProvider.notifier).swapCurrencies();
                },
                color: AppColors.oceanTeal,
              ),
              Expanded(
                child: _CurrencyDropdown(
                  label: 'To',
                  value: state.toCurrency,
                  onChanged: (currency) {
                    ref
                        .read(currencyConverterProvider.notifier)
                        .setToCurrency(currency);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space16),

          // Convert button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.isLoading
                  ? null
                  : () {
                      ref.read(currencyConverterProvider.notifier).convert();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.oceanTeal,
              ),
              child: state.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('Convert'),
            ),
          ),

          // Result
          if (state.result != null) ...[
            const SizedBox(height: AppSizes.space16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.space16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Column(
                children: [
                  Text(
                    formatCurrency(
                        state.result!.convertedAmount, state.toCurrency),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space4),
                  Text(
                    '1 ${state.fromCurrency} = ${state.result!.rate.toStringAsFixed(4)} ${state.toCurrency}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Error
          if (state.error != null) ...[
            const SizedBox(height: AppSizes.space16),
            Container(
              padding: const EdgeInsets.all(AppSizes.space12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: AppSizes.space8),
                  Expanded(
                    child: Text(
                      'Conversion failed. Please try again.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _CurrencyDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSizes.space4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.space12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.hintColor),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: commonCurrencies.map((currency) {
              return DropdownMenuItem(
                value: currency.code,
                child: Text(
                  '${currency.flagEmoji} ${currency.code}',
                  style: theme.textTheme.bodyMedium,
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
          ),
        ),
      ],
    );
  }
}

/// Compact currency display for expense summaries
class CurrencyConversionChip extends StatelessWidget {
  final double amount;
  final String fromCurrency;
  final String toCurrency;
  final double rate;

  const CurrencyConversionChip({
    super.key,
    required this.amount,
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    final convertedAmount = amount * rate;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: AppSizes.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.oceanTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '≈ ${formatCurrency(convertedAmount, toCurrency)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.oceanTeal,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
