import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../common/constants/currencies.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/form_section_card.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: colorScheme.onSurface),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
      ),
      title: Text(
        _isEditing ? 'Edit Expense' : 'Add Expense',
        style: AppTypography.headlineSmall.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildAmountSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FormSectionCard(
      title: 'Amount',
      icon: Icons.attach_money_rounded,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Currency dropdown
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(
                  color: theme.hintColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
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
                          color: colorScheme.onSurface,
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
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: AppTypography.headlineLarge.copyWith(
                    color: theme.hintColor,
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    borderSide: BorderSide(
                      color: theme.hintColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    borderSide: BorderSide(
                      color: theme.hintColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    borderSide: const BorderSide(
                      color: AppColors.sunnyYellow,
                      width: 2,
                    ),
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
    );
  }

  Widget _buildTitleField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FormSectionCard(
      title: 'Title',
      icon: Icons.title_rounded,
      children: [
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'e.g., Lunch at local restaurant',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: theme.hintColor,
            ),
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide(
                color: theme.hintColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide(
                color: theme.hintColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
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
            color: colorScheme.onSurface,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FormSectionCard(
      title: 'Category',
      icon: Icons.category_rounded,
      children: [
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
                  color: isSelected ? AppColors.sunnyYellow : colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.goldenGlow
                        : theme.hintColor.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1.5,
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
                        color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FormSectionCard(
      title: 'Date',
      icon: Icons.calendar_today_rounded,
      children: [
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(AppSizes.space16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(
                color: theme.hintColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
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
                    color: colorScheme.onSurface,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FormSectionCard(
      title: 'Notes (Optional)',
      icon: Icons.notes_rounded,
      children: [
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add any additional details...',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: theme.hintColor,
            ),
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide(
                color: theme.hintColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide(
                color: theme.hintColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: const BorderSide(
                color: AppColors.sunnyYellow,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(AppSizes.space16),
          ),
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sunnyYellow,
          foregroundColor: colorScheme.onSurface,
          disabledBackgroundColor: colorScheme.surfaceContainerHighest,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onSurface,
                ),
              )
            : Text(
                _isEditing ? 'Save Changes' : 'Add Expense',
                style: AppTypography.labelLarge.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
      ),
    );
  }

  Future<void> _selectDate() async {
    HapticFeedback.lightImpact();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: colorScheme.copyWith(
              primary: AppColors.sunnyYellow,
              onPrimary: colorScheme.onSurface,
              surface: colorScheme.surface,
              onSurface: colorScheme.onSurface,
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
