import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Phase 8 rule: user-facing copy lives in the ARB files, not scattered across
// lib/ as raw string literals. This is a regex heuristic, not a Dart parser —
// tuned to this codebase, not a general-purpose linter. It flags anything
// that reads like a sentence or UI label — any phrase with a space, plus
// Capitalized single words — and gets out of the way of code:
// paths, log arguments, map keys, widget keys, and a short explicit
// allowlist for the handful of strings that are legitimately not copy.

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
  // (couldNotReadFile / notABackup). Nobody ever reads this text. Re-audit
  // this list (and the blanket Exception/Error exemption below) whenever a
  // new thrown message is added — the exemption trusts that pattern to stay
  // diagnostic-only, which is only true as long as nobody starts surfacing
  // an exception's .message directly in UI.
  'Backup must be a JSON object',
  'Invalid backup: \$e',
  'Unsupported schemaVersion: \$v',
  'Bad date key: \$s',
  // Same deal, thrown from FileGoalsRepository.load() — the constructor
  // argument sits on its own line, out of reach of the exemption below.
  'consistency.json unreadable and no valid .bak',
};

/// Capitalized single words (no space) that are legitimately not user copy —
/// identifiers, type/font names, etc. that happen to start with a capital.
/// Keep this small; the default for a single capitalized word is "copy".
const _notCopyWords = {
  'WorkSans', // font family name (lib/configs/text_styles.dart)
};

final _stringLiteral = RegExp(
  r"'(?:[^'\\]|\\.)*'" r'|"(?:[^"\\]|\\.)*"',
);

final _interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');

bool _looksLikeCopy(String content) {
  // What survives the interpolations: '${l10n.dayAverage(x)} · ' is glue
  // around already-localized text, not copy of its own.
  final literal = content.replaceAll(_interpolation, '');
  if (!RegExp('[A-Za-z]').hasMatch(literal)) return false;
  if (literal.length <= 3) return false;
  // A phrase is copy whatever its case: 'no data yet' is as user-facing as
  // 'No data yet'.
  if (literal.contains(' ')) return true;
  if (!RegExp(r'^[A-Z]').hasMatch(literal)) return false;
  return !_notCopyWords.contains(literal);
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

        final matches = _stringLiteral.allMatches(line).toList();
        // Trailing comment: everything past the first `//` that isn't inside
        // a string literal (so 'https://…' stays code) is prose, not source.
        var codeEnd = line.length;
        for (var at = line.indexOf('//');
            at != -1;
            at = line.indexOf('//', at + 2)) {
          if (matches.any((m) => at > m.start && at < m.end)) continue;
          codeEnd = at;
          break;
        }

        for (final m in matches) {
          if (m.start >= codeEnd) continue;
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

  // Proves the heuristic actually bites on single-word UI copy — this is
  // the exact gap a previous version of this guard had (an empty known-word
  // set meant it only ever flagged multi-word phrases).
  test(
      '_looksLikeCopy catches single-word UI labels and skips known-safe '
      'ones', () {
    for (final copy in ['Save', 'Cancel', 'Retry', 'no data yet']) {
      expect(_looksLikeCopy(copy), isTrue, reason: copy);
    }
    for (final notCopy in _notCopyWords) {
      expect(_looksLikeCopy(notCopy), isFalse, reason: notCopy);
    }
    expect(_looksLikeCopy('ok'), isFalse); // too short, lowercase
    // Pure glue around already-localized pieces stays out of the way.
    expect(_looksLikeCopy(r'${context.l10n.consistentDay}'), isFalse);
    expect(_looksLikeCopy(r'${avg.round()}% '), isFalse);
  });
}
