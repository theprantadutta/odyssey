import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/app_router.dart';
import '../../data/models/trip_share_model.dart';
import '../providers/sharing_provider.dart';

/// An invitation to someone else's trip, opened from a link or a
/// notification.
class AcceptInviteScreen extends ConsumerWidget {
  const AcceptInviteScreen({super.key, required this.inviteCode});

  final String inviteCode;

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final response = await ref
        .read(inviteProvider(inviteCode).notifier)
        .acceptInvite();

    if (response == null || !context.mounted) return;
    showOdysseyMessage(context, 'You are in — "${response.tripTitle}".');
    context.go('${AppRoutes.tripDetail}/${response.tripId}');
  }

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Decline invitation',
      body: const [
        'The person who invited you will be told. You can always be invited '
            'again later.',
      ],
      confirmLabel: 'Decline',
      cancelLabel: 'Keep it',
    );
    if (!confirmed || !context.mounted) return;

    final ok = await ref
        .read(inviteProvider(inviteCode).notifier)
        .declineInvite();

    if (ok && context.mounted) {
      showOdysseyMessage(context, 'Invitation declined.');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.odyssey;
    final state = ref.watch(inviteProvider(inviteCode));
    final invite = state.invite;

    return OdysseyScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.authPadding,
          AppSizes.contentTop,
          AppSizes.authPadding,
          AppSizes.scrollBottom,
        ),
        children: [
          ScreenHeader(onBack: () => context.pop()),
          const SizedBox(height: AppSizes.space20),

          if (state.isLoading)
            const Column(
              children: [
                Skeleton(
                  width: double.infinity,
                  height: 220,
                  radius: AppSizes.radiusHero,
                ),
                SizedBox(height: AppSizes.space12),
                Skeleton.row(),
              ],
            )
          else if (state.error != null)
            OdysseyErrorState(message: state.error!)
          else if (invite == null)
            const OdysseyEmptyState(
              message: 'That invitation could not be found. The link may have '
                  'been used already.',
            )
          else if (invite.isExpired)
            _Outcome(
              eyebrow: 'Expired',
              title: 'This one ran out',
              body: 'Invitations do not last forever. Ask '
                  '${invite.ownerEmail} to send another.',
            )
          else if (invite.alreadyAccepted)
            _Outcome(
              eyebrow: 'Already yours',
              title: invite.tripTitle,
              body: 'You have already joined this trip.',
              actionLabel: 'Open the trip',
              onAction: () =>
                  context.go('${AppRoutes.tripDetail}/${invite.tripId}'),
            )
          else ...[
            _InviteCard(invite: invite),
            const SizedBox(height: AppSizes.space18),
            Text(
              '${invite.ownerEmail} wants you along.',
              style: AppTypography.body.copyWith(color: t.ink2),
            ),
            if (invite.expiresAt != null) ...[
              const SizedBox(height: AppSizes.space8),
              Text(
                'Expires ${TripFormat.longDate(invite.expiresAt)}',
                style: AppTypography.rowMeta.copyWith(color: t.ink3),
              ),
            ],
            const SizedBox(height: AppSizes.space24),
            PillButton(
              label: 'Join the trip',
              style: PillStyle.brand,
              isLoading: state.isAccepting,
              onPressed: state.isAccepting || state.isDeclining
                  ? null
                  : () => _accept(context, ref),
            ),
            const SizedBox(height: AppSizes.space10),
            PillButton(
              label: 'Decline',
              style: PillStyle.outline,
              isLoading: state.isDeclining,
              onPressed: state.isAccepting || state.isDeclining
                  ? null
                  : () => _decline(context, ref),
              padding: const EdgeInsets.symmetric(vertical: AppSizes.space16),
            ),
          ],
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.invite});

  final InviteDetailsModel invite;

  @override
  Widget build(BuildContext context) {
    return PhotoSurface(
      imageUrl: invite.tripCoverImageUrl,
      seed: invite.tripId,
      height: 260,
      radius: AppSizes.radiusHero,
      child: Stack(
        children: [
          Positioned(
            right: AppSizes.space16,
            top: AppSizes.space16,
            child: PhotoPill(
              label: invite.permission.displayName,
              showDot: false,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.space20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EyebrowLabel(
                    'Invitation',
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: AppSizes.space10),
                  Text(
                    invite.tripTitle,
                    style: AppTypography.heroPlace.copyWith(
                      color: AppColors.onPhoto,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (invite.tripDescription != null &&
                      invite.tripDescription!.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.space8),
                    Text(
                      invite.tripDescription!,
                      style: AppTypography.metaLarge.copyWith(
                        color: AppColors.onPhoto2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An expired or already-accepted invitation. There is no failure colour
/// here, so the outcome is carried entirely by what it says.
class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.eyebrow,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String eyebrow;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return OdysseyCard(
      radius: AppSizes.radiusHero,
      padding: const EdgeInsets.all(AppSizes.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          EyebrowLabel(eyebrow),
          const SizedBox(height: AppSizes.space12),
          Text(title, style: AppTypography.statSmall.copyWith(color: t.ink)),
          const SizedBox(height: AppSizes.space10),
          Text(body, style: AppTypography.subtitle.copyWith(color: t.ink2)),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSizes.space18),
            PillButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
