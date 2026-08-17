import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Phase 8 rule: user-facing copy lives in the ARB files, not scattered across
// lib/ as raw string literals. This is a regex heuristic, not a Dart parser —
// tuned to this codebase, not a general-purpose linter. It flags anything
// that reads like a sentence or UI label (Capitalized, with a space, or a
// known single-word UI term) and gets out of the way of code: paths, log
// arguments, map keys, widget keys, and a short explicit allowlist for the
// handful of strings that are legitimately not copy.

/// Exact string contents (unquoted, escapes as written in source) that are
/// allowed to stay as raw literals.
const _allowed = {
  // Author credit is a proper name — nothing to translate. (The visible
  // splash text itself already goes through l10n.madeWithLove; this is
  // just future-proofing if the raw string ever comes back.)
  'Made with ♥ by Álvaro Rumpel',

  // Android notification channel name. Channels are identified by their id
  // ('daily_reminder'), not their name, and flutter_local_notifications
  // recreates a channel under a new id if the name changes — so this is a
  // one-time system-settings label, not conversational copy worth wiring
  // through a BuildContext-free locale lookup.
  'Daily reminder',

  // FormatException messages below are diagnostics only: every call site
  // catches FormatException and shows an already-localized snackbar
  // (couldNotReadFile / notABackup). Nobody ever reads this text.
  'Backup must be a JSON object',
  'Invalid backup: \$e',
  'Unsupported schemaVersion: \$v',
  'Bad date key: \$s',
};

/// Single-word strings (no space) that still read as UI copy.
const _knownUiWords = <String>{};

final _stringLiteral = RegExp(
  r"'(?:[^'\\]|\\.)*'" r'|"(?:[^"\\]|\\.)*"',
);

bool _looksLikeCopy(String content) {
  if (content.length <= 3) return false;
  final hasSpace = content.contains(' ');
  if (!hasSpace && !_knownUiWords.contains(content)) return false;
  return RegExp(r'^[A-Z]').hasMatch(content);
}

bool _isPathLike(String content) =>
    !content.contains(' ') && (content.contains('/') || content.contains('.'));

void main() {
  test('no raw user-facing strings outside lib/l10n', () {
    final offenders = <String>[];

    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll('\\', '/');
      if (path.contains('lib/l10n/')) continue;
      // Date-pattern strings ('EEE, d MMMM'), not copy.
      if (path.endsWith('lib/configs/date_format.dart')) continue;

      final lines = f.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') ||
            trimmed.startsWith('import ') ||
            trimmed.startsWith('export ')) {
          continue;
        }

        for (final m in _stringLiteral.allMatches(line)) {
          final raw = m.group(0)!;
          final content = raw.substring(1, raw.length - 1);
          if (!_looksLikeCopy(content)) continue;
          if (_isPathLike(content)) continue;
          if (_allowed.contains(content)) continue;

          final before = line.substring(0, m.start);
          final after = line.substring(m.end);
          // debugPrint(...) / assert(...) / log(...) argument.
          if (RegExp(r'\b(debugPrint|assert|log)\($').hasMatch(before)) {
            continue;
          }
          // Thrown Exception/Error constructor argument — diagnostics only,
          // never rendered to a user.
          if (RegExp(r'[A-Za-z_]*(Exception|Error)\($').hasMatch(before)) {
            continue;
          }
          // Map/JSON key: 'key': value, or ['key'].
          if (after.trimLeft().startsWith(':') || before.endsWith('[')) {
            continue;
          }
          // ValueKey('...') / Key('...').
          if (before.endsWith('ValueKey(') || before.endsWith('Key(')) {
            continue;
          }

          offenders.add('$path:${i + 1} — $raw');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Raw user-facing strings found outside lib/l10n — move them to '
          'an ARB key (or add a commented exemption to _allowed if this is '
          'genuinely not copy):\n${offenders.join('\n')}',
    );
  });
}
