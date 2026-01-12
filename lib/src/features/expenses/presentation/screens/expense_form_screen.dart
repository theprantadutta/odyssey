import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../common/constants/currencies.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/expense_model.dart';
import '../providers/expenses_provider.dart';

/// Screen for creating/editing an expense
class ExpenseFormScreen extends ConsumerStatefulWidget {
  final String tripId;
  final ExpenseModel? expense;

  const ExpenseFormScreen({
    super.key,
    required this.tripId,
    this.expense,
  });

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = 'other';
  String _selectedCurrency = 'USD';
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  bool get _isEditing => widget.expense != null;

  static const _categories = [
    ('food', 'Food', '🍔'),
    ('transport', 'Transport', '🚗'),
    ('accommodation', 'Accommodation', '🏨'),
    ('activities', 'Activities', '🎯'),
    ('shopping', 'Shopping', '🛍️'),
    ('other', 'Other', '📝'),
  ];


  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.expense!.title;
      _amountController.text = widget.expense!.amount.toStringAsFixed(2);
      _selectedCategory = widget.expense!.category;
      _selectedCurrency = widget.expense!.currency;
      _notesController.text = widget.expense!.notes ?? '';
      try {
        _selectedDate = DateTime.parse(widget.expense!.date);
      } catch (e) {
        _selectedDate = DateTime.now();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloudGray,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount and Currency
              _buildAmountSection(),
              const SizedBox(height: AppSizes.space20),

              // Title
              _buildTitleField(),
              const SizedBox(height: AppSizes.space16),

              // Category
              _buildCategorySelector(),
              const SizedBox(height: AppSizes.space16),

              // Date
              _buildDateField(),
              const SizedBox(height: AppSizes.space16),

              // Notes
              _buildNotesField(),
              const SizedBox(height: AppSizes.space32),

              // Submit button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.cloudGray,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: AppColors.charcoal),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
      ),
      title: Text(
        _isEditing ? 'Edit Expense' : 'Add Expense',
        style: AppTypography.headlineSmall.copyWith(
          color: AppColors.charcoal,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildAmountSection() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.space20),
      decoration: BoxDecoration(
        color: AppColors.snowWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: AppSizes.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: AppSizes.space12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Currency dropdown
              Container(
                decoration: BoxDecoration(
                  color: AppColors.warmGray,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCurrency,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.space12,
                    ),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    items: commonCurrencies.map((c) {
                      return DropdownMenuItem(
                        value: c.code,
                        child: Text(
                          '${c.symbol} ${c.code}',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.charcoal,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCurrency = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              // Amount input
              Expanded(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.headlineLarge.copyWith(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: AppTypography.headlineLarge.copyWith(
                      color: AppColors.mutedGray,
                      fontWeight: FontWeight.w700,
                    ),
                    filled: true,
                    fillColor: AppColors.warmGray,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(AppSizes.space16),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Invalid amount';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Title',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'e.g., Lunch at local restaurant',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.mutedGray,
            ),
            filled: true,
            fillColor: AppColors.snowWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: const BorderSide(
                color: AppColors.sunnyYellow,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(AppSizes.space16),
          ),
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.charcoal,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Title is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: AppSizes.space12),
        Wrap(
          spacing: AppSizes.space8,
          runSpacing: AppSizes.space8,
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat.$1;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat.$1);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space16,
                  vertical: AppSizes.space12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.sunnyYellow : AppColors.snowWhite,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  border: Border.all(
                    color: isSelected ? AppColors.goldenGlow : AppColors.warmGray,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat.$3, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: AppSizes.space8),
                    Text(
                      cat.$2,
                      style: AppTypography.labelMedium.copyWith(
                        color: isSelected ? AppColors.charcoal : AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(AppSizes.space16),
            decoration: BoxDecoration(
              color: AppColors.snowWhite,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.goldenGlow,
                  size: 20,
                ),
                const SizedBox(width: AppSizes.space12),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add any additional details...',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.mutedGray,
            ),
            filled: true,
            fillColor: AppColors.snowWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(AppSizes.space16),
          ),
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.charcoal,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sunnyYellow,
          foregroundColor: AppColors.charcoal,
          disabledBackgroundColor: AppColors.warmGray,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.charcoal,
                ),
              )
            : Text(
                _isEditing ? 'Save Changes' : 'Add Expense',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.charcoal,
                ),
              ),
      ),
    );
  }

  Future<void> _selectDate() async {
    HapticFeedback.lightImpact();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.sunnyYellow,
              onPrimary: AppColors.charcoal,
              surface: AppColors.snowWhite,
              onSurface: AppColors.charcoal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    try {
      final notifier = ref.read(tripExpensesProvider(widget.tripId).notifier);

      if (_isEditing) {
        await notifier.updateExpense(
          widget.expense!.id,
          {
            'title': _titleController.text,
            'amount': double.tryParse(_amountController.text) ?? 0.0,
            'currency': _selectedCurrency,
            'category': _selectedCategory,
            'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
            'notes': _notesController.text.isNotEmpty ? _notesController.text : null,
          },
        );
      } else {
        await notifier.createExpense(
          ExpenseRequest(
            tripId: widget.tripId,
            title: _titleController.text,
            amount: double.tryParse(_amountController.text) ?? 0.0,
            currency: _selectedCurrency,
            category: _selectedCategory,
            date: DateFormat('yyyy-MM-dd').format(_selectedDate),
            notes: _notesController.text.isNotEmpty ? _notesController.text : null,
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: AppSizes.space12),
                Text(_isEditing ? 'Expense updated!' : 'Expense added!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
