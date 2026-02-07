import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/connectivity_provider.dart';

/// Slim banner shown at the top of the screen when the app is offline
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);

    if (isOnline) return const SizedBox.shrink();

    return MaterialBanner(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      content: const Text(
        "You're offline. Changes will sync when connected.",
        style: TextStyle(fontSize: 13),
      ),
      leading: const Icon(Icons.cloud_off, size: 20),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      actions: const [SizedBox.shrink()],
    );
  }
}
