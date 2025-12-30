import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odyssey/src/common/theme/app_colors.dart';
import 'package:odyssey/src/common/theme/app_sizes.dart';
import 'package:odyssey/src/features/sharing/data/models/trip_share_model.dart';
import 'package:odyssey/src/features/sharing/presentation/providers/sharing_provider.dart';

/// Small indicator showing number of collaborators
class CollaborationIndicator extends ConsumerWidget {
  final String tripId;
  final VoidCallback? onTap;

  const CollaborationIndicator({
    super.key,
    required this.tripId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharesState = ref.watch(tripSharesProvider(tripId));
    final acceptedCount = sharesState.acceptedShares.length;

    if (acceptedCount == 0) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space8,
          vertical: AppSizes.space4,
        ),
        decoration: BoxDecoration(
          color: AppColors.oceanTeal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_outline,
              size: 16,
              color: AppColors.oceanTeal,
            ),
            const SizedBox(width: AppSizes.space4),
            Text(
              '$acceptedCount',
              style: const TextStyle(
                color: AppColors.oceanTeal,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact avatar stack for collaborators
class CollaboratorAvatars extends ConsumerWidget {
  final String tripId;
  final int maxAvatars;
  final double avatarSize;
  final VoidCallback? onTap;

  const CollaboratorAvatars({
    super.key,
    required this.tripId,
    this.maxAvatars = 3,
    this.avatarSize = 28,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharesState = ref.watch(tripSharesProvider(tripId));
    final acceptedShares = sharesState.acceptedShares;

    if (acceptedShares.isEmpty) return const SizedBox.shrink();

    final displayShares = acceptedShares.take(maxAvatars).toList();
    final overflowCount = acceptedShares.length - maxAvatars;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(avatarSize),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: avatarSize +
                (displayShares.length - 1) * (avatarSize * 0.6) +
                (overflowCount > 0 ? avatarSize * 0.6 : 0),
            height: avatarSize,
            child: Stack(
              children: [
                ...displayShares.asMap().entries.map((entry) {
                  final index = entry.key;
                  final share = entry.value;
                  return Positioned(
                    left: index * (avatarSize * 0.6),
                    child: _CollaboratorAvatar(
                      email: share.sharedWithEmail,
                      size: avatarSize,
                      permission: share.permission,
                    ),
                  );
                }),
                if (overflowCount > 0)
                  Positioned(
                    left: displayShares.length * (avatarSize * 0.6),
                    child: _OverflowAvatar(
                      count: overflowCount,
                      size: avatarSize,
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

class _CollaboratorAvatar extends StatelessWidget {
  final String email;
  final double size;
  final SharePermission permission;

  const _CollaboratorAvatar({
    required this.email,
    required this.size,
    required this.permission,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.oceanTeal,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          email[0].toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}

class _OverflowAvatar extends StatelessWidget {
  final int count;
  final double size;

  const _OverflowAvatar({
    required this.count,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.textSecondary,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.35,
          ),
        ),
      ),
    );
  }
}

/// Detailed collaborator list for manage shares screen
class CollaboratorList extends ConsumerWidget {
  final String tripId;
  final bool showActions;

  const CollaboratorList({
    super.key,
    required this.tripId,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharesState = ref.watch(tripSharesProvider(tripId));

    if (sharesState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (sharesState.shares.isEmpty) {
      return const _NoCollaboratorsState();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sharesState.shares.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final share = sharesState.shares[index];
        return CollaboratorTile(
          tripId: tripId,
          share: share,
          showActions: showActions,
        );
      },
    );
  }
}

class CollaboratorTile extends ConsumerWidget {
  final String tripId;
  final TripShareModel share;
  final bool showActions;

  const CollaboratorTile({
    super.key,
    required this.tripId,
    required this.share,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _CollaboratorAvatar(
        email: share.sharedWithEmail,
        size: 40,
        permission: share.permission,
      ),
      title: Text(share.sharedWithEmail),
      subtitle: Row(
        children: [
          _StatusChip(status: share.status),
          const SizedBox(width: AppSizes.space8),
          _PermissionChip(permission: share.permission),
        ],
      ),
      trailing: showActions
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                final notifier =
                    ref.read(tripSharesProvider(tripId).notifier);
                switch (value) {
                  case 'view':
                    await notifier.updatePermission(
                        share.id, SharePermission.view);
                    break;
                  case 'edit':
                    await notifier.updatePermission(
                        share.id, SharePermission.edit);
                    break;
                  case 'revoke':
                    final confirmed = await _showRevokeConfirmation(context);
                    if (confirmed) {
                      await notifier.revokeShare(share.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Access revoked'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view',
                  enabled: share.permission != SharePermission.view,
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 20,
                        color: share.permission == SharePermission.view
                            ? AppColors.oceanTeal
                            : null,
                      ),
                      const SizedBox(width: AppSizes.space8),
                      const Text('View Only'),
                      if (share.permission == SharePermission.view) ...[
                        const Spacer(),
                        const Icon(Icons.check,
                            size: 16, color: AppColors.oceanTeal),
                      ],
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  enabled: share.permission != SharePermission.edit,
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: share.permission == SharePermission.edit
                            ? AppColors.oceanTeal
                            : null,
                      ),
                      const SizedBox(width: AppSizes.space8),
                      const Text('Can Edit'),
                      if (share.permission == SharePermission.edit) ...[
                        const Spacer(),
                        const Icon(Icons.check,
                            size: 16, color: AppColors.oceanTeal),
                      ],
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'revoke',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_outlined,
                          size: 20, color: AppColors.error),
                      SizedBox(width: AppSizes.space8),
                      Text('Remove Access',
                          style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Future<bool> _showRevokeConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Access'),
            content: Text(
              'Are you sure you want to remove ${share.sharedWithEmail}\'s access to this trip?',
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
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _StatusChip extends StatelessWidget {
  final ShareStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (status) {
      case ShareStatus.pending:
        color = AppColors.warning;
        icon = Icons.schedule;
        break;
      case ShareStatus.accepted:
        color = AppColors.success;
        icon = Icons.check_circle;
        break;
      case ShareStatus.declined:
        color = AppColors.error;
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  final SharePermission permission;

  const _PermissionChip({required this.permission});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.lavenderDream.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            permission == SharePermission.view
                ? Icons.visibility_outlined
                : Icons.edit_outlined,
            size: 12,
            color: AppColors.lavenderDream,
          ),
          const SizedBox(width: 4),
          Text(
            permission.displayName,
            style: const TextStyle(
              color: AppColors.lavenderDream,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoCollaboratorsState extends StatelessWidget {
  const _NoCollaboratorsState();

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
              'Share this trip with friends and family to plan together',
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
