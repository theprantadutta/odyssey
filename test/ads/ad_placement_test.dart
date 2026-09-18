import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/router/task_routes.dart';
import 'package:odyssey/src/features/ads/ad_constants.dart';
import 'package:odyssey/src/features/ads/native_ad_slots.dart';

/// Builds a throwaway route carrying [name] so the observer's filters can be
/// exercised without a Navigator.
PageRoute<void> _route(String? name, {bool fullscreenDialog = false}) {
  return PageRouteBuilder<void>(
    settings: RouteSettings(name: name),
    fullscreenDialog: fullscreenDialog,
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}

void main() {
  group('NativeAdSlots', () {
    test('allocates no slots below the minimum item count', () {
      final slots = NativeAdSlots(AdConstants.nativeAdMinItemsBeforeFirst - 1);
      expect(slots.adCount, 0);
      expect(slots.totalCount, AdConstants.nativeAdMinItemsBeforeFirst - 1);
      expect(slots.isAdAt(0), isFalse);
    });

    test('maps every interleaved index back to a distinct real item', () {
      const realCount = 40;
      final slots = NativeAdSlots(realCount);

      final realIndices = <int>[];
      for (var i = 0; i < slots.totalCount; i++) {
        if (!slots.isAdAt(i)) realIndices.add(slots.realIndexAt(i));
      }

      // Every real item is rendered exactly once, in order, with no index ever
      // running past the end of the backing list.
      expect(realIndices, List<int>.generate(realCount, (i) => i));
    });

    test('spaces ads by the configured interval', () {
      final slots = NativeAdSlots(40);
      final adIndices = <int>[
        for (var i = 0; i < slots.totalCount; i++)
          if (slots.isAdAt(i)) i,
      ];

      expect(adIndices, isNotEmpty);
      for (var i = 1; i < adIndices.length; i++) {
        expect(
          adIndices[i] - adIndices[i - 1],
          AdConstants.nativeAdEveryNItems + 1,
        );
      }
    });

    test('honours the native format kill switch', () {
      final slots = NativeAdSlots(1000);
      expect(slots.adCount, AdConstants.nativeEnabled ? greaterThan(0) : 0);
    });
  });

  group('TaskRoutes.isTaskRoute', () {
    test('flags imperatively-pushed task screens', () {
      for (final name in TaskRoutes.all) {
        expect(_route(name), predicate<Route<dynamic>>(TaskRoutes.isTaskRoute),
            reason: '$name should be treated as a task route');
      }
    });

    test('flags GoRouter trip-form paths by pattern', () {
      expect(TaskRoutes.isTaskRoute(_route('/create-trip')), isTrue);
      expect(TaskRoutes.isTaskRoute(_route('/edit-trip/:id')), isTrue);
    });

    test('leaves browse destinations countable', () {
      for (final name in <String?>['/', '/templates', '/achievements', null]) {
        expect(TaskRoutes.isTaskRoute(_route(name)), isFalse,
            reason: '$name should still count toward the ad cadence');
      }
    });
  });

  group('quiet-launch ad profile', () {
    test('full-screen formats are off', () {
      expect(AdConstants.interstitialEnabled, isFalse);
      expect(AdConstants.appOpenEnabled, isFalse);
    });

    test('cadence divisors are safe', () {
      // Both are used as `% n` divisors; zero would throw at runtime.
      expect(AdConstants.interstitialEveryNNavigations, greaterThanOrEqualTo(1));
      expect(AdConstants.nativeAdEveryNItems, greaterThanOrEqualTo(1));
    });

    test('new users get an ad-free window', () {
      expect(AdConstants.newUserGracePeriod, greaterThan(Duration.zero));
    });
  });
}
