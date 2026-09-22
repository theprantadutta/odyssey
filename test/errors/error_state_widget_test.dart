import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/common/theme/app_theme.dart';
import 'package:odyssey/src/common/widgets/odyssey/odyssey.dart';

/// What the error screen puts in front of somebody.
///
/// These run in debug, where the raw detail is deliberately still rendered - a
/// developer looking at a broken screen should not have to go to the console.
/// So the contract they check is the one that holds in every build: [message]
/// is prose we wrote, and anything raw exists only in [detail], which is null
/// in release.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  test('a thrown object is described, not quoted', () {
    final state = OdysseyErrorState.fromError(
      'SqliteException(1): while executing, duplicate column name: reason',
      message: 'Your trips could not be loaded.',
    );

    expect(state.message, 'Your trips could not be loaded.');
    expect(state.message, isNot(contains('SqliteException')));
    expect(state.message, isNot(contains('duplicate column')));
    // The raw text survives only here, and only outside release.
    expect(state.detail, contains('duplicate column'));
  });

  test('a recognised failure is explained in the user\'s terms', () {
    final state = OdysseyErrorState.fromError(
      const SocketException('Failed host lookup: odyssey.pranta.dev'),
      message: 'Your trips could not be loaded.',
    );

    expect(state.message, contains('offline'));
    expect(state.message, isNot(contains('pranta.dev')));
  });

  test('the default constructor carries no detail at all', () {
    expect(const OdysseyErrorState(message: 'Nope.').detail, isNull);
  });

  testWidgets('the headline and the safe line are what is rendered', (
    tester,
  ) async {
    await pump(
      tester,
      OdysseyErrorState.fromError(
        StateError('database is locked at /data/odyssey.db'),
        message: 'Your trips could not be loaded.',
      ),
    );

    expect(find.text('That did not load.'), findsOneWidget);
    expect(find.text('Your trips could not be loaded.'), findsOneWidget);
  });

  testWidgets('prose passed by a caller is shown as written', (tester) async {
    await pump(
      tester,
      const OdysseyErrorState(
        message: 'We could not reach the store to load the plans.',
      ),
    );
    expect(
      find.text('We could not reach the store to load the plans.'),
      findsOneWidget,
    );
  });

  testWidgets('retry is offered when there is something to retry', (
    tester,
  ) async {
    var tapped = 0;
    await pump(
      tester,
      OdysseyErrorState.fromError(
        StateError('boom'),
        message: 'Your trips could not be loaded.',
        onRetry: () => tapped++,
      ),
    );

    await tester.tap(find.text('Try again'));
    expect(tapped, 1);
  });
}
