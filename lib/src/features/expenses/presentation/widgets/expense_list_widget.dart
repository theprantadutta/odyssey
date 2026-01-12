import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../common/constants/currencies.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/expense_model.dart';
import 'expense_card.dart';

/// Expense list widget
class ExpenseListWidget extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final Function(ExpenseModel expense)? onExpenseTap;
  final Function(ExpenseModel expense)? onExpenseDelete;

  const ExpenseListWidget({
    super.key,
    required this.expenses,
    this.onExpenseTap,
    this.onExpenseDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        return ExpenseCard(
          expense: expense,
          onTap: () => onExpenseTap?.call(expense),
          onDelete: () => onExpenseDelete?.call(expense),
        );
      },
    );
  }
}

/// Expense summary widget showing category breakdown with budget tracking
class ExpenseSummaryWidget extends StatefulWidget {
  final ExpenseSummaryResponse? summary;
  final double totalAmount;
  final String currency;
  final VoidCallback? onRefreshRates;
  final bool isRefreshing;

  const ExpenseSummaryWidget({
    super.key,
    this.summary,
    required this.totalAmount,
    required this.currency,
    this.onRefreshRates,
    this.isRefreshing = false,
  });

  @override
  State<ExpenseSummaryWidget> createState() => _ExpenseSummaryWidgetState();
}

class _ExpenseSummaryWidgetState extends State<ExpenseSummaryWidget> {
  bool _showCurrencyBreakdown = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final displayCurrency = summary?.displayCurrency ?? widget.currency;
    final convertedTotal = summary?.convertedTotalAmount ?? widget.totalAmount;
    final hasBudget = summary?.hasBudget ?? false;
    final budget = summary?.budget;
    final budgetRemaining = summary?.budgetRemaining;
    final budgetUsedPercentage = summary?.budgetUsedPercentage ?? 0;
    final isOverBudget = summary?.isOverBudget ?? false;

