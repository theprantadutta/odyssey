import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/services/install_source_tagger.dart';

void main() {
  group('installSourceTagsFor', () {
    test('Play release install is a real user', () {
      expect(
        installSourceTagsFor(
          installerStore: 'com.android.vending',
          isNonReleaseBuild: false,
        ),
        const InstallSourceTags(
          installSource: 'com.android.vending',
          internalTester: false,
        ),
      );
    });

    test('App Store release install is a real user', () {
      final tags = installSourceTagsFor(
        installerStore: 'com.apple',
        isNonReleaseBuild: false,
      );
      expect(tags.installSource, 'com.apple');
      expect(tags.internalTester, isFalse);
    });

    test('debug/profile build from Play is still a tester', () {
      final tags = installSourceTagsFor(
        installerStore: 'com.android.vending',
        isNonReleaseBuild: true,
      );
      expect(tags.installSource, 'com.android.vending');
      expect(tags.internalTester, isTrue);
    });

    test('no installer (adb on older Android) is a sideload', () {
      for (final installer in [null, '', '  ']) {
        final tags = installSourceTagsFor(
          installerStore: installer,
          isNonReleaseBuild: false,
        );
        expect(tags.installSource, 'none');
        expect(tags.internalTester, isTrue);
      }
    });

    test('adb shell, package installer, TestFlight and simulator are testers',
        () {
      for (final installer in [
        'com.android.shell',
        'com.google.android.packageinstaller',
        'com.apple.testflight',
        'com.apple.simulator',
      ]) {
        final tags = installSourceTagsFor(
          installerStore: installer,
          isNonReleaseBuild: false,
        );
        expect(tags.installSource, installer);
        expect(tags.internalTester, isTrue, reason: installer);
      }
    });

    test('long installer names are cut to the 36-char GA limit', () {
      final tags = installSourceTagsFor(
        installerStore: 'com.example.some.very.long.installer.package.name',
        isNonReleaseBuild: false,
      );
      expect(tags.installSource.length, 36);
      expect(tags.internalTester, isTrue);
    });
  });
}
