import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/constants/currencies.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/utils/validators.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../subscription/presentation/utils/limit_checker.dart';
import '../../data/models/expense_model.dart';
import '../providers/expenses_provider.dart';

/// Add or edit an expense.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({
    super.key,
    required this.tripId,
    this.expense,
  });

  final String tripId;
  final ExpenseModel? expense;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  ExpenseCategory _category = ExpenseCategory.other;
  String _currency = 'USD';
  DateTime _date = DateTime.now();
  bool _isSubmitting = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    if (!_isEditing) return;

    final expense = widget.expense!;
    _titleController.text = expense.title;
    _amountController.text = expense.amount.toStringAsFixed(2);
    _notesController.text = expense.notes ?? '';
    _currency = expense.currency;
    _category = ExpenseCategory.values.firstWhere(
      (c) => c.name == expense.category,
      orElse: () => ExpenseCategory.other,
    );
    _date = DateTime.tryParse(expense.date) ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountController.text.trim());

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      (_amount ?? 0) > 0 &&
      !_isSubmitting;

  String get _submitLabel {
    if (_titleController.text.trim().isEmpty) return 'Name the expense';
    if ((_amount ?? 0) <= 0) return 'Enter an amount';
    return _isEditing ? 'Save changes' : 'Add to the budget';
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickCurrency() async {
    final picked =
        await showOdysseyPicker<({String code, String name, String symbol})>(
          context: context,
          title: 'Currency',
          options: commonCurrencies,
          labelOf: (c) => '${c.symbol} ${c.code}',
          selected: commonCurrencies.firstWhere(
            (c) => c.code == _currency,
            orElse: () => commonCurrencies.first,
          ),
        );
    if (picked != null && mounted) setState(() => _currency = picked.code);
  }

  Future<void> _handleSubmit() async {
    if (!_isEditing) {
      final currentCount =
          ref.read(tripExpensesProvider(widget.tripId)).expenses.length;
      final canCreate = await LimitChecker.canCreateExpense(
        context,
        ref,
        currentCount: currentCount,
      );
      if (!canCreate) return;
      if (!mounted) return;
    }

    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    try {
      final notifier = ref.read(tripExpensesProvider(widget.tripId).notifier);
      final notes = _notesController.text.trim();

      if (_isEditing) {
        await notifier.updateExpense(widget.expense!.id, {
          'title': _titleController.text.trim(),
          'amount': _amount ?? 0.0,
          'currency': _currency,
          'category': _category.name,
          'date': DateFormat('yyyy-MM-dd').format(_date),
          'notes': notes.isEmpty ? null : notes,
        });
      } else {
        await notifier.createExpense(
          ExpenseRequest(
            tripId: widget.tripId,
            title: _titleController.text.trim(),
            amount: _amount ?? 0.0,
            currency: _currency,
            category: _category.name,
            date: DateFormat('yyyy-MM-dd').format(_date),
            notes: notes.isEmpty ? null : notes,
          ),
        );
      }

      if (!mounted) return;
      showOdysseyMessage(
        context,
        _isEditing ? 'Expense updated.' : 'Expense added.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      showOdysseyError(context, 'That did not save.', error: e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Delete expense',
      body: ['This removes "${widget.expense!.title}" from the budget.'],
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    await ref
        .read(tripExpensesProvider(widget.tripId).notifier)
        .deleteExpense(widget.expense!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return OdysseyFormScreen(
      formKey: _formKey,
      onChanged: () => setState(() {}),
      caption: _isEditing ? 'Editing' : null,
      title: _isEditing ? 'Edit expense' : 'New expense',
      submitLabel: _submitLabel,
      onSubmit: _canSubmit ? _handleSubmit : null,
      isLoading: _isSubmitting,
      secondaryLabel: _isEditing ? 'Delete expense' : null,
      onSecondary: _isEditing ? _handleDelete : null,
      children: [
        FieldCard(
          label: 'What was it',
          controller: _titleController,
          hint: 'Dinner at Gion',
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          validator: (value) => Validators.required(value, fieldName: 'Title'),
        ),
        const SizedBox(height: AppSizes.space12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: FieldCard(
                label: 'Amount',
                controller: _amountController,
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter an amount above zero';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: AppSizes.space10),
            Expanded(
              child: ValueCard(
                label: 'Currency',
                value: _currency,
                onTap: _isSubmitting ? null : _pickCurrency,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space12),

        ValueCard(
          label: 'When',
          value: TripFormat.longDate(_date),
          onTap: _pickDate,
        ),
        const SizedBox(height: AppSizes.space20),

        FormGroup(
          label: 'Category',
          child: ChipWrap(
            labels: ExpenseCategory.values.map((c) => c.displayName).toList(),
            selected: _category.displayName,
            onSelected: (label) => setState(() {
              _category = ExpenseCategory.values.firstWhere(
                (c) => c.displayName == label,
              );
            }),
          ),
        ),
        const SizedBox(height: AppSizes.space20),

        FieldCard(
          label: 'Notes',
          controller: _notesController,
          hint: 'Optional',
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}
