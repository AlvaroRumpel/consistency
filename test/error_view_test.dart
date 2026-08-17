import 'package:consistency/l10n/app_localizations.dart';
import 'package:consistency/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ErrorView shows the message and fires onRetry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ErrorView(message: 'boom', onRetry: () => retries++),
      ),
    ));
    expect(find.text('boom'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });
}
