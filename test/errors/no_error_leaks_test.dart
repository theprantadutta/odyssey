import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads the source looking for the mistake that caused a production incident.
///
/// Sanitising at the render boundary stops the damage, but it does not stop the
/// habit: `'That did not save: $e'` still looks reasonable while you are typing
/// it, and the next person will type it. This fails the build instead.
///
/// It is deliberately a source check rather than a runtime one. The leak only
/// happens in release builds, which is exactly where no test runs.
void main() {
  final lib = Directory('lib/src');

  Iterable<File> dartFiles() => lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));

  /// Offences as (file, line number, line).
  List<(String, int, String)> scan(bool Function(String line) offends) {
    final hits = <(String, int, String)>[];
    for (final file in dartFiles()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (offends(line)) hits.add((file.path, i + 1, line.trim()));
      }
    }
    return hits;
  }

  String report(List<(String, int, String)> hits) =>
      hits.map((h) => '  ${h.$1}:${h.$2}\n    ${h.$3}').join('\n');

  test('no toast interpolates a caught exception', () {
    final hits = scan((line) {
      if (!line.contains('showOdysseyMessage(')) return false;
      return RegExp(r'\$e\b|\$err|\$error|\.toString\(\)').hasMatch(line);
    });
    expect(
      hits,
      isEmpty,
      reason:
          'Use showOdysseyError(context, "your words", error: e) so the '
          'detail goes to the log rather than the screen:\n${report(hits)}',
    );
  });

  test('no error state is handed a raw error as its message', () {
    // `OdysseyErrorState(message:)` is for prose. Anything derived from a
    // thrown object belongs in `OdysseyErrorState.fromError`.
    final hits = scan((line) {
      if (!line.contains('message:')) return false;
      // A bare error value only. `error.message` on our own enum or
      // exception is prose somebody wrote, which the allowlist allows.
      return RegExp(
            r"message:\s*(state\.error|error|e)\s*[,)!]",
          ).hasMatch(line) &&
          !line.contains('FailureMessage');
    });
    expect(
      hits,
      isEmpty,
      reason:
          'Use OdysseyErrorState.fromError(error, message: "your words"):'
          '\n${report(hits)}',
    );
  });

  test('no widget prints an error value into its text', () {
    final hits = scan((line) {
      if (!line.contains(r'${') && !line.contains(r'$e')) return false;
      if (line.contains('FailureMessage')) return false;
      if (line.contains('AppLogger') || line.contains('debugPrint')) {
        return false;
      }
      return RegExp(
        r"Text\(\s*'[^']*\$\{?(e|err|error|state\.error)\b",
      ).hasMatch(line);
    });
    expect(hits, isEmpty, reason: report(hits));
  });

  test('the sanitiser is the only thing that renders raw detail', () {
    // detailFor is the single door raw text goes through, and it is shut in
    // release. If a second one appears, it needs the same treatment.
    final sources = dartFiles()
        .where((f) => f.readAsStringSync().contains('kReleaseMode'))
        .map((f) => f.path)
        .toList();
    expect(
      sources.any((p) => p.contains('failure_message')),
      isTrue,
      reason: 'FailureMessage must keep gating on the build mode',
    );
  });
}
