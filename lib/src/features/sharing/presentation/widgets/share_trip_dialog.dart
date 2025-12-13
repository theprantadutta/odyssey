import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odyssey/src/common/theme/app_colors.dart';
import 'package:odyssey/src/common/theme/app_sizes.dart';
import 'package:odyssey/src/features/sharing/data/models/trip_share_model.dart';
import 'package:odyssey/src/features/sharing/presentation/providers/sharing_provider.dart';

class ShareTripDialog extends ConsumerStatefulWidget {
  final String tripId;
  final String tripTitle;

  const ShareTripDialog({
    super.key,
    required this.tripId,
    required this.tripTitle,
  });

  @override
  ConsumerState<ShareTripDialog> createState() => _ShareTripDialogState();
}

class _ShareTripDialogState extends ConsumerState<ShareTripDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  SharePermission _selectedPermission = SharePermission.view;
  bool _isSharing = false;
  String? _lastInviteCode;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _shareTrip() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSharing = true);

    final request = TripShareRequest(
      email: _emailController.text.trim(),
      permission: _selectedPermission,
    );

    final share = await ref
        .read(tripSharesProvider(widget.tripId).notifier)
        .shareTrip(request);

    setState(() => _isSharing = false);

    if (share != null && mounted) {
      setState(() => _lastInviteCode = share.inviteCode);
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite sent to ${share.sharedWithEmail}'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _copyInviteLink() {
    if (_lastInviteCode == null) return;
    // In a real app, this would be the actual deep link
    final link = 'https://odyssey.app/invite/$_lastInviteCode';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied to clipboard'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sharesState = ref.watch(tripSharesProvider(widget.tripId));

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(AppSizes.space20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.space12),
                  decoration: BoxDecoration(
                    color: AppColors.oceanTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: const Icon(
                    Icons.share_outlined,
                    color: AppColors.oceanTeal,
                  ),
                ),
                const SizedBox(width: AppSizes.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Trip',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.tripTitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space20),

            // Share form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email address',
                      hintText: 'Enter email to share with',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.space16),

                  // Permission selector
                  Text(
                    'Permission',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space8),
                  Row(
                    children: SharePermission.values.map((permission) {
                      final isSelected = _selectedPermission == permission;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: permission != SharePermission.values.last
                                ? AppSizes.space8
                                : 0,
                          ),
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedPermission = permission),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMd),
                            child: Container(
                              padding:
                                  const EdgeInsets.all(AppSizes.space12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.oceanTeal.withValues(alpha: 0.1)
                                    : null,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.oceanTeal
                                      : AppColors.mutedGray,
                                ),
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radiusMd),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    permission == SharePermission.view
                                        ? Icons.visibility_outlined
                                        : Icons.edit_outlined,
                                    color: isSelected
                                        ? AppColors.oceanTeal
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: AppSizes.space4),
                                  Text(
                                    permission.displayName,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isSelected
                                          ? AppColors.oceanTeal
                                          : AppColors.textSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSizes.space16),

                  // Share button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSharing ? null : _shareTrip,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Text(_isSharing ? 'Sharing...' : 'Send Invite'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.oceanTeal,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.space12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Last invite link
            if (_lastInviteCode != null) ...[
              const SizedBox(height: AppSizes.space16),
              Container(
                padding: const EdgeInsets.all(AppSizes.space12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: AppSizes.space8),
                    Expanded(
                      child: Text(
                        'Invite created! Copy link to share.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        size: 20,
                        color: AppColors.success,
                      ),
                      onPressed: _copyInviteLink,
                      tooltip: 'Copy invite link',
                    ),
                  ],
                ),
              ),
            ],

            // Current shares
            if (sharesState.shares.isNotEmpty) ...[
              const SizedBox(height: AppSizes.space20),
              const Divider(),
              const SizedBox(height: AppSizes.space12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Shared with',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Navigate to manage shares screen
                      Navigator.of(context).pushNamed(
                        '/trips/${widget.tripId}/shares',
                      );
                    },
                    child: const Text('Manage'),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space8),
              ...sharesState.shares.take(3).map((share) => _ShareListTile(
                    share: share,
                  )),
              if (sharesState.shares.length > 3)
                Text(
                  '+${sharesState.shares.length - 3} more',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShareListTile extends StatelessWidget {
  final TripShareModel share;

  const _ShareListTile({required this.share});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.space8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.oceanTeal.withValues(alpha: 0.1),
            child: Text(
              share.sharedWithEmail[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.oceanTeal,
                fontWeight: FontWeight.bold,
                fontSize: 12,
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
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    _StatusBadge(status: share.status),
                    const SizedBox(width: AppSizes.space4),
                    Text(
                      share.permission.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
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

class _StatusBadge extends StatelessWidget {
  final ShareStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ShareStatus.pending:
        color = AppColors.warning;
        break;
      case ShareStatus.accepted:
        color = AppColors.success;
        break;
      case ShareStatus.declined:
        color = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
