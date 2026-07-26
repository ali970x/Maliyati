import '../models/transaction.dart';

class LabelNormalizer {
  const LabelNormalizer._();

  static const myWallet = 'My Wallet';
  static const wishMoney = 'Whish Money';
  static const service = 'Service';

  static bool isWishMoney(String value) {
    final normalized = _key(value);
    return normalized.contains('whish') ||
        normalized.contains('wesh') ||
        normalized.contains('wish');
  }

  static bool isService(String value) => _key(value) == 'service';

  static String wallet(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final normalized = _key(trimmed);
    if (isWishMoney(trimmed)) {
      return wishMoney;
    }
    if (isService(trimmed)) {
      return service;
    }
    if (normalized == 'mywallet' ||
        normalized == 'wallet' ||
        normalized == 'cash' ||
        trimmed == 'محفظتي' ||
        trimmed == 'المحفظة') {
      return myWallet;
    }
    if (trimmed.contains('ويش') || trimmed.contains('وش موني')) {
      return wishMoney;
    }
    return text(trimmed);
  }

  static String category(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return switch (_key(trimmed)) {
      'masroufbayt' ||
      'masrofbayt' ||
      'houseexpense' ||
      'homeexpense' => 'Home expenses',
      'dyefe' || 'diyafe' || 'hospitality' => 'Hospitality',
      'dyoune' || 'dyoun' || 'dion' || 'debts' => 'Debt payments',
      'eshtiraket' || 'ishtiraket' || 'subscriptions' => 'Subscriptions',
      'na2rashe' ||
      'nakrashe' ||
      'smallpurchase' ||
      'smallpurchases' => 'Small purchases',
      'incomeinternet' => 'Internet income',
      'incomezougeib' || 'incomezougaib' => 'Zougeib income',
      'incomeother' => 'Other income',
      'incomeaboudi' => 'Aboudi income',
      'wishmoney' || 'whishmoney' || 'weshmoney' => wishMoney,
      'wishtopup' || 'whishtopup' => 'Whish top up',
      'wishreceived' || 'whishreceived' => 'Whish received',
      'wishtransfer' || 'whishtransfer' => 'Whish transfer',
      'wishexchange' || 'whishexchange' => 'Whish exchange',
      _ => text(trimmed),
    };
  }

  static String source(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'app') {
      return TransactionSource.application.label;
    }
    if (normalized == 'google sheet' || normalized == 'sheet') {
      return TransactionSource.googleSheet.label;
    }
    if (normalized == 'gemini' || normalized == 'manual') {
      return TransactionSource.script.label;
    }
    return text(value.trim());
  }

  static String text(String value) {
    var output = value.trim();
    output = output.replaceAll(
      RegExp(r'\bwhish\s+money\b', caseSensitive: false),
      wishMoney,
    );
    output = output.replaceAll(
      RegExp(r'\bwesh\s+money\b', caseSensitive: false),
      wishMoney,
    );
    output = output.replaceAll(
      RegExp(r'\bwish\s+money\b', caseSensitive: false),
      wishMoney,
    );
    output = output.replaceAll(
      RegExp(r'\bwhish\b', caseSensitive: false),
      'Whish',
    );
    return output.replaceAll(
      RegExp(r'\bwesh\b', caseSensitive: false),
      'Whish',
    );
  }

  static String _key(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
