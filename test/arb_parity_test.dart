import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The generator only reads placeholder metadata from the template ARB, so a
/// translation that drops a key — or renames a placeholder inside one — fails
/// at runtime (or silently prints a literal '{name}'), not at build time.
/// This is that missing build-time check.
Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Placeholder names used in an ICU message, nested ones included: `{name}`
/// and `{count, plural, ...}`, but not the literal text inside a plural
/// branch (`=1{1 day}`).
Set<String> _placeholders(String message) => RegExp(r'\{(\w+)\s*[},]')
    .allMatches(message)
    .map((m) => m.group(1)!)
    .toSet();

void main() {
  final en = _arb('lib/l10n/app_en.arb');
  final pt = _arb('lib/l10n/app_pt.arb');

  Set<String> keys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('both ARBs define the same keys', () {
    expect(keys(pt), keys(en));
  });

  test('every key uses the same placeholders in both ARBs', () {
    final mismatched = <String>[];
    for (final k in keys(en)) {
      if (!pt.containsKey(k)) continue;
      final a = _placeholders(en[k] as String);
      final b = _placeholders(pt[k] as String);
      if (a.length != b.length || !a.containsAll(b)) {
        mismatched.add('$k: en=$a pt=$b');
      }
    }
    expect(mismatched, isEmpty, reason: mismatched.join('\n'));
  });

  test('only the template carries @ metadata', () {
    // Descriptions and placeholder types belong to the template ARB; the
    // translations stay plain key/value files.
    expect(pt.keys.where((k) => k.startsWith('@') && k != '@@locale'), isEmpty);
    for (final k in keys(en)) {
      expect(en['@$k'], isNotNull, reason: '$k has no @description block');
      expect((en['@$k'] as Map)['description'], isNotNull,
          reason: '$k has no @description');
    }
  });
}
