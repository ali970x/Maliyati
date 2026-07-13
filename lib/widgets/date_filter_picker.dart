import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';

enum _DateSelectionMode { singleDay, range }

Future<void> showCustomDateFilterPicker(
  BuildContext context,
  DashboardController controller,
) async {
  final strings = controller.strings;
  final mode = await showModalBottomSheet<_DateSelectionMode>(
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
              strings.chooseDateFilter,
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.today_rounded),
            title: Text(strings.singleDay),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () =>
                Navigator.pop(sheetContext, _DateSelectionMode.singleDay),
          ),
          ListTile(
            leading: const Icon(Icons.date_range_rounded),
            title: Text(strings.dateRange),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pop(sheetContext, _DateSelectionMode.range),
          ),
        ],
      ),
    ),
  );

  if (mode == null || !context.mounted) {
    return;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final firstDate = DateTime(today.year - 8);
  final lastDate = DateTime(today.year + 1, 12, 31);

  if (mode == _DateSelectionMode.singleDay) {
    final picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: controller.customStart ?? today,
    );
    if (picked != null) {
      controller.setCustomRange(DateTimeRange(start: picked, end: picked));
    }
    return;
  }

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
