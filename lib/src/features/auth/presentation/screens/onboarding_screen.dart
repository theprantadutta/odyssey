import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../common/widgets/odyssey/range_calendar.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/logger_service.dart';
import '../../../trips/data/models/trip_model.dart';
import '../../../trips/data/repositories/trip_repository.dart';
import '../../../trips/presentation/providers/trips_provider.dart';
import '../providers/auth_provider.dart';

/// The one screen after the first sign-in: name the next trip and pick its
/// dates, and land inside it.
///
/// It used to ask "demo trips or empty?", with the demo trips recommended.
/// Almost nobody went on to create a trip of their own — they arrived among
/// four trips that weren't theirs, looked around and left. So the default path
/// is now the user's own trip, and the samples and an empty start are
/// secondary.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// How the user leaves onboarding. The name is reported to analytics.
enum _Exit { firstTrip, sampleTrips, skipped }

extension on _Exit {
  String get analyticsName => switch (this) {
    _Exit.firstTrip => 'first_trip',
    _Exit.sampleTrips => 'sample_trips',
    _Exit.skipped => 'skipped',
  };
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _destinationController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  /// The exit in progress, if any. Every action is disabled while one runs.
  _Exit? _busy;

  bool get _canCreate =>
      _destinationController.text.trim().isNotEmpty &&
      _startDate != null &&
      _endDate != null;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  /// Past dates make it a trip being journalled rather than planned.
  TripStatus _statusFor(DateTime start, DateTime end) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (end.isBefore(today)) return TripStatus.completed;
    if (!start.isAfter(today)) return TripStatus.ongoing;
    return TripStatus.planned;
  }

  Future<void> _leave(_Exit exit) async {
    setState(() => _busy = exit);
    HapticFeedback.mediumImpact();
    // Captured up front: completing onboarding refreshes the router, which
    // moves off this screen and unmounts it before the code below finishes.
    final router = ref.read(routerProvider);

    try {
      TripModel? firstTrip;

      switch (exit) {
        case _Exit.firstTrip:
          final start = _startDate!;
          final end = _endDate!;
          final format = DateFormat('yyyy-MM-dd');
          firstTrip = await ref
              .read(tripsProvider.notifier)
              .createTrip(
                TripRequest(
                  title: _destinationController.text.trim(),
                  startDate: format.format(start),
                  endDate: format.format(end),
                  status: _statusFor(start, end).name,
                ),
                source: 'onboarding',
              );
          AppLogger.info('First trip created: ${firstTrip.title}');
        case _Exit.sampleTrips:
          final created = await TripRepository().createDefaultTrips();
          if (created != null) {
            AppLogger.info(
              'Demo trips created successfully: ${created.length}',
            );
          } else {
            AppLogger.info(
              'Demo trips already added to this account, skipping',
            );
          }
        case _Exit.skipped:
          AppLogger.action('User skipped the first trip');
      }

      await ref
          .read(authProvider.notifier)
          .completeOnboarding(choice: exit.analyticsName);
      AppLogger.lifecycle('Onboarding completed (${exit.analyticsName})');

      router.go(AppRoutes.home);
      if (firstTrip != null) {
        // Pushed over home rather than gone to directly, so the trip's back
        // button has somewhere to return to. The frame lets the `go` land
        // first; pushed straight away it stacks on the old location.
        await WidgetsBinding.instance.endOfFrame;
        router.push(
          '${AppRoutes.tripDetail}/${firstTrip.id}',
          extra: firstTrip,
        );
      }
    } catch (e) {
      AppLogger.error('Onboarding failed', e);
      if (mounted) {
        HapticFeedback.heavyImpact();
        showOdysseyError(context, 'That did not work.', error: e);
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final isBusy = _busy != null;
    // Sample trips are created by the server, which a guest cannot reach.
    final isGuest = ref.watch(authProvider.select((s) => s.isGuest));

    return OdysseyScaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.authPadding,
                AppSizes.contentTop,
                AppSizes.authPadding,
                AppSizes.scrollBottom,
              ),
              children: [
                Text(
                  'Where to\nnext?',
                  style: AppTypography.screenTitle.copyWith(
                    fontSize: 38,
                    letterSpacing: -1.71,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: AppSizes.space12),
                Text(
                  'Name the trip and pick the dates. The plan, the packing '
                  'list and the photos all hang off it.',
                  style: AppTypography.body.copyWith(color: t.ink2),
                ),
                const SizedBox(height: AppSizes.space26),

                FieldCard(
                  label: 'Destination',
                  controller: _destinationController,
                  hint: 'Lisbon',
                  enabled: !isBusy,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSizes.space12),

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
                const SizedBox(height: AppSizes.space12),
                Text(
                  'Already been? Pick the dates you went and keep it as a '
                  'journal.',
                  style: AppTypography.caption.copyWith(color: t.ink3),
                ),
              ],
            ),
          ),

          StickyFooter(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.authPadding,
              AppSizes.space14,
              AppSizes.authPadding,
              AppSizes.space20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PillButton(
                  label: 'Create my trip',
                  style: PillStyle.brand,
                  isLoading: _busy == _Exit.firstTrip,
                  onPressed: isBusy || !_canCreate
                      ? null
                      : () => _leave(_Exit.firstTrip),
                ),
                const SizedBox(height: AppSizes.space8),
                // Wraps rather than overflowing on a narrow phone or with a
                // large text scale.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    if (!isGuest)
                      _QuietLink(
                        label: _busy == _Exit.sampleTrips
                            ? 'Adding samples…'
                            : 'Show me sample trips',
                        onTap: isBusy ? null : () => _leave(_Exit.sampleTrips),
                      ),
                    _QuietLink(
                      label: 'Skip for now',
                      onTap: isBusy ? null : () => _leave(_Exit.skipped),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A secondary text action, styled like the sign-in screen's "Forgot
/// password?".
class _QuietLink extends StatelessWidget {
  const _QuietLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusChipXs),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space8,
          vertical: AppSizes.space10,
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: onTap == null ? t.ink3 : t.ink2,
          ),
        ),
      ),
    );
  }
}
