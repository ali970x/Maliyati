import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import 'date_filter_picker.dart';
import 'filter_pill.dart';
import 'finance_formatters.dart';

String periodFilterLabel(
  DashboardController controller, [
  TimeFilter? selectedFilter,
]) {
  final filter = selectedFilter ?? controller.timeFilter;
  if (filter == TimeFilter.last3Days && controller.selectedRecentDay != null) {
    return FinanceFormatters.shortDate(controller.selectedRecentDay!);
  }
  if (filter == TimeFilter.thisMonth && controller.selectedMonth != null) {
    return FinanceFormatters.monthYear(controller.selectedMonth!);
  }
  if (filter == TimeFilter.allTime && controller.referenceMonth != null) {
    return FinanceFormatters.monthYear(controller.referenceMonth!);
  }
  if (filter == TimeFilter.thisWeek && controller.selectedMonthWeek != null) {
    return controller.selectedMonthWeek == 4
        ? controller.strings.restOfMonth
        : controller.strings.weekNumber(controller.selectedMonthWeek! + 1);
  }
  if (filter == TimeFilter.custom &&
      controller.customStart != null &&
      controller.customEnd != null) {
    final start = FinanceFormatters.shortDate(controller.customStart!);
    final end = FinanceFormatters.shortDate(controller.customEnd!);
    if (_sameDay(controller.customStart!, controller.customEnd!)) {
      return '${controller.strings.singleDay}: $start';
    }
    return '$start - $end';
  }
  return controller.strings.timeFilterLabel(filter.name);
}

class PeriodFilterBar extends StatelessWidget {
  const PeriodFilterBar({super.key, required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: TimeFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = TimeFilter.values[index];
          return SizedBox(
            width: _width(filter),
            child: AppFilterPill(
              selected: controller.timeFilter == filter,
              label: periodFilterLabel(controller, filter),
              icon: _icon(filter),
              selectedColor: filter == TimeFilter.last3Days
                  ? const Color(0xFF168A5B)
                  : null,
              onTap: () async {
                if (filter == TimeFilter.custom) {
                  await showCustomDateRangePicker(context, controller);
                } else {
                  controller.selectTimeFilter(filter);
                }
              },
              onLongPress: switch (filter) {
                TimeFilter.last3Days => () => _showRecentDayPicker(context),
                TimeFilter.custom => () => showCustomSingleDayPicker(
                  context,
                  controller,
                ),
                TimeFilter.thisMonth => () => _showMonthPicker(context),
                TimeFilter.thisWeek => () => _showMonthWeekPicker(context),
                TimeFilter.allTime => () => _showReferenceMonthPicker(context),
                _ => null,
              },
            ),
          );
        },
      ),
    );
  }

  double _width(TimeFilter filter) {
    if (filter == TimeFilter.custom &&
        controller.customStart != null &&
        controller.customEnd != null) {
      return _sameDay(controller.customStart!, controller.customEnd!)
          ? 148
          : 164;
    }
    if (filter == TimeFilter.thisMonth && controller.selectedMonth != null) {
      return 132;
    }
    if (filter == TimeFilter.allTime && controller.referenceMonth != null) {
      return 132;
    }
    return switch (filter) {
      TimeFilter.today => 92,
      TimeFilter.last3Days => 126,
      TimeFilter.thisWeek => 118,
      TimeFilter.thisMonth => 122,
      TimeFilter.custom => 98,
      TimeFilter.allTime => 102,
    };
  }

  Future<void> _showMonthPicker(BuildContext context) async {
    final month = await showAppMonthPicker(
      context,
      controller,
      initialMonth: controller.selectedMonth ?? DateTime.now(),
    );
    if (month != null) {
      controller.selectMonth(month);
    }
  }

  Future<void> _showReferenceMonthPicker(BuildContext context) async {
    final month = await showAppMonthPicker(
      context,
      controller,
      initialMonth: controller.referenceMonth ?? DateTime.now(),
    );
    if (month != null) {
      controller.selectReferenceMonth(month);
    }
  }

  Future<void> _showMonthWeekPicker(BuildContext context) async {
    final month = controller.referenceMonth ?? DateTime.now();
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final weeks = <({int index, DateTime start, DateTime end})>[];
    for (var index = 0; index < 5; index++) {
      final start = monthStart.add(Duration(days: index * 7));
      if (!start.isBefore(monthEnd)) {
        break;
      }
      final candidateEnd = start.add(const Duration(days: 6));
      weeks.add((
        index: index,
        start: start,
        end: candidateEnd.isBefore(monthEnd)
            ? candidateEnd
            : monthEnd.subtract(const Duration(days: 1)),
      ));
    }

    final selected = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Text(
                controller.strings.chooseWeek(
                  FinanceFormatters.monthYear(monthStart),
                ),
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            for (final week in weeks)
              ListTile(
                leading: const Icon(Icons.view_week_rounded),
                title: Text(
                  week.index == 4
                      ? controller.strings.restOfMonth
                      : controller.strings.weekNumber(week.index + 1),
                ),
                subtitle: Text(
                  '${FinanceFormatters.shortDate(week.start)} - '
                  '${FinanceFormatters.shortDate(week.end)}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetContext, week.index),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      controller.selectMonthWeek(selected);
    }
  }

  IconData _icon(TimeFilter filter) {
    return switch (filter) {
      TimeFilter.today => Icons.today_rounded,
      TimeFilter.last3Days =>
        controller.selectedRecentDay == null
            ? Icons.date_range_rounded
            : Icons.event_available_rounded,
      TimeFilter.thisWeek => Icons.view_week_rounded,
      TimeFilter.thisMonth => Icons.calendar_month_rounded,
      TimeFilter.custom =>
        controller.customStart != null &&
                controller.customEnd != null &&
                _sameDay(controller.customStart!, controller.customEnd!)
            ? Icons.event_rounded
            : Icons.tune_rounded,
      TimeFilter.allTime => Icons.all_inclusive_rounded,
    };
  }

  Future<void> _showRecentDayPicker(BuildContext context) async {
    final today = controller.referenceDate;
    final candidateDays = [
      (
        day: today.subtract(const Duration(days: 1)),
        label: controller.strings.yesterday,
      ),
      (
        day: today.subtract(const Duration(days: 2)),
        label: controller.strings.twoDaysAgo,
      ),
      (
        day: today.subtract(const Duration(days: 3)),
        label: controller.strings.threeDaysAgo,
      ),
    ];
    final monthStart = controller.referenceMonth == null
        ? null
        : DateTime(
            controller.referenceMonth!.year,
            controller.referenceMonth!.month,
          );
    final days = monthStart == null
        ? candidateDays
        : candidateDays
              .where((item) => !item.day.isBefore(monthStart))
              .toList();

    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Text(
                controller.strings.chooseRecentDay,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            for (final item in days)
              ListTile(
                leading: const Icon(Icons.calendar_today_rounded),
                title: Text(item.label),
                subtitle: Text(FinanceFormatters.date(item.day)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetContext, item.day),
              ),
          ],
        ),
      ),
    );

    if (selected != null) {
      controller.selectRecentDay(selected);
    }
  }
}

bool _sameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
