import 'package:consistency/pages/skeleton_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('splash navigates as soon as storage is ready, no fixed delay',
      (tester) async {
    await tester.pumpWidget(await buildApp());
    // A handful of frames — far less than the old 1500ms timer.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(SkelentonPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
