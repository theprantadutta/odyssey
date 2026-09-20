import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:odyssey/src/common/theme/app_sizes.dart';
import 'package:odyssey/src/common/theme/app_theme.dart';
import 'package:odyssey/src/common/theme/odyssey_tokens.dart';
import 'package:odyssey/src/common/widgets/odyssey/odyssey.dart';

/// Renders the loading states on the real canvas in both themes.
///
/// These exist to be looked at. Skeletons are the one part of the interface
/// that cannot be checked by using the app - they are gone within a frame of
/// the data arriving - and the bug they are guarding against was exactly a
/// skeleton that could not be seen. Run with --update-goldens and open the
/// PNGs in test/goldens/.
void main() {
  Future<void> pumpSheet(WidgetTester tester, {required bool dark}) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: const _LoadingSampler(),
      ),
    );
    // Part-way through a sweep, so the highlight is actually in frame.
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('loading states, dark', (tester) async {
    await pumpSheet(tester, dark: true);
    await expectLater(
      find.byType(_LoadingSampler),
      matchesGoldenFile('goldens/loading-dark.png'),
    );
  });

  testWidgets('loading states, light', (tester) async {
    await pumpSheet(tester, dark: false);
    await expectLater(
      find.byType(_LoadingSampler),
      matchesGoldenFile('goldens/loading-light.png'),
    );
  });
}

/// One of each shape a skeleton takes across the app, on the page background
/// it actually sits on.
class _LoadingSampler extends StatelessWidget {
  const _LoadingSampler();

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return ColoredBox(
      color: t.canvas,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Skeleton(width: 148, height: 19),
            const SizedBox(height: AppSizes.space14),

            // The home hero.
            const Skeleton.tile(height: 210),
            const SizedBox(height: AppSizes.space18),

            // The home thumbnail strip.
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: AppSizes.space12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(
                        width: AppSizes.tripThumb,
                        height: AppSizes.tripThumb,
                        radius: AppSizes.radiusTile,
                      ),
                      SizedBox(height: AppSizes.space10),
                      Skeleton(width: 108, height: 13),
                      SizedBox(height: AppSizes.space6),
                      Skeleton(width: 68, height: 11),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSizes.space18),

            // List rows.
            const Skeleton.row(),
            const SizedBox(height: AppSizes.space12),
            const Skeleton.row(),
            const SizedBox(height: AppSizes.space18),

            // The trip detail stat row: two plain tiles and the lime one, which
            // needs its own sheen because the card tone vanishes on lime.
            const Row(
              children: [
                Expanded(
                  child: StatCard(value: '6', label: 'days', loading: true),
                ),
                SizedBox(width: AppSizes.space10),
                Expanded(
                  child: StatCard(value: '7', label: 'plans', loading: true),
                ),
                SizedBox(width: AppSizes.space10),
                Expanded(
                  child: StatCard(
                    value: '89%',
                    label: 'ready',
                    highlight: true,
                    loading: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
