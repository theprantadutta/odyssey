import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'logger_service.dart';

/// Installer package names that mean the app came from a public store.
///
/// Anything else - adb (`com.android.shell`), a file manager or the system
/// package installer, no installer at all, TestFlight, an Xcode run or the
/// simulator - is an install a real user would not have.
const Set<String> storeInstallers = {
  'com.android.vending', // Google Play
  'com.apple', // App Store (package_info_plus reports this for store receipts)
};

/// User property values derived from how the app was installed.
@immutable
class InstallSourceTags {
  const InstallSourceTags({
    required this.installSource,
    required this.internalTester,
  });

  /// Value for the `install_source` user property.
  final String installSource;

  /// Whether the install should be tagged `internal_tester` = 'true'.
  ///
  /// Never used to write 'false' or clear the property: the account-based tag
  /// set at sign-in must not be overwritten from here.
  final bool internalTester;

  @override
  bool operator ==(Object other) =>
      other is InstallSourceTags &&
      other.installSource == installSource &&
      other.internalTester == internalTester;

  @override
  int get hashCode => Object.hash(installSource, internalTester);

  @override
  String toString() =>
      'InstallSourceTags(installSource: $installSource, internalTester: $internalTester)';
}

/// GA4 caps user property values at 36 characters.
const int _maxUserPropertyValueLength = 36;

/// Maps the installer reported by the platform and the build mode to the
/// user property values. Pure, so it can be tested without a device.
InstallSourceTags installSourceTagsFor({
  required String? installerStore,
  required bool isNonReleaseBuild,
}) {
  final installer = installerStore?.trim();
  final source = (installer == null || installer.isEmpty) ? 'none' : installer;
  final fromStore = storeInstallers.contains(source);
  return InstallSourceTags(
    installSource: source.length > _maxUserPropertyValueLength
        ? source.substring(0, _maxUserPropertyValueLength)
        : source,
    internalTester: isNonReleaseBuild || !fromStore,
  );
}

/// Tags every install with where it came from, so production reports can
/// leave out the developer's sideloaded and debug builds.
///
/// Sets `install_source` to the installer package (`com.android.vending` for
/// Play, `com.apple` for the App Store, `com.apple.testflight`, `none` for adb
/// on older Android, ...) and `internal_tester` = 'true' for non-store installs
/// and debug/profile builds. See internal_testers.dart for filtering.
///
/// Only touches user properties; whether anything is sent is still decided by
/// the analytics collection setting (disabled in debug by analyticsService).
/// Never throws.
Future<void> tagInstallSource() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  try {
    final info = await PackageInfo.fromPlatform();
    final tags = installSourceTagsFor(
      installerStore: info.installerStore,
      isNonReleaseBuild: kDebugMode || kProfileMode,
    );
    final analytics = FirebaseAnalytics.instance;
    await analytics.setUserProperty(
      name: 'install_source',
      value: tags.installSource,
    );
    if (tags.internalTester) {
      await analytics.setUserProperty(name: 'internal_tester', value: 'true');
    }
    AppLogger.info('Install source tagged: $tags');
  } catch (e) {
    AppLogger.warning('Could not tag install source: $e');
  }
}
