enum DashboardPinMetric { income, expense, receivable, payable, transfer }

enum DashboardPinComparison { day, week, month, selectedPeriod }

class DashboardPinnedItem {
  const DashboardPinnedItem({
    required this.metric,
    required this.comparison,
    this.category,
    this.mode = 'open',
  });

  final DashboardPinMetric metric;
  final DashboardPinComparison comparison;
  final String? category;
  final String mode;

  String get identity {
    final normalizedCategory = category?.trim().toLowerCase() ?? '';
    return '${metric.name}|$normalizedCategory|${mode.trim().toLowerCase()}';
  }

  DashboardPinnedItem copyWith({
    DashboardPinMetric? metric,
    DashboardPinComparison? comparison,
    String? category,
    bool clearCategory = false,
    String? mode,
  }) {
    return DashboardPinnedItem(
      metric: metric ?? this.metric,
      comparison: comparison ?? this.comparison,
      category: clearCategory ? null : category ?? this.category,
      mode: mode ?? this.mode,
    );
  }

  Map<String, dynamic> toJson() => {
    'metric': metric.name,
    'comparison': comparison.name,
    if (category?.trim().isNotEmpty == true) 'category': category!.trim(),
    'mode': mode,
  };

  factory DashboardPinnedItem.fromJson(Map<String, dynamic> json) {
    final metricName = '${json['metric'] ?? ''}'.trim();
    final comparisonName = '${json['comparison'] ?? ''}'.trim();
    final rawCategory = '${json['category'] ?? ''}'.trim();
    return DashboardPinnedItem(
      metric: DashboardPinMetric.values.firstWhere(
        (value) => value.name == metricName,
        orElse: () => DashboardPinMetric.expense,
      ),
      comparison: DashboardPinComparison.values.firstWhere(
        (value) => value.name == comparisonName,
        orElse: () => DashboardPinComparison.month,
      ),
      category: rawCategory.isEmpty ? null : rawCategory,
      mode: '${json['mode'] ?? 'open'}'.trim().isEmpty
          ? 'open'
          : '${json['mode']}',
    );
  }
}
