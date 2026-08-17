import 'package:consistency/notifications/fake_reminder_scheduler.dart';
import 'package:consistency/notifications/reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake records schedules and cancels', () async {
    final f = FakeReminderScheduler();
    await f.init();
    expect(f.inited, isTrue);
    await f.schedule(
      ReminderRequest(when: DateTime(2026, 8, 17, 20), title: 't', body: 'b'),
    );
    expect(f.scheduled.single.when, DateTime(2026, 8, 17, 20));
    await f.cancelAll();
    expect(f.cancels, 1);
    expect(f.scheduled, isEmpty); // cancelAll clears the queue
  });
}
