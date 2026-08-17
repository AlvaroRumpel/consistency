import 'package:consistency/data/in_memory_goals_repository.dart';
import 'package:consistency/l10n/app_localizations.dart';
import 'package:consistency/models/app_data.dart';
import 'package:consistency/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _Throwing extends InMemoryGoalsRepository {
  @override
  Future<AppData> load() async =>
      throw const FormatException('boom: secret internals');
}

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

  testWidgets('a load failure shows localised copy, never the exception',
      (tester) async {
    await tester.pumpWidget(await buildApp(repo: _Throwing()));
    await pumpFrames(tester);

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('boom'), findsNothing);
  });
}
