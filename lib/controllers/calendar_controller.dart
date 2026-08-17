import '../engine/consistency_engine.dart';
import '../models/date_key.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';
import 'base_controller.dart';

enum CalendarView { month, year }

sealed class CalendarState {}

class CalendarLoading extends CalendarState {}

class CalendarData extends CalendarState {
  final Map<DateTime, double?> qualityByDay;
  final DateTime month;
  final int year;
  final CalendarView view;
  final DateTime selectedDay;
  final DateTime today;

  CalendarData({
    required this.qualityByDay,
    required this.month,
    required this.year,
    required this.view,
    required this.selectedDay,
    required this.today,
  });
}

class CalendarError extends CalendarState {
  final String message;

  CalendarError({required this.message});
}

class CalendarController extends BaseController<CalendarState> {
  final AppStore store;
  final SettingsStore settings;
  final DateTime Function() _now;

  DateTime _month; // first day of the displayed month
  int _year;
  CalendarView _view;
  DateTime _selectedDay;

  CalendarController(this.store, this.settings, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _month = _monthOf(_today(now)),
        _year = _today(now).year,
        _view = CalendarView.month,
        _selectedDay = _today(now),
        super(CalendarLoading());

  static DateTime _today(DateTime Function()? now) =>
      dateOnly((now ?? DateTime.now)());

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  @override
  void onInit() {
    store.addListener(reload);
    settings.addListener(reload);
    reload();
  }

  void reload() {
    final error = store.loadError;
    if (error != null) {
      emit(CalendarError(message: error.toString()));
      return;
    }
    if (!store.loaded) {
      emit(CalendarLoading());
      return;
    }

    final today = dateOnly(_now());
    final engine = ConsistencyEngine(
        data: store.data, threshold: settings.threshold, today: today);

    final Map<DateTime, double?> qualityByDay;
    if (_view == CalendarView.year) {
      qualityByDay = engine.heatmap(_year);
    } else {
      final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
      qualityByDay = {
        for (var i = 1; i <= daysInMonth; i++)
          DateTime(_month.year, _month.month, i):
              engine.dayAverage(DateTime(_month.year, _month.month, i)),
      };
    }

    emit(CalendarData(
      qualityByDay: qualityByDay,
      month: _month,
      year: _year,
      view: _view,
      selectedDay: _selectedDay,
      today: today,
    ));
  }

  void selectDay(DateTime day) {
    final d = dateOnly(day);
    _selectedDay = d;
    _month = _monthOf(d);
    _year = d.year;
    reload();
  }

  /// Opens [day] in the month view, in one reload. For the heatmap.
  void openMonthFor(DateTime day) {
    _view = CalendarView.month;
    selectDay(day);
  }

  /// There is nothing to see past the current month/year, so the forward
  /// arrows stop there.
  void nextMonth() {
    final next = DateTime(_month.year, _month.month + 1);
    if (next.isAfter(_monthOf(_today(_now)))) return;
    _month = next;
    reload();
  }

  void previousMonth() {
    _month = DateTime(_month.year, _month.month - 1);
    reload();
  }

  void nextYear() {
    if (_year >= _today(_now).year) return;
    _year++;
    reload();
  }

  void previousYear() {
    _year--;
    reload();
  }

  /// Keeps the window the user was looking at: the month carries its year up,
  /// the year comes back down on the selected day when it belongs to it and
  /// on January otherwise.
  void setView(CalendarView v) {
    _view = v;
    if (v == CalendarView.month) {
      _month =
          _selectedDay.year == _year ? _monthOf(_selectedDay) : DateTime(_year);
      // The panel edits the selection, so it has to be a day the grid shows.
      if (_monthOf(_selectedDay) != _month) {
        final today = _today(_now);
        _selectedDay = _monthOf(today) == _month ? today : _month;
      }
    } else {
      _year = _month.year;
    }
    reload();
  }

  @override
  void onDispose() {
    store.removeListener(reload);
    settings.removeListener(reload);
    super.onDispose();
  }
}
