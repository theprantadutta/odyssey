import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:odyssey/src/common/theme/app_colors.dart';
import 'package:odyssey/src/common/theme/app_sizes.dart';
import 'package:odyssey/src/features/sharing/data/models/trip_share_model.dart';
import 'package:odyssey/src/features/sharing/presentation/providers/sharing_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AcceptInviteScreen extends ConsumerWidget {
  final String inviteCode;

  const AcceptInviteScreen({
    super.key,
    required this.inviteCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteState = ref.watch(inviteProvider(inviteCode));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Invitation'),
      ),
      body: _buildContent(context, ref, inviteState, theme),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    InviteState state,
    ThemeData theme,
  ) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSizes.space16),
            Text('Loading invitation...'),
          ],
        ),
      );
    }

    if (state.error != null) {
      return _ErrorState(error: state.error!);
    }

    final invite = state.invite;
    if (invite == null) {
      return const _ErrorState(error: 'Invitation not found');
    }

    if (invite.isExpired) {
      return const _ExpiredInviteState();
    }

    if (invite.alreadyAccepted) {
      return _AlreadyAcceptedState(
        tripId: invite.tripId,
        tripTitle: invite.tripTitle,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.space24),
      child: Column(
        children: [
          // Trip card
          _InviteTripCard(invite: invite),
          const SizedBox(height: AppSizes.space24),

          // Action buttons
          _ActionButtons(
            inviteCode: inviteCode,
            isAccepting: state.isAccepting,
            isDeclining: state.isDeclining,
          ),
        ],
      ),
    );
  }
}

class _InviteTripCard extends StatelessWidget {
  final InviteDetailsModel invite;

  const _InviteTripCard({required this.invite});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Cover image
          if (invite.tripCoverImageUrl != null)
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: invite.tripCoverImageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.oceanTeal.withValues(alpha: 0.1),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.oceanTeal.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 48,
                    color: AppColors.oceanTeal,
                  ),
                ),
              ),
            )
          else
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.oceanTeal.withValues(alpha: 0.4),
                    AppColors.lavenderDream.withValues(alpha: 0.4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.flight_takeoff,
                size: 64,
                color: Colors.white,
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(AppSizes.space20),
            child: Column(
              children: [
                // Invitation message
                Container(
                  padding: const EdgeInsets.all(AppSizes.space12),
                  decoration: BoxDecoration(
                    color: AppColors.oceanTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.mail_outline,
                        color: AppColors.oceanTeal,
                      ),
                      const SizedBox(width: AppSizes.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You\'ve been invited!',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${invite.ownerEmail} wants to share a trip with you',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.space20),

                // Trip title
                Text(
                  invite.tripTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (invite.tripDescription != null) ...[
                  const SizedBox(height: AppSizes.space8),
                  Text(
                    invite.tripDescription!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: AppSizes.space16),

                // Permission badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space12,
                    vertical: AppSizes.space8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderDream.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        invite.permission == SharePermission.view
                            ? Icons.visibility_outlined
                            : Icons.edit_outlined,
                        size: 18,
                        color: AppColors.lavenderDream,
                      ),
                      const SizedBox(width: AppSizes.space8),
                      Text(
                        invite.permission == SharePermission.view
                            ? 'View access'
                            : 'Edit access',
                        style: const TextStyle(
                          color: AppColors.lavenderDream,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  final String inviteCode;
  final bool isAccepting;
  final bool isDeclining;

  const _ActionButtons({
    required this.inviteCode,
    required this.isAccepting,
    required this.isDeclining,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProcessing = isAccepting || isDeclining;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isProcessing ? null : () => _acceptInvite(context, ref),
            icon: isAccepting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(isAccepting ? 'Accepting...' : 'Accept Invitation'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: AppSizes.space16),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.space12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isProcessing ? null : () => _declineInvite(context, ref),
            icon: isDeclining
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.close),
            label: Text(isDeclining ? 'Declining...' : 'Decline'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: AppSizes.space16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _acceptInvite(BuildContext context, WidgetRef ref) async {
    final response = await ref
        .read(inviteProvider(inviteCode).notifier)
        .acceptInvite();

    if (response != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined "${response.tripTitle}"!'),
          backgroundColor: AppColors.success,
        ),
      );
      // Navigate to the trip
      context.go('/trips/${response.tripId}');
    }
  }

  Future<void> _declineInvite(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Invitation'),
        content: const Text(
          'Are you sure you want to decline this invitation? The person who invited you will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(inviteProvider(inviteCode).notifier)
          .declineInvite();

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation declined'),
          ),
        );
        context.pop();
      }
    }
  }
}

class _ErrorState extends StatelessWidget {
  final String error;

  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.space20),
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              'Invalid Invitation',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiredInviteState extends StatelessWidget {
  const _ExpiredInviteState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.space20),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule,
                size: 48,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              'Invitation Expired',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'This invitation has expired. Please ask the trip owner to send you a new invitation.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlreadyAcceptedState extends StatelessWidget {
  final String tripId;
  final String tripTitle;

  const _AlreadyAcceptedState({
    required this.tripId,
    required this.tripTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.space20),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 48,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              'Already Accepted',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'You\'ve already joined "$tripTitle"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            FilledButton.icon(
              onPressed: () => context.go('/trips/$tripId'),
              icon: const Icon(Icons.flight_takeoff),
              label: const Text('View Trip'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.oceanTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
