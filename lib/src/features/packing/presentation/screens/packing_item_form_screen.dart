import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/validators.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../subscription/presentation/utils/limit_checker.dart';
import '../../data/models/packing_model.dart';
import '../providers/packing_provider.dart';

/// Add or edit a packing item.
class PackingItemFormScreen extends ConsumerStatefulWidget {
  const PackingItemFormScreen({
    super.key,
    required this.tripId,
    this.item,
  });

  final String tripId;
  final PackingItemModel? item;

  @override
  ConsumerState<PackingItemFormScreen> createState() =>
      _PackingItemFormScreenState();
}

class _PackingItemFormScreenState extends ConsumerState<PackingItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;

  late PackingCategory _category;
  int _quantity = 1;
  bool _isLoading = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _notesController = TextEditingController(text: widget.item?.notes ?? '');
    _quantity = widget.item?.quantity ?? 1;
    _category = widget.item != null
        ? PackingCategory.fromString(widget.item!.category)
        : PackingCategory.other;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty && !_isLoading;

  String get _submitLabel {
    if (_nameController.text.trim().isEmpty) return 'Name the item';
    return _isEditing ? 'Save changes' : 'Add to the list';
  }

  void _setQuantity(int next) {
    HapticFeedback.selectionClick();
    setState(() => _quantity = next.clamp(1, 99));
  }

  Future<void> _handleSubmit() async {
    if (!_isEditing) {
      final currentCount =
          ref.read(tripPackingProvider(widget.tripId)).items.length;
      final canCreate = await LimitChecker.canCreatePackingItem(
        context,
        ref,
        currentCount: currentCount,
      );
      if (!canCreate) return;
      if (!mounted) return;
    }

    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(tripPackingProvider(widget.tripId).notifier);
      final notes = _notesController.text.trim();

      if (_isEditing) {
        await notifier.updatePackingItem(widget.item!.id, {
          'name': _nameController.text.trim(),
          'category': _category.name,
          'quantity': _quantity,
          'notes': notes.isEmpty ? null : notes,
        });
      } else {
        await notifier.createPackingItem(
          PackingItemRequest(
            tripId: widget.tripId,
            name: _nameController.text.trim(),
            category: _category.name,
            quantity: _quantity,
            notes: notes.isEmpty ? null : notes,
          ),
        );
      }

      if (!mounted) return;
      showOdysseyMessage(context, _isEditing ? 'Item updated.' : 'Item added.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      showOdysseyError(context, 'That did not save.', error: e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Remove item',
      body: ['This takes "${widget.item!.name}" off the packing list.'],
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;

    await ref
        .read(tripPackingProvider(widget.tripId).notifier)
        .deletePackingItem(widget.item!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return OdysseyFormScreen(
      formKey: _formKey,
      onChanged: () => setState(() {}),
      caption: _isEditing ? 'Editing' : null,
      title: _isEditing ? 'Edit item' : 'New item',
      submitLabel: _submitLabel,
      onSubmit: _canSubmit ? _handleSubmit : null,
      isLoading: _isLoading,
      secondaryLabel: _isEditing ? 'Remove item' : null,
      onSecondary: _isEditing ? _handleDelete : null,
      children: [
        FieldCard(
          label: 'Item',
          controller: _nameController,
          hint: 'Rain shell',
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          validator: (value) => Validators.required(value, fieldName: 'Name'),
        ),
        const SizedBox(height: AppSizes.space12),

        _QuantityRow(
          quantity: _quantity,
          onChanged: _setQuantity,
        ),
        const SizedBox(height: AppSizes.space20),

        FormGroup(
          label: 'Category',
          child: ChipWrap(
            labels: PackingCategory.values.map((c) => c.displayName).toList(),
            selected: _category.displayName,
            onSelected: (label) => setState(() {
              _category = PackingCategory.values.firstWhere(
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

/// A stepper rather than a text field: quantity is almost always a small
/// number nudged up or down, and a keyboard for it is friction.
class _QuantityRow extends StatelessWidget {
  const _QuantityRow({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusInput),
        border: Border.all(color: t.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const EyebrowLabel('How many'),
                const SizedBox(height: 7),
                Text(
                  '$quantity',
                  style: AppTypography.fieldValueStrong.copyWith(color: t.ink),
                ),
              ],
            ),
          ),
          CircleButton(
            glyph: '−',
            size: AppSizes.circleSm,
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            semanticLabel: 'One fewer',
          ),
          const SizedBox(width: AppSizes.space8),
          CircleButton(
            glyph: '+',
            size: AppSizes.circleSm,
            style: CircleStyle.action,
            onPressed: () => onChanged(quantity + 1),
            semanticLabel: 'One more',
          ),
        ],
      ),
    );
  }
}
