import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../data/models/trip_share_model.dart';
import '../providers/sharing_provider.dart';
import '../widgets/share_trip_dialog.dart';

/// Who can see this trip, and what they can do with it.
class ManageSharesScreen extends ConsumerWidget {
  const ManageSharesScreen({
    super.key,
    required this.tripId,
    required this.tripTitle,
  });

  final String tripId;
  final String tripTitle;

  void _share(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (context) =>
          ShareTripDialog(tripId: tripId, tripTitle: tripTitle),
    );
  }

  Future<void> _changePermission(
    BuildContext context,
    WidgetRef ref,
    TripShareModel share,
  ) async {
    final picked = await showOdysseyPicker<SharePermission>(
      context: context,
      title: share.sharedWithEmail,
      options: SharePermission.values,
      labelOf: (p) => p.displayName,
      selected: share.permission,
    );
    if (picked == null || picked == share.permission) return;

    final ok = await ref
        .read(tripSharesProvider(tripId).notifier)
        .updatePermission(share.id, picked);

    if (!ok && context.mounted) {
      showOdysseyMessage(context, 'That change did not save.');
    }
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    TripShareModel share,
  ) async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Remove access',
      body: [
        '${share.sharedWithEmail} will no longer be able to open this trip.',
      ],
      confirmLabel: 'Remove access',
    );
    if (!confirmed || !context.mounted) return;

    final ok = await ref
        .read(tripSharesProvider(tripId).notifier)
        .revokeShare(share.id);

    if (!ok && context.mounted) {
      showOdysseyMessage(context, 'Could not remove that access.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.odyssey;
    final state = ref.watch(tripSharesProvider(tripId));

    return OdysseyScaffold(
      body: RefreshIndicator(
        color: t.action,
        backgroundColor: Color.alphaBlend(t.card, t.canvas),
        onRefresh: () => ref.read(tripSharesProvider(tripId).notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.contentTop,
            AppSizes.screenPadding,
            AppSizes.scrollBottom,
          ),
          children: [
            ScreenHeader(title: tripTitle, onBack: () => context.pop()),
            const SizedBox(height: AppSizes.space20),
            Text(
              'Who can\nsee this',
              style: AppTypography.screenTitle.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppSizes.space20),

            PillButton(
              label: 'Invite someone',
              icon: Icons.person_add_outlined,
              onPressed: () => _share(context),
            ),
            const SizedBox(height: AppSizes.space20),

            if (state.isLoading && state.shares.isEmpty)
              const Column(
                children: [
                  Skeleton.row(),
                  SizedBox(height: AppSizes.space10),
                  Skeleton.row(),
                ],
              )
            else if (state.error != null && state.shares.isEmpty)
              OdysseyErrorState.fromError(
                state.error,
                message: 'The people on this trip could not be loaded.',
                onRetry: () =>
                    ref.read(tripSharesProvider(tripId).notifier).refresh(),
              )
            else ...[
              if (state.acceptedShares.isNotEmpty) ...[
                EyebrowLabel(
                  'Travelling with you · ${state.acceptedShares.length}',
                ),
                const SizedBox(height: AppSizes.space12),
                for (final share in state.acceptedShares) ...[
                  _ShareRow(
                    share: share,
                    pending: false,
                    onTap: () => _changePermission(context, ref, share),
                    onRemove: () => _revoke(context, ref, share),
                  ),
                  const SizedBox(height: AppSizes.space10),
                ],
                const SizedBox(height: AppSizes.space14),
              ],

              if (state.pendingShares.isNotEmpty) ...[
                EyebrowLabel('Invited · ${state.pendingShares.length}'),
                const SizedBox(height: AppSizes.space12),
                for (final share in state.pendingShares) ...[
                  _ShareRow(
                    share: share,
                    pending: true,
                    onTap: () => _changePermission(context, ref, share),
                    onRemove: () => _revoke(context, ref, share),
                  ),
                  const SizedBox(height: AppSizes.space10),
                ],
              ],

              if (state.shares.isEmpty)
                const OdysseyEmptyState(
                  icon: Icons.group_add_outlined,
                  message: 'Only you can see this trip. Invite someone and '
                      'they can follow along.',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.share,
    required this.pending,
    required this.onTap,
    required this.onRemove,
  });

  final TripShareModel share;
  final bool pending;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    final meta = pending
        ? (share.inviteExpiresAt == null
              ? 'Waiting for a reply'
              : 'Invite expires '
                    '${TripFormat.shortDate(share.inviteExpiresAt)}')
        : 'Joined ${TripFormat.shortDate(share.acceptedAt ?? share.createdAt)}';

    return Pressable(
      onTap: onTap,
      onLongPress: onRemove,
      borderRadius: BorderRadius.circular(AppSizes.radiusRow),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusRow),
          border: Border.all(color: t.hairline),
        ),
        child: Row(
          children: [
            // A pending invite is drawn at reduced opacity rather than in a
            // warning colour, because there is no warning colour here.
            Opacity(
              opacity: pending ? 0.55 : 1,
              child: AvatarCircle(name: share.sharedWithEmail, size: 34),
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    share.sharedWithEmail,
                    style: AppTypography.rowLabel.copyWith(color: t.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: AppTypography.rowMeta.copyWith(color: t.ink3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.space10),
            MonoTag(share.permission.displayName),
            const SizedBox(width: AppSizes.space8),
            CircleButton(
              glyph: '✕',
              size: AppSizes.circleSm,
              onPressed: onRemove,
              semanticLabel: 'Remove ${share.sharedWithEmail}',
            ),
          ],
        ),
      ),
    );
  }
}
