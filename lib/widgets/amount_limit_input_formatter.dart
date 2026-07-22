import 'package:flutter/services.dart';

class AmountLimitInputFormatter extends TextInputFormatter {
  AmountLimitInputFormatter(this.maxAmount);

  final double maxAmount;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.trim();
    if (text.isEmpty) {
      return newValue;
    }
    final normalized = text.replaceAll(',', '');
    final value = double.tryParse(normalized);
    if (value == null) {
      return oldValue;
    }
    if (value > maxAmount) {
      return oldValue;
    }
    return newValue;
  }
}

String compactUsdLimit(double value) {
  final fixed = value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '\$$fixed';
}

String compactLbpLimit(double value) {
  if (value == 0) {
    return '0K';
  }
  final thousands = value / 1000;
  final text = thousands.truncateToDouble() == thousands
      ? thousands.toStringAsFixed(0)
      : thousands.toStringAsFixed(1);
  return '${text}K';
}