    return Container(
      margin: const EdgeInsets.all(AppSizes.space16),
      padding: const EdgeInsets.all(AppSizes.space20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOverBudget
              ? [AppColors.error.withValues(alpha: 0.9), AppColors.coralBurst]
              : [AppColors.sunnyYellow, AppColors.goldenGlow],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: (isOverBudget ? AppColors.error : AppColors.sunnyYellow)
                .withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with total and refresh button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Spent',
                      style: AppTypography.labelMedium.copyWith(
                        color: isOverBudget
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppColors.charcoal.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: AppSizes.space4),
                    Text(
                      '${getCurrencySymbol(displayCurrency)}${_formatAmount(convertedTotal)}',
                      style: AppTypography.headlineLarge.copyWith(
                        color: isOverBudget ? Colors.white : AppColors.charcoal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (widget.onRefreshRates != null)
                    IconButton(
                      onPressed:
                          widget.isRefreshing ? null : widget.onRefreshRates,
                      icon: widget.isRefreshing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isOverBudget
                                    ? Colors.white
                                    : AppColors.charcoal,
                              ),
                            )
                          : Icon(
                              Icons.refresh_rounded,
                              color: isOverBudget
                                  ? Colors.white
                                  : AppColors.charcoal,
                            ),
                      tooltip: 'Refresh exchange rates',
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.space12,
                      vertical: AppSizes.space8,
                    ),
                    decoration: BoxDecoration(
                      color: isOverBudget
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.charcoal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Text(
                      displayCurrency,
                      style: AppTypography.labelLarge.copyWith(
                        color: isOverBudget ? Colors.white : AppColors.charcoal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Budget progress section
          if (hasBudget && budget != null) ...[
            const SizedBox(height: AppSizes.space16),
            _buildBudgetProgress(
              budget: budget,
              remaining: budgetRemaining ?? 0,
              usedPercentage: budgetUsedPercentage,
              isOverBudget: isOverBudget,
              displayCurrency: displayCurrency,
            ),
          ],

          // Currency breakdown toggle
          if (summary != null && summary.byCurrency.isNotEmpty) ...[
            const SizedBox(height: AppSizes.space16),
            _buildCurrencyBreakdownToggle(
              summary.byCurrency,
              isOverBudget,
              displayCurrency,
            ),
          ],

          if (summary != null && summary.byCategory.isNotEmpty) ...[
            const SizedBox(height: AppSizes.space20),
            Divider(
              color: isOverBudget
                  ? Colors.white.withValues(alpha: 0.3)
                  : AppColors.charcoal.withValues(alpha: 0.2),
              height: 1,
            ),
            const SizedBox(height: AppSizes.space16),

            // Category breakdown
            ...summary.byCategory.map((cat) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.space8),
                  child: _buildCategoryRow(cat, isOverBudget, convertedTotal),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetProgress({
    required double budget,
    required double remaining,
    required double usedPercentage,
    required bool isOverBudget,
    required String displayCurrency,
  }) {
    final progressValue = (usedPercentage / 100).clamp(0.0, 1.0);
    final textColor = isOverBudget ? Colors.white : AppColors.charcoal;

    Color progressColor;
    if (isOverBudget) {
      progressColor = Colors.white;
    } else if (usedPercentage > 80) {
      progressColor = AppColors.warning;
    } else {
      progressColor = AppColors.success;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Budget',
              style: AppTypography.labelMedium.copyWith(
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
            Text(
              '${getCurrencySymbol(displayCurrency)}${_formatAmount(budget)}',
              style: AppTypography.labelLarge.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          child: LinearProgressIndicator(
            value: progressValue,
            backgroundColor: textColor.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${usedPercentage.toStringAsFixed(1)}% used',
              style: AppTypography.caption.copyWith(
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
            Text(
              isOverBudget
                  ? '${getCurrencySymbol(displayCurrency)}${_formatAmount(remaining.abs())} over'
                  : '${getCurrencySymbol(displayCurrency)}${_formatAmount(remaining)} left',
              style: AppTypography.labelMedium.copyWith(
                color: isOverBudget ? Colors.white : AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrencyBreakdownToggle(
    List<CurrencyBreakdown> byCurrency,
    bool isOverBudget,
    String displayCurrency,
  ) {
    final textColor = isOverBudget ? Colors.white : AppColors.charcoal;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _showCurrencyBreakdown = !_showCurrencyBreakdown);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.space12,
              vertical: AppSizes.space8,
            ),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.currency_exchange_rounded,
                      size: 16,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: AppSizes.space8),
                    Text(
                      '${byCurrency.length} ${byCurrency.length == 1 ? 'currency' : 'currencies'}',
                      style: AppTypography.labelMedium.copyWith(
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showCurrencyBreakdown
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
        if (_showCurrencyBreakdown) ...[
          const SizedBox(height: AppSizes.space12),
          ...byCurrency.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.space8),
                child: _buildCurrencyRow(c, isOverBudget, displayCurrency),
              )),
        ],
      ],
    );
  }

  Widget _buildCurrencyRow(
    CurrencyBreakdown breakdown,
    bool isOverBudget,
    String displayCurrency,
  ) {
    final textColor = isOverBudget ? Colors.white : AppColors.charcoal;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space8,
                vertical: AppSizes.space4,
              ),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(
                breakdown.currency,
                style: AppTypography.caption.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.space8),
            Text(
              '${getCurrencySymbol(breakdown.currency)}${_formatAmount(breakdown.originalAmount)}',
              style: AppTypography.bodySmall.copyWith(
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${getCurrencySymbol(displayCurrency)}${_formatAmount(breakdown.convertedAmount)}',
              style: AppTypography.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (breakdown.currency != displayCurrency)
              Text(
                '@ ${breakdown.exchangeRate.toStringAsFixed(4)}',
                style: AppTypography.caption.copyWith(
                  color: textColor.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryRow(
      ExpenseSummary category, bool isOverBudget, double total) {
    final percentage = _calculatePercentage(category.totalAmount, total);
    final color = _getCategoryColor(category.category);
    final textColor = isOverBudget ? Colors.white : AppColors.charcoal;

    return Row(
      children: [
        Text(
          _getCategoryEmoji(category.category),
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(width: AppSizes.space8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getCategoryDisplayName(category.category),
                    style: AppTypography.bodySmall.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${getCurrencySymbol(category.currency)}${_formatAmount(category.totalAmount)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space4),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: textColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      isOverBudget ? Colors.white : color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _calculatePercentage(double categoryAmount, double total) {
    if (total == 0) return 0;
    return (categoryAmount / total * 100).clamp(0, 100);
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return AppColors.coralBurst;
      case 'transport':
        return AppColors.skyBlue;
      case 'accommodation':
        return AppColors.lavenderDream;
      case 'activities':
        return AppColors.oceanTeal;
      case 'shopping':
        return AppColors.sunnyYellow;
      case 'other':
      default:
        return AppColors.slate;
    }
  }

  String _getCategoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return '🍔';
      case 'transport':
        return '🚗';
      case 'accommodation':
        return '🏨';
      case 'activities':
        return '🎯';
      case 'shopping':
        return '🛍️';
      case 'other':
      default:
        return '📝';
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return 'Food';
      case 'transport':
        return 'Transport';
      case 'accommodation':
        return 'Accommodation';
      case 'activities':
        return 'Activities';
      case 'shopping':
        return 'Shopping';
      case 'other':
      default:
        return 'Other';
    }
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }
}

/// No expenses empty state
class NoExpensesState extends StatelessWidget {
  final VoidCallback? onAddExpense;

  const NoExpensesState({
    super.key,
    this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.lemonLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              ),
              child: const Center(
                child: Text(
                  '💰',
                  style: TextStyle(fontSize: 36),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            // Title
            Text(
              'No Expenses Yet',
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.charcoal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            // Description
            Text(
              'Track your travel expenses to stay on budget.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slate,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space24),
            // Add button
            if (onAddExpense != null)
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onAddExpense?.call();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add First Expense'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.sunnyYellow,
                  backgroundColor: AppColors.lemonLight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space20,
                    vertical: AppSizes.space12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
