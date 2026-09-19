import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/validators.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../subscription/presentation/providers/feature_access_provider.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';
import '../../data/models/trip_share_model.dart';
import '../../data/repositories/sharing_repository.dart';
import '../providers/sharing_provider.dart';

/// Invite someone to a trip.
///
/// Presented as a full-height dialog rather than a bottom sheet because it
/// holds a form and a list of everyone already invited, and a sheet that tall
/// fights the keyboard.
class ShareTripDialog extends ConsumerStatefulWidget {
  const ShareTripDialog({
    super.key,
    required this.tripId,
    required this.tripTitle,
  });

  final String tripId;
  final String tripTitle;

  @override
  ConsumerState<ShareTripDialog> createState() => _ShareTripDialogState();
}

class _ShareTripDialogState extends ConsumerState<ShareTripDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  SharePermission _permission = SharePermission.view;
  bool _isSharing = false;
  String? _lastInviteCode;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSharing = true);

    TripShareModel? share;
    String? failure;
    try {
      share = await ref
          .read(tripSharesProvider(widget.tripId).notifier)
          .shareTrip(
            TripShareRequest(
              email: _emailController.text.trim(),
              permission: _permission,
            ),
          );
    } on OfflineInvitationException catch (e) {
      failure = e.message;
    } catch (e) {
      failure = 'Could not send the invitation. Try again.';
    }

    if (!mounted) return;
    setState(() => _isSharing = false);

    if (failure != null) {
      // Says what actually happened: nothing was sent and nothing was queued.
      showOdysseyMessage(context, failure);
      return;
    }

    if (share != null) {
      setState(() => _lastInviteCode = share!.inviteCode);
      _emailController.clear();
      showOdysseyMessage(context, 'Invite sent to ${share.sharedWithEmail}.');
    }
  }

  void _copyLink() {
    if (_lastInviteCode == null) return;
    HapticFeedback.lightImpact();
    Clipboard.setData(
      ClipboardData(text: 'https://odyssey.app/invite/$_lastInviteCode'),
    );
    showOdysseyMessage(context, 'Invite link copied.');
  }

  void _setPermission(SharePermission permission) {
    if (permission == SharePermission.edit) {
      final hasAccess = ref.read(
        featureAccessProvider(PremiumFeature.editSharing),
      );
      if (!hasAccess) {
        PaywallUtils.showPaywall(
          context,
          featureName: 'Edit Sharing',
          customDescription:
              'Let the people you travel with change the plan, not just read it.',
          featureIcon: Icons.edit,
          unlockableFeature: PremiumFeature.editSharing,
        );
        return;
      }
    }
    HapticFeedback.selectionClick();
    setState(() => _permission = permission);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final state = ref.watch(tripSharesProvider(widget.tripId));

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSizes.space20),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.space20),
        decoration: BoxDecoration(
          color: Color.alphaBlend(t.sheet, t.canvas),
          borderRadius: BorderRadius.circular(AppSizes.radiusPanel),
          border: Border.all(color: t.hairline),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: EyebrowLabel('Invite to')),
                  CircleButton(
                    glyph: '✕',
                    size: AppSizes.circleSm,
                    onPressed: () => Navigator.of(context).pop(),
                    semanticLabel: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space10),
              Text(
                widget.tripTitle,
                style: AppTypography.statSmall.copyWith(color: t.ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSizes.space20),

              FieldCard(
                label: 'Their email',
                controller: _emailController,
                hint: 'name@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                validator: Validators.email,
                onSubmitted: (_) => _share(),
              ),
              const SizedBox(height: AppSizes.space14),

              SegmentedControl(
                labels: SharePermission.values
                    .map((p) => p.displayName)
                    .toList(),
                selected: _permission.displayName,
                onSelected: (label) => _setPermission(
                  SharePermission.values.firstWhere(
                    (p) => p.displayName == label,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.space18),

              PillButton(
                label: 'Send the invite',
                isLoading: _isSharing,
                onPressed: _isSharing ? null : _share,
              ),

              if (_lastInviteCode != null) ...[
                const SizedBox(height: AppSizes.space10),
                PillButton(
                  label: 'Copy the link',
                  style: PillStyle.outline,
                  onPressed: _copyLink,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSizes.space14,
                  ),
                ),
              ],

              if (state.shares.isNotEmpty) ...[
                const SizedBox(height: AppSizes.space20),
                EyebrowLabel('Already invited · ${state.shares.length}'),
                const SizedBox(height: AppSizes.space12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.shares.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSizes.space8),
                    itemBuilder: (context, index) {
                      final share = state.shares[index];
                      final pending = state.pendingShares.contains(share);
                      return Row(
                        children: [
                          Opacity(
                            opacity: pending ? 0.55 : 1,
                            child: AvatarCircle(
                              name: share.sharedWithEmail,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: AppSizes.space10),
                          Expanded(
                            child: Text(
                              share.sharedWithEmail,
                              style: AppTypography.rowMeta.copyWith(
                                color: t.ink2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          MonoTag(
                            pending ? 'Invited' : share.permission.displayName,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
