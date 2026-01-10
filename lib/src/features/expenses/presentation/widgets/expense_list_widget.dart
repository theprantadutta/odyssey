import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Expense summary widget showing category breakdown
class ExpenseSummaryWidget extends StatelessWidget {
  final ExpenseSummaryResponse? summary;
  final double totalAmount;
  final String currency;

  const ExpenseSummaryWidget({
    super.key,
    this.summary,
    required this.totalAmount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSizes.space16),
      padding: const EdgeInsets.all(AppSizes.space20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.sunnyYellow,
            AppColors.goldenGlow,
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.sunnyYellow.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total amount header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Spent',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.charcoal.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: AppSizes.space4),
                  Text(
                    '${_getCurrencySymbol(currency)}${_formatAmount(totalAmount)}',
                    style: AppTypography.headlineLarge.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space12,
                  vertical: AppSizes.space8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Text(
                  currency,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          if (summary != null && summary!.byCategory.isNotEmpty) ...[
            const SizedBox(height: AppSizes.space20),
            const Divider(color: AppColors.charcoal, height: 1),
            const SizedBox(height: AppSizes.space16),

            // Category breakdown
            ...summary!.byCategory.map((cat) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.space8),
                  child: _buildCategoryRow(cat),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow(ExpenseSummary category) {
    final percentage = _calculatePercentage(category.totalAmount, totalAmount);
    final color = _getCategoryColor(category.category);

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
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${_getCurrencySymbol(category.currency)}${_formatAmount(category.totalAmount)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space4),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: AppColors.charcoal.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
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

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'BDT':
        return '৳';
      case 'INR':
        return '₹';
      default:
        return '';
    }
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
