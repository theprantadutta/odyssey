import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/packing_model.dart';
import '../providers/packing_provider.dart';

/// Screen for creating or editing a packing item
class PackingItemFormScreen extends ConsumerStatefulWidget {
  final String tripId;
  final PackingItemModel? item;

  const PackingItemFormScreen({
    super.key,
    required this.tripId,
    this.item,
  });

  @override
  ConsumerState<PackingItemFormScreen> createState() =>
      _PackingItemFormScreenState();
}

class _PackingItemFormScreenState extends ConsumerState<PackingItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late TextEditingController _quantityController;
  late PackingCategory _selectedCategory;
  bool _isLoading = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _notesController = TextEditingController(text: widget.item?.notes ?? '');
    _quantityController = TextEditingController(
      text: widget.item?.quantity.toString() ?? '1',
    );
    _selectedCategory = widget.item != null
        ? PackingCategory.fromString(widget.item!.category)
        : PackingCategory.other;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snowWhite,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.space20),
          children: [
            // Name field
            _buildNameField(),
            const SizedBox(height: AppSizes.space20),

            // Category selector
            _buildCategorySelector(),
            const SizedBox(height: AppSizes.space20),

            // Quantity field
            _buildQuantityField(),
            const SizedBox(height: AppSizes.space20),

            // Notes field
            _buildNotesField(),
            const SizedBox(height: AppSizes.space32),

            // Save button
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.snowWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.snowWhite,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: AppColors.mutedGray.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.charcoal,
          ),
        ),
      ),
      title: Text(
        _isEditing ? 'Edit Item' : 'Add Item',
        style: AppTypography.headlineSmall.copyWith(
          color: AppColors.charcoal,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Name',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.charcoal),
          decoration: InputDecoration(
            hintText: 'e.g., T-shirts, Toothbrush, Charger...',
            hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.slate),
            filled: true,
            fillColor: AppColors.snowWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide(
                color: AppColors.mutedGray.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide(
                color: AppColors.mutedGray.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: const BorderSide(color: AppColors.oceanTeal, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.all(AppSizes.space16),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter an item name';
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
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSizes.space12),
        Wrap(
          spacing: AppSizes.space8,
          runSpacing: AppSizes.space8,
          children: PackingCategory.values.map((category) {
            final isSelected = category == _selectedCategory;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = category);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space16,
                  vertical: AppSizes.space12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _getCategoryColor(category)
                      : AppColors.snowWhite,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  border: Border.all(
                    color: isSelected
                        ? _getCategoryColor(category)
                        : AppColors.mutedGray.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.icon,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: AppSizes.space8),
                    Text(
                      category.displayName,
                      style: AppTypography.labelMedium.copyWith(
                        color: isSelected ? Colors.white : AppColors.charcoal,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
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

  Widget _buildQuantityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantity',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        Row(
          children: [
            // Decrease button
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                final current = int.tryParse(_quantityController.text) ?? 1;
                if (current > 1) {
                  _quantityController.text = (current - 1).toString();
                }
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.snowWhite,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  border: Border.all(
                    color: AppColors.mutedGray.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.remove_rounded,
                  color: AppColors.charcoal,
                ),
              ),
            ),

            const SizedBox(width: AppSizes.space12),

            // Quantity input
            SizedBox(
              width: 80,
              child: TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.snowWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    borderSide: BorderSide(
                      color: AppColors.mutedGray.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    borderSide: BorderSide(
                      color: AppColors.mutedGray.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    borderSide: const BorderSide(color: AppColors.oceanTeal, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space12,
                    vertical: AppSizes.space12,
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  final qty = int.tryParse(value);
                  if (qty == null || qty < 1) {
                    return 'Min 1';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(width: AppSizes.space12),

            // Increase button
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                final current = int.tryParse(_quantityController.text) ?? 1;
                _quantityController.text = (current + 1).toString();
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.oceanTeal,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
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
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        TextFormField(
          controller: _notesController,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.charcoal),
          decoration: InputDecoration(
            hintText: 'Add any notes or reminders...',
            hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.slate),
            filled: true,
            fillColor: AppColors.snowWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide(
                color: AppColors.mutedGray.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide(
                color: AppColors.mutedGray.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: const BorderSide(color: AppColors.oceanTeal, width: 2),
            ),
            contentPadding: const EdgeInsets.all(AppSizes.space16),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _saveItem,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSizes.space16),
        decoration: BoxDecoration(
          color: _isLoading
              ? AppColors.oceanTeal.withValues(alpha: 0.5)
              : AppColors.oceanTeal,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: _isLoading
              ? null
              : [
                  BoxShadow(
                    color: AppColors.oceanTeal.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _isEditing ? 'Update Item' : 'Add Item',
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  Color _getCategoryColor(PackingCategory category) {
    switch (category) {
      case PackingCategory.clothes:
        return AppColors.coralPink;
      case PackingCategory.toiletries:
        return AppColors.skyBlue;
      case PackingCategory.electronics:
        return AppColors.sunnyYellow;
      case PackingCategory.documents:
        return AppColors.lavenderDream;
      case PackingCategory.medicine:
        return AppColors.mintGreen;
      case PackingCategory.other:
        return AppColors.slate;
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final packingNotifier =
          ref.read(tripPackingProvider(widget.tripId).notifier);

      if (_isEditing) {
        await packingNotifier.updatePackingItem(
          widget.item!.id,
          {
            'name': _nameController.text.trim(),
            'category': _selectedCategory.name,
            'quantity': int.parse(_quantityController.text),
            'notes': _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          },
        );
      } else {
        await packingNotifier.createPackingItem(
          PackingItemRequest(
            tripId: widget.tripId,
            name: _nameController.text.trim(),
            category: _selectedCategory.name,
            quantity: int.parse(_quantityController.text),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: AppSizes.space12),
                Text(_isEditing ? 'Item updated' : 'Item added'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isEditing ? 'update' : 'add'} item: $e'),
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
        setState(() => _isLoading = false);
      }
    }
  }
}
