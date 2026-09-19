import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:odyssey/src/common/theme/app_theme.dart';
import 'package:odyssey/src/common/theme/odyssey_tokens.dart';
import 'package:odyssey/src/common/widgets/odyssey/odyssey.dart';

/// Smoke coverage for the Odyssey 2.0 component library.
///
/// Not golden tests — these check that every primitive lays out and paints in
/// both themes without throwing, which is the failure mode that costs the most
/// time when it surfaces later, on a screen, in an unrelated change.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, {bool dark = true}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(20), child: child),
          ),
        ),
      ),
    );
  }

  group('tokens', () {
    test('dark resolves lime as the action colour', () {
      expect(OdysseyTokens.dark.action, const Color(0xFFD6FF3D));
      expect(OdysseyTokens.dark.onAction, const Color(0xFF0A0B0D));
      expect(OdysseyTokens.dark.actionGlyph, const Color(0xFF0A0B0D));
    });

    test('light inverts to ink, with lime as the inner glyph', () {
      expect(OdysseyTokens.light.action, const Color(0xFF0A0B0D));
      expect(OdysseyTokens.light.onAction, const Color(0xFFF2F2EF));
      expect(OdysseyTokens.light.actionGlyph, const Color(0xFFD6FF3D));
    });

    test('hero tiles stay lime in both themes', () {
      expect(OdysseyTokens.dark.heroTile, OdysseyTokens.light.heroTile);
      expect(OdysseyTokens.dark.onHeroTile, OdysseyTokens.light.onHeroTile);
    });

    test('lime never appears as body text on paper', () {
      expect(OdysseyTokens.light.limeText, const Color(0xFF5C7A00));
      expect(OdysseyTokens.dark.limeText, const Color(0xFFD6FF3D));
    });

    test('both themes carry the token extension', () {
      expect(AppTheme.darkTheme.extension<OdysseyTokens>(), isNotNull);
      expect(AppTheme.lightTheme.extension<OdysseyTokens>(), isNotNull);
    });

    test('the data ramp has four tones and wraps', () {
      expect(OdysseyTokens.dark.ramp, hasLength(4));
      expect(OdysseyTokens.light.ramp, hasLength(4));
      expect(OdysseyTokens.dark.rampAt(5), OdysseyTokens.dark.ramp[1]);
    });

    test('lerp interpolates between the two themes', () {
      final mid = OdysseyTokens.dark.lerp(OdysseyTokens.light, 0.5);
      expect(mid.ramp, hasLength(4));
      expect(mid.canvas, isNot(OdysseyTokens.dark.canvas));
    });
  });

  for (final dark in [true, false]) {
    final label = dark ? 'dark' : 'light';

    testWidgets('buttons render in $label', (tester) async {
      await pump(
        tester,
        Column(
          children: [
            PillButton(label: 'Create account', onPressed: () {}),
            PillButton(
              label: 'Brand',
              style: PillStyle.brand,
              onPressed: () {},
            ),
            const PillButton(label: 'Disabled'),
            PillButton(label: 'Loading', isLoading: true, onPressed: () {}),
            PillButton(
              label: 'Add to this day',
              style: PillStyle.dashed,
              onPressed: () {},
            ),
            PillButton(
              label: 'Sign out',
              style: PillStyle.outline,
              onPressed: () {},
            ),
            CircleButton(glyph: '→', onPressed: () {}),
            ArrowCircle(onTap: () {}),
            SquareButton(glyph: '+', onPressed: () {}),
          ],
        ),
        dark: dark,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('chips and controls render in $label', (tester) async {
      await pump(
        tester,
        Column(
          children: [
            const EyebrowLabel('Next trip'),
            OdysseyChip(label: 'For you', selected: true, onTap: () {}),
            OdysseyChip(
              label: 'Nature',
              selected: true,
              activeStyle: ChipActiveStyle.action,
              onTap: () {},
            ),
            SegmentedControl(
              labels: const ['Plan', 'Stays', 'Spend'],
              selected: 'Plan',
              onSelected: (_) {},
            ),
            const OdysseyBadge('DAY 3 / 6'),
            const MonoTag('DOCS'),
            DotPill(label: '2 trips ahead', onTap: () {}),
          ],
        ),
        dark: dark,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('inputs render in $label', (tester) async {
      await pump(
        tester,
        Column(
          children: [
            const FieldCard(label: 'Email'),
            const FieldCard(label: 'Password', obscureText: true),
            const ValueCard(label: 'From', value: '4 Oct'),
            const ValueCard(label: 'To', value: null),
            OdysseySwitch(value: true, onChanged: (_) {}),
            CircleCheckbox(checked: true, onChanged: (_) {}),
            const SearchPill(hint: 'Search a city or trip', readOnly: true),
          ],
        ),
        dark: dark,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('indicators render in $label', (tester) async {
      await pump(
        tester,
        Column(
          children: [
            const ProgressTrack(value: 0.62),
            const SegmentedBar(
              segments: [
                BarSegment(label: 'Stays', value: 38),
                BarSegment(label: 'Transport', value: 24),
                BarSegment(label: 'Food', value: 20),
                BarSegment(label: 'Other', value: 18),
              ],
            ),
            const BarLegend(
              segments: [
                BarSegment(label: 'Stays', value: 38),
                BarSegment(label: 'Food', value: 20),
              ],
            ),
            const BarChart(
              values: [12, 4, 28, 46, 22, 64, 88, 52, 34, 100, 18, 40],
              labels: [
                'J', 'F', 'M', 'A', 'M', 'J',
                'J', 'A', 'S', 'O', 'N', 'D',
              ],
            ),
            const StepDots(count: 3, index: 0),
            const Skeleton.row(),
            const StatCard(value: '82%', label: 'ready', highlight: true),
            OdysseyEmptyState(
              message: 'No trips yet.',
              actionLabel: 'Plan a trip',
              onAction: () {},
            ),
            OdysseyErrorState(message: 'Could not load.', onRetry: () {}),
          ],
        ),
        dark: dark,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('surfaces render in $label', (tester) async {
      await pump(
        tester,
        Column(
          children: [
            const OdysseyCard(child: Text('Card')),
            const GroupedCard(
              children: [
                SizedBox(height: 48, child: Text('One')),
                SizedBox(height: 48, child: Text('Two')),
              ],
            ),
            const HeroTile(child: Text('2,480')),
            const SizedBox(
              height: 150,
              child: PhotoSurface(seed: 'trip-1', child: PhotoTag('photo')),
            ),
            const PhotoPill(label: '14 days out'),
            DashedBox(onTap: () {}, child: const Text('Add photo')),
            const OverlapSheet(child: Text('Sheet')),
            const IconChip(icon: Icons.settings),
            const AvatarCircle(name: 'Pranta'),
          ],
        ),
        dark: dark,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the nav bar renders in $label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: Scaffold(
            bottomNavigationBar: OdysseyNavBar(
              destinations: kOdysseyDestinations,
              currentIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    });
  }

  group('behaviour', () {
    testWidgets('a pill button fires its callback', (tester) async {
      var taps = 0;
      await pump(
        tester,
        PillButton(label: 'Continue', onPressed: () => taps++),
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('a disabled pill button does not fire', (tester) async {
      await pump(tester, const PillButton(label: 'Continue'));
      await tester.tap(find.text('Continue'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a switch toggles', (tester) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => OdysseySwitch(
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(OdysseySwitch));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });

    testWidgets('a checkbox toggles', (tester) async {
      var checked = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CircleCheckbox(
                checked: checked,
                onChanged: (next) => setState(() => checked = next),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(CircleCheckbox));
      await tester.pumpAndSettle();
      expect(checked, isTrue);
    });

    testWidgets('the segmented control reports the tapped tab', (tester) async {
      String? picked;
      await pump(
        tester,
        SegmentedControl(
          labels: const ['Plan', 'Stays', 'Spend'],
          selected: 'Plan',
          onSelected: (value) => picked = value,
        ),
      );
      await tester.tap(find.text('Spend'));
      await tester.pumpAndSettle();
      expect(picked, 'Spend');
    });

    testWidgets('an empty segmented bar falls back to a track', (tester) async {
      await pump(
        tester,
        const SegmentedBar(
          segments: [BarSegment(label: 'Nothing', value: 0)],
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a progress track clamps out-of-range values', (tester) async {
      await pump(
        tester,
        const Column(
          children: [ProgressTrack(value: -1), ProgressTrack(value: 4)],
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an avatar without a name still renders', (tester) async {
      await pump(tester, const AvatarCircle(name: null));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('a loading stat card states nothing', (tester) async {
      // The readiness tile falls back to 'no list' when a trip has no packing
      // list, which is indistinguishable from one that has not loaded. While
      // it is loading the tile must say neither.
      await pump(
        tester,
        const StatCard(
          value: '—',
          label: 'no list',
          highlight: true,
          loading: true,
        ),
      );
      expect(find.text('no list'), findsNothing);
      expect(find.text('—'), findsNothing);
      expect(find.byType(Skeleton), findsNWidgets(2));
    });

    testWidgets('a loaded stat card states its value', (tester) async {
      await pump(
        tester,
        const StatCard(value: '89%', label: 'ready', highlight: true),
      );
      expect(find.text('89%'), findsOneWidget);
      expect(find.text('ready'), findsOneWidget);
      expect(find.byType(Skeleton), findsNothing);
    });
  });
}
