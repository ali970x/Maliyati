import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';

Future<void> showCustomDateRangePicker(
  BuildContext context,
  DashboardController controller,
) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final firstDate = DateTime(today.year - 8);
  final lastDate = DateTime(today.year + 1, 12, 31);

  final range = await showDateRangePicker(
    context: context,
    firstDate: firstDate,
    lastDate: lastDate,
    initialDateRange: DateTimeRange(
      start: controller.customStart ?? today.subtract(const Duration(days: 30)),
      end: controller.customEnd ?? today,
    ),
  );
  if (range != null) {
    controller.setCustomRange(range);
  }
}

Future<void> showCustomSingleDayPicker(
  BuildContext context,
  DashboardController controller,
) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final picked = await showDatePicker(
    context: context,
    firstDate: DateTime(today.year - 8),
    lastDate: DateTime(today.year + 1, 12, 31),
    initialDate: controller.customStart ?? today,
  );
  if (picked != null) {
    controller.setCustomRange(DateTimeRange(start: picked, end: picked));
  }
}
