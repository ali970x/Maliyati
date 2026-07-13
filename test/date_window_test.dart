import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('last 3 days includes today and the previous two days', () {
    final window = DateWindow.forFilter(
      TimeFilter.last3Days,
      now: DateTime(2026, 7, 7),
    );

    expect(window.contains(DateTime(2026, 7, 4)), isFalse);
    expect(window.contains(DateTime(2026, 7, 5)), isTrue);
    expect(window.contains(DateTime(2026, 7, 6)), isTrue);
    expect(window.contains(DateTime(2026, 7, 7)), isTrue);
    expect(window.contains(DateTime(2026, 7, 8)), isFalse);
  });

  test('a selected recent day narrows the last 3 days filter to one day', () {
    final controller = DashboardController();
    addTearDown(controller.dispose);

    controller.selectRecentDay(DateTime(2026, 7, 10));

    expect(controller.timeFilter, TimeFilter.last3Days);
    expect(controller.currentWindow.contains(DateTime(2026, 7, 9)), isFalse);
    expect(controller.currentWindow.contains(DateTime(2026, 7, 10)), isTrue);
    expect(controller.currentWindow.contains(DateTime(2026, 7, 11)), isFalse);
  });

  test('tapping last 3 days again clears the selected recent day', () {
    final controller = DashboardController();
    addTearDown(controller.dispose);

    controller.selectRecentDay(DateTime(2026, 7, 10));
    controller.selectTimeFilter(TimeFilter.last3Days);

    expect(controller.selectedRecentDay, isNull);
    expect(controller.currentWindow.dayCount, 3);
  });

  test('this month runs from the first day through today', () {
    final window = DateWindow.forFilter(
      TimeFilter.thisMonth,
      now: DateTime(2026, 7, 7),
    );

    expect(window.contains(DateTime(2026, 6, 30)), isFalse);
    expect(window.contains(DateTime(2026, 7, 1)), isTrue);
    expect(window.contains(DateTime(2026, 7, 7)), isTrue);
    expect(window.contains(DateTime(2026, 7, 8)), isFalse);
    expect(window.dayCount, 7);
  });

  test('this week includes today and the previous six days', () {
    final window = DateWindow.forFilter(
      TimeFilter.thisWeek,
      now: DateTime(2026, 7, 12),
    );

    expect(window.contains(DateTime(2026, 7, 12)), isTrue);
    expect(window.contains(DateTime(2026, 7, 10)), isTrue);
    expect(window.contains(DateTime(2026, 7, 6)), isTrue);
    expect(window.contains(DateTime(2026, 7, 5)), isFalse);
  });

  test('previous week is the seven days before the current window', () {
    final previous = DateWindow.forFilter(
      TimeFilter.thisWeek,
      now: DateTime(2026, 7, 12),
    ).previous!;

    expect(previous.contains(DateTime(2026, 7, 5)), isTrue);
    expect(previous.contains(DateTime(2026, 6, 29)), isTrue);
    expect(previous.contains(DateTime(2026, 7, 6)), isFalse);
  });

  test('custom range includes both the start and end dates', () {
    final window = DateWindow.forFilter(
      TimeFilter.custom,
      customStart: DateTime(2026, 7, 9),
      customEnd: DateTime(2026, 7, 10),
    );

    expect(window.contains(DateTime(2026, 7, 8)), isFalse);
    expect(window.contains(DateTime(2026, 7, 9)), isTrue);
    expect(window.contains(DateTime(2026, 7, 10)), isTrue);
    expect(window.contains(DateTime(2026, 7, 11)), isFalse);
  });

  test('custom range supports a single selected day', () {
    final window = DateWindow.forFilter(
      TimeFilter.custom,
      customStart: DateTime(2026, 7, 10),
      customEnd: DateTime(2026, 7, 10),
    );

    expect(window.contains(DateTime(2026, 7, 9)), isFalse);
    expect(window.contains(DateTime(2026, 7, 10)), isTrue);
    expect(window.contains(DateTime(2026, 7, 11)), isFalse);
  });
}
