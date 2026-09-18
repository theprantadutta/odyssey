import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What index a reorder reports, and what the consumer does with it.
///
/// `ReorderableListView.onReorder` reports the index *before* the dragged item
/// is removed, so every caller wrote `if (newIndex > oldIndex) newIndex -= 1` by
/// hand — the activity list did exactly that. `onReorderItem` performs the
/// adjustment itself, so migrating to it while keeping the decrement applies it
/// twice and lands every downward move one place short.
///
/// The decisive check is the *relationship* between the two callbacks on the
/// same gesture, not the absolute index a particular drag produces. Asserting a
/// specific index would pin the framework's drag geometry — how far a pointer
/// travels before a slot changes — which is not what the migration depends on
/// and would break for reasons unrelated to it.
void main() {
  /// Mirrors `reorderActivities`: remove at the old index, insert at the new.
  List<String> applyReorder(List<String> items, int oldIndex, int newIndex) {
    final next = List<String>.from(items);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    return next;
  }

  /// Runs one drag against a list wired with the chosen callback.
  Future<(int, int)?> drag(
    WidgetTester tester, {
    required List<String> items,
    required int from,
    required int rows,
    required bool useLegacyCallback,
  }) async {
    (int, int)? reported;
    const rowHeight = 56.0;

    void capture(int oldIndex, int newIndex) => reported = (oldIndex, newIndex);

    Widget buildItem(BuildContext context, int index) => SizedBox(
          key: ValueKey(items[index]),
          height: rowHeight,
          child: ReorderableDragStartListener(
            index: index,
            child: Text(items[index]),
          ),
        );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: useLegacyCallback
            ? ReorderableListView.builder(
                itemCount: items.length,
                // ignore: deprecated_member_use
                onReorder: capture,
                itemBuilder: buildItem,
              )
            : ReorderableListView.builder(
                itemCount: items.length,
                onReorderItem: capture,
                itemBuilder: buildItem,
              ),
      ),
    ));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text(items[from])),
    );

    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    // A row at a time, with a frame between: the list decides the drop slot as
    // the dragged item crosses each neighbour, and that needs frames to happen
    // in.
    for (var i = 0; i < rows.abs(); i++) {
      await gesture.moveBy(Offset(0, rows.isNegative ? -rowHeight : rowHeight));
      await tester.pump(const Duration(milliseconds: 50));
    }

    await gesture.up();
    await tester.pumpAndSettle();

    return reported;
  }

  testWidgets('onReorderItem reports one less than onReorder when moving down',
      (tester) async {
    final items = ['a', 'b', 'c', 'd'];

    final legacy = await drag(tester,
        items: items, from: 0, rows: 2, useLegacyCallback: true);

    final modern = await drag(tester,
        items: items, from: 0, rows: 2, useLegacyCallback: false);

    expect(legacy, isNotNull, reason: 'the legacy drag did not register');
    expect(modern, isNotNull, reason: 'the modern drag did not register');

    expect(modern!.$1, legacy!.$1, reason: 'the old index is the same either way');

    // The whole migration in one line: the new callback has already done the
    // subtraction the old code did by hand.
    expect(modern.$2, legacy.$2 - 1);
  });

  testWidgets('the two callbacks agree when moving up', (tester) async {
    final items = ['a', 'b', 'c', 'd'];

    final legacy = await drag(tester,
        items: items, from: 3, rows: -2, useLegacyCallback: true);

    final modern = await drag(tester,
        items: items, from: 3, rows: -2, useLegacyCallback: false);

    expect(legacy, isNotNull);
    expect(modern, isNotNull);

    // Upward moves never needed the adjustment, which is why a double
    // subtraction would show in one direction only — easy to miss by hand.
    expect(modern, legacy);
  });

  testWidgets('a downward drag actually moves the item down', (tester) async {
    final items = ['a', 'b', 'c', 'd'];

    final modern = await drag(tester,
        items: items, from: 0, rows: 2, useLegacyCallback: false);

    expect(modern, isNotNull);

    final (oldIndex, newIndex) = modern!;
    final result = applyReorder(items, oldIndex, newIndex);

    // Applying the old decrement on top of this would leave a one-slot move at
    // index 0 — the item visibly refusing to move.
    expect(result.first, isNot('a'));
    expect(result.indexOf('a'), greaterThan(0));
    expect(result.toSet(), items.toSet());
  });

  group('the consumer applies the index as given', () {
    test('a post-removal index inserts where the user dropped it', () {
      expect(applyReorder(['a', 'b', 'c', 'd'], 0, 2), ['b', 'c', 'a', 'd']);
    });

    test('decrementing again lands one place short', () {
      // What keeping the old `newIndex -= 1` alongside onReorderItem produces.
      expect(applyReorder(['a', 'b', 'c', 'd'], 0, 1), ['b', 'a', 'c', 'd']);
    });

    test('an index at the end appends', () {
      expect(applyReorder(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
    });
  });
}
