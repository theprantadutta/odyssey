import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/services/storage_service.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/feature_access_provider.dart';

/// Temporary unlocks are earned by a person, not by a device, so signing out
/// must clear them. That only works if the storage layer knows every key the
/// feature layer can write - a new reward would otherwise survive a sign-out and
/// hand the next account a premium feature it never earned.

void main() {
  test('every unlockable feature is cleared on sign-out', () {
    final featureKeys =
        PremiumFeature.values.map((f) => f.storageKey).toSet();

    expect(
      StorageService.featureUnlockKeys.toSet(),
      featureKeys,
      reason: 'add the new PremiumFeature storageKey to '
          'StorageService.featureUnlockKeys so sign-out clears it',
    );
  });

  test('the key list has no duplicates', () {
    expect(
      StorageService.featureUnlockKeys.length,
      StorageService.featureUnlockKeys.toSet().length,
    );
  });
}
