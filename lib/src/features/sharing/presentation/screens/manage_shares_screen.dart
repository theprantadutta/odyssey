import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odyssey/src/common/theme/app_colors.dart';
import 'package:odyssey/src/common/theme/app_sizes.dart';
import 'package:odyssey/src/features/sharing/data/models/trip_share_model.dart';
import 'package:odyssey/src/features/sharing/presentation/providers/sharing_provider.dart';
import 'package:odyssey/src/features/sharing/presentation/widgets/collaboration_indicator.dart';
import 'package:odyssey/src/features/sharing/presentation/widgets/share_trip_dialog.dart';

class ManageSharesScreen extends ConsumerWidget {
  final String tripId;
  final String tripTitle;

  const ManageSharesScreen({
    super.key,
    required this.tripId,
    required this.tripTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharesState = ref.watch(tripSharesProvider(tripId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Sharing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(tripSharesProvider(tripId).notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(tripSharesProvider(tripId).notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trip info
              _TripInfoCard(title: tripTitle),
              const SizedBox(height: AppSizes.space24),

              // Share button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showShareDialog(context),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Share Trip'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.oceanTeal,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.space16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.space24),

              // Shares by status
              if (sharesState.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (sharesState.shares.isEmpty)
                const _NoCollaboratorsYet()
              else ...[
                // Accepted shares
                if (sharesState.acceptedShares.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Active Collaborators',
                    count: sharesState.acceptedShares.length,
                  ),
                  const SizedBox(height: AppSizes.space8),
                  ...sharesState.acceptedShares.map(
                    (share) => CollaboratorTile(
                      tripId: tripId,
                      share: share,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space16),
                ],

                // Pending shares
                if (sharesState.pendingShares.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Pending Invites',
                    count: sharesState.pendingShares.length,
                  ),
                  const SizedBox(height: AppSizes.space8),
                  ...sharesState.pendingShares.map(
                    (share) => _PendingShareTile(
                      tripId: tripId,
                      share: share,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space16),
                ],

                // Declined shares
                if (sharesState.declinedShares.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Declined',
                    count: sharesState.declinedShares.length,
                  ),
                  const SizedBox(height: AppSizes.space8),
                  ...sharesState.declinedShares.map(
                    (share) => CollaboratorTile(
                      tripId: tripId,
                      share: share,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ShareTripDialog(
        tripId: tripId,
        tripTitle: tripTitle,
      ),
    );
  }
}

class _TripInfoCard extends StatelessWidget {
  final String title;

  const _TripInfoCard({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        color: AppColors.oceanTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: AppColors.oceanTeal.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.space12),
            decoration: BoxDecoration(
              color: AppColors.oceanTeal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: const Icon(
              Icons.flight_takeoff,
              color: AppColors.oceanTeal,
            ),
          ),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Managing sharing for',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppSizes.space8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space8,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingShareTile extends ConsumerWidget {
  final String tripId;
  final TripShareModel share;

  const _PendingShareTile({
    required this.tripId,
    required this.share,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.space8),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.warning.withValues(alpha: 0.1),
              child: Text(
                share.sharedWithEmail[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    share.sharedWithEmail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 12,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Waiting for response',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: 'Copy invite link',
              onPressed: () {
                final link =
                    'https://odyssey.app/invite/${share.inviteCode}';
                Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invite link copied'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.close,
                size: 20,
                color: AppColors.error,
              ),
              tooltip: 'Cancel invite',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cancel Invite'),
                    content: Text(
                      'Cancel the invite for ${share.sharedWithEmail}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Keep'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                        child: const Text('Cancel Invite'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await ref
                      .read(tripSharesProvider(tripId).notifier)
                      .revokeShare(share.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NoCollaboratorsYet extends StatelessWidget {
  const _NoCollaboratorsYet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.space32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.space16),
              decoration: BoxDecoration(
                color: AppColors.oceanTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 48,
                color: AppColors.oceanTeal,
              ),
            ),
            const SizedBox(height: AppSizes.space16),
            Text(
              'No collaborators yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'Share this trip with friends and family\nto plan together',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
