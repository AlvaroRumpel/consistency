import 'reminder_scheduler.dart';

/// In-memory [ReminderScheduler] for tests: records calls instead of touching the OS.
class FakeReminderScheduler implements ReminderScheduler {
  bool permissionGranted = true;
  final List<ReminderRequest> scheduled = [];
  int cancels = 0;
  bool inited = false;

  @override
  Future<void> init() async {
    inited = true;
  }

  @override
  Future<bool> ensurePermission() async => permissionGranted;

  @override
  Future<void> schedule(ReminderRequest r) async {
    scheduled
      ..clear()
      ..add(r);
  }

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled.clear();
  }
}
