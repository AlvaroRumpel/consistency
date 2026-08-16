import 'package:consistency/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ErrorView shows the message and fires onRetry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorView(message: 'boom', onRetry: () => retries++),
      ),
    ));
    expect(find.text('boom'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });
}
