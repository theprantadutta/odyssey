import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../../expenses/presentation/screens/expense_form_screen.dart';
import '../../../expenses/presentation/widgets/expense_list_widget.dart';

class TripExpensesTab extends ConsumerWidget {
  final String tripId;

  const TripExpensesTab({
    super.key,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesState = ref.watch(tripExpensesProvider(tripId));

    return Stack(
      children: [
        // Main content
        _buildContent(context, ref, expensesState),
        // FAB
        Positioned(
          right: AppSizes.space16,
          bottom: AppSizes.space16,
          child: _buildFAB(context),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ExpensesState state,
  ) {
    // Loading state
    if (state.isLoading && state.expenses.isEmpty) {
      return _buildLoadingState();
    }

    // Error state
    if (state.error != null && state.expenses.isEmpty) {
      return _buildErrorState(context, ref, state.error!);
    }

    // Empty state
    if (state.expenses.isEmpty) {
      return NoExpensesState(
        onAddExpense: () => _navigateToAddExpense(context),
      );
    }

    // Expenses list
    return RefreshIndicator(
      color: AppColors.sunnyYellow,
      onRefresh: () async {
        await ref.read(tripExpensesProvider(tripId).notifier).refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          bottom: AppSizes.space80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Budget summary
            ExpenseSummaryWidget(
              summary: state.summary,
              totalAmount: state.totalAmount,
              currency: state.summary?.currency ?? 'USD',
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${state.expenses.length} ${state.expenses.length == 1 ? 'Expense' : 'Expenses'}',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.space8),

            // Expenses list
            ExpenseListWidget(
              expenses: state.expenses,
              onExpenseTap: (expense) => _navigateToEditExpense(context, expense),
              onExpenseDelete: (expense) => _showDeleteDialog(context, ref, expense),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.space16),
      child: Column(
        children: [
          // Summary skeleton
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.warmGray,
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            ),
          ),
          const SizedBox(height: AppSizes.space16),
          // Expense card skeletons
          ...List.generate(
            3,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: AppSizes.space12),
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.warmGray,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              'Failed to load expenses',
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.charcoal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              error,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slate,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space24),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(tripExpensesProvider(tripId).notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
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

  Widget _buildFAB(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _navigateToAddExpense(context);
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.sunnyYellow,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.sunnyYellow.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: AppColors.charcoal,
          size: 28,
        ),
      ),
    );
  }

  void _navigateToAddExpense(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpenseFormScreen(tripId: tripId),
      ),
    );
  }

  void _navigateToEditExpense(BuildContext context, ExpenseModel expense) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpenseFormScreen(
          tripId: tripId,
          expense: expense,
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    ExpenseModel expense,
  ) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.snowWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        title: Text(
          'Delete Expense',
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.charcoal,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${expense.title}"? This action cannot be undone.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.slate,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.slate,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop();
              try {
                await ref
                    .read(tripExpensesProvider(tripId).notifier)
                    .deleteExpense(expense.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white),
                          SizedBox(width: AppSizes.space12),
                          Text('Expense deleted'),
                        ],
                      ),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
