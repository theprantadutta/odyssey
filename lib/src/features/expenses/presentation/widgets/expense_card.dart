import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/expense_model.dart';

/// Expense card widget
class ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExpenseCard({
    super.key,
    required this.expense,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(expense.category);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onDelete?.call();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSizes.space12),
        padding: const EdgeInsets.all(AppSizes.space16),
        decoration: BoxDecoration(
          color: AppColors.snowWhite,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          boxShadow: AppSizes.softShadow,
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Center(
                child: Text(
                  _getCategoryEmoji(expense.category),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            // Title and date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.charcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.space4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.space8,
                          vertical: AppSizes.space4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        ),
                        child: Text(
                          _getCategoryDisplayName(expense.category),
                          style: AppTypography.caption.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.space8),
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: AppColors.mutedGray,
                      ),
                      const SizedBox(width: AppSizes.space4),
                      Text(
                        _formatDate(expense.date),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.mutedGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_getCurrencySymbol(expense.currency)}${_formatAmount(expense.amount)}',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSizes.space4),
                Text(
                  expense.currency,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.mutedGray,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,##0.00').format(amount);
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

/// Compact expense card for smaller displays
class ExpenseCardCompact extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback? onTap;

  const ExpenseCardCompact({
    super.key,
    required this.expense,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space12,
          vertical: AppSizes.space8,
        ),
        decoration: BoxDecoration(
          color: AppColors.warmGray,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Row(
          children: [
            Text(
              _getCategoryEmoji(expense.category),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: AppSizes.space8),
            Expanded(
              child: Text(
                expense.title,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.charcoal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${_getCurrencySymbol(expense.currency)}${_formatAmount(expense.amount)}',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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

  String _formatAmount(double amount) {
    return NumberFormat('#,##0.00').format(amount);
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
