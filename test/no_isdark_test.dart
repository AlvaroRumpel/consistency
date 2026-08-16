import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Phase 1 rule: light/dark branching lives only in the ThemeData builders.
void main() {
  test('no isDark branching outside lib/configs/theme.dart', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.replaceAll('\\', '/').endsWith('lib/configs/theme.dart')) {
        continue;
      }
      final src = f.readAsStringSync();
      if (src.contains('Brightness.dark') || src.contains('isDark')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
