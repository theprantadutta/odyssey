import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/widgets/odyssey/dialogs.dart';
import '../../../core/providers/analytics_provider.dart';
import '../../../core/router/app_router.dart';
import 'providers/auth_provider.dart';

/// What a guest is told before they start, and what the Settings reminder
/// repeats. Kept in one place so the two never drift apart.
const List<String> guestWarningBody = [
  'Everything you add stays on this phone only. It is not backed up or '
      'synced anywhere.',
  'If you delete the app, clear its data or change phones, your trips are '
      'gone for good.',
  'You can create a free account at any time, and everything you have added '
      'moves to it.',
];

/// Asks someone to confirm they want to use the app without an account.
Future<bool> confirmContinueAsGuest(BuildContext context) {
  return showOdysseyConfirm(
    context: context,
    title: 'Use Odyssey without an account?',
    body: guestWarningBody,
    confirmLabel: 'Continue without an account',
    cancelLabel: 'Back',
  );
}

/// Stops a guest at a feature that needs an account, and offers them one.
///
/// Returns true when the caller may go ahead: always for a signed-in user,
/// never for a guest. [feature] is reported to analytics; [reason] is the line
/// the guest reads, naming what the account is needed for.
Future<bool> requireAccount(
  BuildContext context,
  WidgetRef ref, {
  required String feature,
  required String reason,
}) async {
  if (!ref.read(authProvider).isGuest) return true;

  ref.read(analyticsServiceProvider).trackAccountPromptShown(feature: feature);
  final router = GoRouter.of(context);
  final wantsAccount = await showOdysseyConfirm(
    context: context,
    title: 'Create a free account',
    body: [
      reason,
      'Everything you have added on this phone comes with you.',
    ],
    confirmLabel: 'Create account',
    cancelLabel: 'Not now',
  );
  // Pushed rather than gone to, so the register screen has a way back.
  if (wantsAccount) router.push(AppRoutes.register);
  return false;
}
