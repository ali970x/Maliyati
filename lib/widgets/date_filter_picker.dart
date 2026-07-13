import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

Future<DateTime?> showAppMonthPicker(
  BuildContext context,
  DashboardController controller, {
  DateTime? initialMonth,
}) async {
  final now = DateTime.now();
  var visibleYear = (initialMonth ?? now).year;

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final locale = controller.language.code;
        return AlertDialog(
          title: Text(controller.strings.chooseMonth),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '${visibleYear - 1}',
                      onPressed: () => setState(() => visibleYear--),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '$visibleYear',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '${visibleYear + 1}',
                      onPressed: () => setState(() => visibleYear++),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.35,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = DateTime(visibleYear, index + 1);
                    final selected =
                        initialMonth?.year == month.year &&
                        initialMonth?.month == month.month;
                    return selected
                        ? FilledButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, month),
                            child: Text(DateFormat.MMM(locale).format(month)),
                          )
                        : FilledButton.tonal(
                            onPressed: () =>
                                Navigator.pop(dialogContext, month),
                            child: Text(DateFormat.MMM(locale).format(month)),
                          );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(controller.strings.cancel),
            ),
          ],
        );
      },
    ),
  );
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
