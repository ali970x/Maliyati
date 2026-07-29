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
  String? title,
  String? explanation,
}) async {
  final now = DateTime.now();
  var visibleYear = (initialMonth ?? now).year;

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final locale = controller.language.code;
        return AlertDialog(
          title: Text(title ?? controller.strings.chooseMonth),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (explanation != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            explanation,
                            style: const TextStyle(height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
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
