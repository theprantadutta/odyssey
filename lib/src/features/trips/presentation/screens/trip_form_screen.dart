import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/constants/currencies.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/utils/validators.dart';
import '../../../../common/widgets/cover_image_picker.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../common/widgets/odyssey/range_calendar.dart';
import '../../../../core/services/file_upload_service.dart';
import '../../../subscription/presentation/utils/limit_checker.dart';
import '../../../walkthrough/presentation/providers/walkthrough_provider.dart';
import '../../../walkthrough/presentation/steps/trip_creation_walkthrough_steps.dart';
import '../../../walkthrough/presentation/widgets/walkthrough_overlay.dart';
import '../../data/models/trip_model.dart';
import '../providers/trips_provider.dart';

/// Create or edit a trip — screen 3d.
///
/// Header, title, the two field cards, the range calendar with its From / To
/// summary, the style chips, and a sticky footer whose label reflects the
/// state of the range.
///
/// The design shows a three-step flow. Odyssey's form is one screen with more
/// fields than the mock draws (cover image, description, budget, currency,
/// tags), so the step counter reports genuine progress through the required
/// fields rather than a wizard that does not exist.
class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen({super.key, this.trip});

  final TripModel? trip;

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  /// The trip-style chips. Stored as ordinary tags, which is what the API
  /// already understands.
  static const List<String> _styles = [
    'Slow',
    'Packed',
    'Nature',
    'Food',
    'Culture',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _tagController = TextEditingController();
  final _fileUploadService = FileUploadService();

  DateTime? _startDate;
  DateTime? _endDate;
  TripStatus _status = TripStatus.planned;
  List<String> _tags = [];
  bool _isLoading = false;
  CoverImageResult _coverImageResult = CoverImageResult.empty;
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  String _displayCurrency = 'USD';

  // Walkthrough anchors.
  final _basicInfoKey = GlobalKey();
  final _coverImageKey = GlobalKey();
  final _datesKey = GlobalKey();
  final _budgetKey = GlobalKey();

  bool get _isEditing => widget.trip != null;

  @override
  void initState() {
    super.initState();
    if (widget.trip != null) _initializeWithTrip(widget.trip!);

    // Only for trip creation; editing is not a first-run experience.
    if (widget.trip == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          ref
              .read(walkthroughProvider.notifier)
              .startIfNeeded(
                'trip_creation',
                TripCreationWalkthroughSteps.build(
                  basicInfoKey: _basicInfoKey,
                  coverImageKey: _coverImageKey,
                  datesKey: _datesKey,
                  budgetKey: _budgetKey,
                ),
              );
        });
      });
    }
  }

  void _initializeWithTrip(TripModel trip) {
    _titleController.text = trip.title;
    _descriptionController.text = trip.description ?? '';
    if (trip.coverImageUrl != null && trip.coverImageUrl!.isNotEmpty) {
      _coverImageResult = CoverImageResult.fromUrl(trip.coverImageUrl!);
    }
    _startDate = DateTime.parse(trip.startDate);
    _endDate = DateTime.parse(trip.endDate);
    _status = TripStatus.values.firstWhere(
      (s) => s.name == trip.status,
      orElse: () => TripStatus.planned,
    );
    _tags = List.of(trip.tags ?? const []);
    if (trip.budget != null) {
      _budgetController.text = trip.budget!.toStringAsFixed(2);
    }
    _displayCurrency = trip.displayCurrency;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Derived state
  // ------------------------------------------------------------------

  int get _nights => TripFormat.nights(_startDate, _endDate);

  bool get _hasRange => _startDate != null && _endDate != null;

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty && _hasRange && !_isLoading;

  /// What the sticky footer says. The label is the state of the form, so it
  /// tells the user what is missing rather than sitting there greyed out
  /// without explanation.
  String get _ctaLabel {
    if (_isUploading) {
      return 'Uploading cover · ${(_uploadProgress * 100).round()}%';
    }
    if (_titleController.text.trim().isEmpty) return 'Name the trip';
    if (_startDate == null) return 'Pick a start date';
    if (_endDate == null) return 'Pick an end date';
    if (_isEditing) return 'Save changes';
    return 'Create · $_nights ${_nights == 1 ? 'night' : 'nights'}';
  }

  /// The step counter. Three real gates: a name, a start, an end.
  int get _completedSteps {
    var done = 0;
    if (_titleController.text.trim().isNotEmpty) done++;
    if (_startDate != null) done++;
    if (_endDate != null) done++;
    return done;
  }

  /// The selected style chip, if exactly one of the known styles is tagged.
  String? get _selectedStyle {
    for (final style in _styles) {
      if (_tags.contains(style.toLowerCase())) return style;
    }
    return null;
  }

  void _selectStyle(String style) {
    HapticFeedback.selectionClick();
    setState(() {
      // Styles are single-select, so clear the others before adding this one.
      _tags.removeWhere((t) => _styles.any((s) => s.toLowerCase() == t));
      if (_selectedStyle != style) _tags.add(style.toLowerCase());
    });
  }

  void _addTag() {
    final tag = _tagController.text.trim().toLowerCase();
    if (tag.isEmpty || _tags.contains(tag)) return;
    HapticFeedback.lightImpact();
    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  void _removeTag(String tag) {
    HapticFeedback.selectionClick();
    setState(() => _tags.remove(tag));
  }

  Future<void> _pickCurrency() async {
    final picked =
        await showOdysseyPicker<({String code, String name, String symbol})>(
      context: context,
      title: 'Display currency',
      options: commonCurrencies,
      labelOf: (c) => '${c.symbol} ${c.code}',
      selected: commonCurrencies.firstWhere(
        (c) => c.code == _displayCurrency,
        orElse: () => commonCurrencies.first,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _displayCurrency = picked.code);
    }
  }

  // ------------------------------------------------------------------
  // Submit
  // ------------------------------------------------------------------

  Future<void> _handleSubmit() async {
    if (widget.trip == null) {
      final canCreate = await LimitChecker.canCreateTrip(context, ref);
      if (!canCreate) return;
    }

    if (!mounted) return;
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    if (!_hasRange) {
      HapticFeedback.lightImpact();
      showOdysseyMessage(context, 'Pick a start and an end date.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? coverImageUrl = _coverImageResult.url;

      if (_coverImageResult.needsUpload) {
        setState(() {
          _isUploading = true;
          _uploadProgress = 0.0;
        });

        try {
          final uploadResult = await _fileUploadService.uploadCoverImage(
            file: _coverImageResult.localFile!,
            onProgress: (sent, total) {
              if (mounted) setState(() => _uploadProgress = sent / total);
            },
          );
          coverImageUrl = uploadResult.url;
        } finally {
          if (mounted) setState(() => _isUploading = false);
        }
      }

      final budgetText = _budgetController.text.trim();
      final request = TripRequest(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        coverImageUrl: coverImageUrl,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        status: _status.name,
        tags: _tags.isEmpty ? null : _tags,
        budget: budgetText.isEmpty ? null : double.tryParse(budgetText),
        displayCurrency: _displayCurrency,
      );

      if (widget.trip == null) {
        await ref.read(tripsProvider.notifier).createTrip(request);
      } else {
        await ref
            .read(tripsProvider.notifier)
            .updateTrip(widget.trip!.id, request.toJson());
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showOdysseyMessage(
        context,
        widget.trip == null ? 'Trip created.' : 'Trip updated.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      showOdysseyMessage(context, 'That did not save: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    final form = Scaffold(
      backgroundColor: t.canvas,
      body: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.contentTop,
                  AppSizes.screenPadding,
                  AppSizes.scrollBottom,
                ),
                children: [
                  ScreenHeader(
                    title: _isEditing
                        ? 'Editing'
                        : 'Step $_completedSteps of 3',
                    leadingGlyph: '✕',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: AppSizes.space20),
                  Text(
                    _isEditing ? 'Edit trip' : 'New trip',
                    style: AppTypography.screenTitle.copyWith(
                      height: 1.02,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space20),

                  // --- name and description ---
                  KeyedSubtree(
                    key: _basicInfoKey,
                    child: Column(
                      children: [
                        FieldCard(
                          label: 'Trip name',
                          controller: _titleController,
                          hint: 'Kyoto in autumn',
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              Validators.required(value, fieldName: 'Trip name'),
                        ),
                        const SizedBox(height: AppSizes.space12),
                        FieldCard(
                          label: 'Notes',
                          controller: _descriptionController,
                          hint: 'What is this trip about?',
                          maxLines: 3,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.space12),

                  // --- cover ---
                  KeyedSubtree(
                    key: _coverImageKey,
                    child: CoverImagePicker(
                      initialUrl: widget.trip?.coverImageUrl,
                      enabled: !_isLoading,
                      onChanged: (result) =>
                          setState(() => _coverImageResult = result),
                    ),
                  ),
                  const SizedBox(height: AppSizes.space12),

                  // --- dates ---
                  KeyedSubtree(
                    key: _datesKey,
                    child: Column(
                      children: [
                        RangeCalendar(
                          start: _startDate,
                          end: _endDate,
                          onChanged: (start, end) => setState(() {
                            _startDate = start;
                            _endDate = end;
                          }),
                        ),
                        const SizedBox(height: AppSizes.space10),
                        Row(
                          children: [
                            Expanded(
                              child: ValueCard(
                                label: 'From',
                                value: _startDate == null
                                    ? null
                                    : TripFormat.shortDate(_startDate),
                              ),
                            ),
                            const SizedBox(width: AppSizes.space10),
                            Expanded(
                              child: ValueCard(
                                label: 'To',
                                value: _endDate == null
                                    ? null
                                    : TripFormat.shortDate(_endDate),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.space20),

                  // --- style ---
                  const EyebrowLabel('Trip style'),
                  const SizedBox(height: AppSizes.space12),
                  ChipWrap(
                    labels: _styles,
                    selected: _selectedStyle,
                    onSelected: _selectStyle,
                  ),
                  const SizedBox(height: AppSizes.space20),

                  // --- budget ---
                  KeyedSubtree(
                    key: _budgetKey,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: FieldCard(
                            label: 'Budget',
                            controller: _budgetController,
                            hint: 'Optional',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.space10),
                        Expanded(
                          child: ValueCard(
                            label: 'Currency',
                            value: _displayCurrency,
                            onTap: _isLoading ? null : _pickCurrency,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.space20),

                  // --- status ---
                  const EyebrowLabel('Status'),
                  const SizedBox(height: AppSizes.space12),
                  SegmentedControl(
                    labels: TripStatus.values
                        .map((s) => s.displayName)
                        .toList(),
                    selected: _status.displayName,
                    onSelected: (label) => setState(() {
                      _status = TripStatus.values.firstWhere(
                        (s) => s.displayName == label,
                      );
                    }),
                  ),
                  const SizedBox(height: AppSizes.space20),

                  // --- tags ---
                  const EyebrowLabel('Tags'),
                  const SizedBox(height: AppSizes.space12),
                  FieldCard(
                    label: 'Add a tag',
                    controller: _tagController,
                    hint: 'maple season',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addTag(),
                    trailing: Pressable(
                      onTap: _addTag,
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusChipXs,
                      ),
                      child: Text(
                        'Add',
                        style: AppTypography.legend.copyWith(color: t.ink2),
                      ),
                    ),
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.space12),
                    Wrap(
                      spacing: AppSizes.space8,
                      runSpacing: AppSizes.space8,
                      children: [
                        for (final tag in _tags)
                          OdysseyChip(
                            label: tag,
                            selected: false,
                            onTap: () => _removeTag(tag),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            StickyFooter(
              child: PillButton(
                label: _ctaLabel,
                isLoading: _isLoading,
                onPressed: _canSubmit ? _handleSubmit : null,
              ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        form,
        Consumer(
          builder: (context, ref, _) {
            final wt = ref.watch(walkthroughProvider);
            if (!wt.isActive || wt.activeSegmentId != 'trip_creation') {
              return const SizedBox.shrink();
            }
            return WalkthroughOverlay(
              steps: wt.steps,
              currentIndex: wt.currentStepIndex,
              onNext: () => ref.read(walkthroughProvider.notifier).next(),
              onPrevious: () =>
                  ref.read(walkthroughProvider.notifier).previous(),
              onSkip: () => ref.read(walkthroughProvider.notifier).skip(),
            );
          },
        ),
      ],
    );
  }
}
