enum DashboardComparisonPreset {
  previousPeriod,
  yesterday,
  previousWeek,
  previousMonth,
  custom,
}

class DashboardComparisonSettings {
  const DashboardComparisonSettings({
    this.preset = DashboardComparisonPreset.previousPeriod,
    this.customStart,
    this.customEnd,
  });

  final DashboardComparisonPreset preset;
  final DateTime? customStart;
  final DateTime? customEnd;

  bool get hasCustomRange => customStart != null && customEnd != null;

  DashboardComparisonSettings copyWith({
    DashboardComparisonPreset? preset,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    return DashboardComparisonSettings(
      preset: preset ?? this.preset,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
    );
  }

  Map<String, dynamic> toJson() => {
    'preset': preset.name,
    'customStart': customStart?.toIso8601String(),
    'customEnd': customEnd?.toIso8601String(),
  };

  factory DashboardComparisonSettings.fromJson(Map<String, dynamic> json) {
    final presetName = '${json['preset'] ?? ''}'.trim();
    final preset = DashboardComparisonPreset.values.firstWhere(
      (value) => value.name == presetName,
      orElse: () => DashboardComparisonPreset.previousPeriod,
    );
    return DashboardComparisonSettings(
      preset: preset,
      customStart: DateTime.tryParse('${json['customStart'] ?? ''}'),
      customEnd: DateTime.tryParse('${json['customEnd'] ?? ''}'),
    );
  }
}
