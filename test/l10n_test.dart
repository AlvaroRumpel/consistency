import 'package:consistency/configs/l10n_ext.dart';
import 'package:consistency/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('English and Portuguese resolve the same keys', (tester) async {
    for (final (locale, greeting, record) in [
      (const Locale('en'), 'Hi, Alvaro', 'record 12 days'),
      (const Locale('pt'), 'Olá, Alvaro', 'recorde 12 dias'),
    ]) {
      late AppLocalizations l;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l = context.l10n;
          return const SizedBox.shrink();
        }),
      ));
      expect(l.greeting('Alvaro'), greeting);
      expect(l.recordDays(12).toLowerCase(), record);
      expect(l.streakDays(1), isNot(contains('days')));
    }
  });

  testWidgets('an unsupported locale falls back to English', (tester) async {
    late AppLocalizations l;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        l = context.l10n;
        return const SizedBox.shrink();
      }),
    ));
    expect(l.newGoal, 'New goal');
  });
}
