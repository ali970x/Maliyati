import '../models/transaction.dart';

class CategoryTaxonomy {
  const CategoryTaxonomy._();

  static const expenseCategories = <String>[
    'Home & Groceries',
    'Personal Care',
    'Transportation & Delivery',
    'Dining & Hospitality',
    'Utilities & Bills',
    'Subscriptions',
    'Inventory & Supplies',
    'Shop Maintenance',
    'Fees & Commissions',
    'Debt Payments',
    'Other Expense',
  ];

  static const incomeCategories = <String>[
    'Product Sales',
    'Recharge & Telecom',
    'Repair Services',
    'Perfume Sales',
    'Service Income',
    'Salary & Other Income',
    'Wallet Funding',
    'Other Income',
  ];

  static const receivableCategory = 'Customer Receivables';
  static const payableCategory = 'Supplier Payables';
  static const transferCategory = 'Wallet Transfers';

  static String forTransaction(FinancialTransaction transaction) {
    return switch (transaction.type) {
      TransactionType.reserveable => receivableCategory,
      TransactionType.debt => payableCategory,
      TransactionType.transfer => transferCategory,
      TransactionType.expense => _expenseCategory(transaction),
      TransactionType.income => _incomeCategory(transaction),
      TransactionType.unknown => 'Uncategorized',
    };
  }

  static String _expenseCategory(FinancialTransaction transaction) {
    final text = _searchText(transaction);
    if (_containsAny(text, const [
      'debt payment',
      'payable payment',
      'loan repayment',
      'debt repayment',
      'debt payments',
      'dyoun',
      'dyoune',
      'تسديد دين',
      'سداد دين',
    ])) {
      return 'Debt Payments';
    }
    if (_containsAny(text, const [
      'inventory',
      'stock',
      'supplier',
      'supplies',
      'accessor',
      'charger',
      'cable',
      'screen protector',
      'packaging',
      'بضاعة',
      'مخزون',
      'اكسسوار',
    ])) {
      return 'Inventory & Supplies';
    }
    if (_containsAny(text, const [
      'transport',
      'delivery',
      'taxi',
      'fuel',
      'gasoline',
      'petrol',
      'benzine',
      'bus',
      'مواصلات',
      'توصيل',
      'تاكسي',
      'بنزين',
    ])) {
      return 'Transportation & Delivery';
    }
    if (_containsAny(text, const [
      'electric',
      'water bill',
      'internet bill',
      'phone bill',
      'utility',
      'generator',
      'فاتورة',
      'كهرباء',
      'مولد',
      'مياه',
    ])) {
      return 'Utilities & Bills';
    }
    if (_containsAny(text, const [
      'subscription',
      'subscriptions',
      'netflix',
      'spotify',
      'ishtirak',
      'eshtirak',
      'اشتراك',
    ])) {
      return 'Subscriptions';
    }
    if (_containsAny(text, const [
      'restaurant',
      'cafe',
      'coffee',
      'hospitality',
      'dining',
      'diyafe',
      'dyefe',
      'مطعم',
      'ضيافة',
      'قهوة',
    ])) {
      return 'Dining & Hospitality';
    }
    if (_containsAny(text, const [
      'personal',
      'deodorant',
      'nivea',
      'barber',
      'salon',
      'clothing',
      'clothes',
      'shoes',
      'skincare',
      'hygiene',
      'sha5se',
      'شخصي',
      'عناية',
      'ملابس',
      'حلاق',
    ])) {
      return 'Personal Care';
    }
    if (_containsAny(text, const [
      'home',
      'house',
      'grocery',
      'groceries',
      'supermarket',
      'vegetable',
      'tomato',
      'bread',
      'bayt',
      'beit',
      'masrouf bayt',
      'منزل',
      'بيت',
      'خضار',
      'طعام',
      'سوبرماركت',
    ])) {
      return 'Home & Groceries';
    }
    if (_containsAny(text, const [
      'maintenance',
      'equipment repair',
      'shop repair',
      'shop maintenance',
      'صيانة المحل',
      'تصليح المحل',
    ])) {
      return 'Shop Maintenance';
    }
    if (_containsAny(text, const [
      'fee',
      'fees',
      'commission',
      'bank charge',
      'رسوم',
      'عمولة',
    ])) {
      return 'Fees & Commissions';
    }
    return _clearCustomCategory(transaction, 'Other Expense');
  }

  static String _incomeCategory(FinancialTransaction transaction) {
    final text = _searchText(transaction);
    if (_containsAny(text, const [
      'recharge',
      'top up',
      'topup',
      'telecom',
      'alfa',
      'touch',
      'internet income',
      'mobile data',
      'phone credit',
      'تشريج',
      'تعبئة',
      'انترنت',
      'اتصالات',
    ])) {
      return 'Recharge & Telecom';
    }
    if (_containsAny(text, const [
      'repair',
      'maintenance service',
      'phone fix',
      'screen replacement',
      'تصليح',
      'صيانة',
    ])) {
      return 'Repair Services';
    }
    if (_containsAny(text, const ['perfume', 'fragrance', 'عطر', 'عطور'])) {
      return 'Perfume Sales';
    }
    if (_containsAny(text, const [
      'product sale',
      'sales income',
      'phone sale',
      'device sale',
      'accessory sale',
      'accessories sale',
      'بيع',
      'مبيعات',
    ])) {
      return 'Product Sales';
    }
    if (_containsAny(text, const [
      'wallet funding',
      'wallet deposit',
      'wish received',
      'whish received',
      'cash deposit',
      'تمويل المحفظة',
      'إيداع',
    ])) {
      return 'Wallet Funding';
    }
    if (_containsAny(text, const ['salary', 'wage', 'راتب', 'معاش'])) {
      return 'Salary & Other Income';
    }
    if (_containsAny(text, const [
      'service',
      'commission income',
      'delivery income',
      'خدمة',
      'عمولة',
    ])) {
      return 'Service Income';
    }
    if (_containsAny(text, const [
      'sale',
      'sales',
      'accessory',
      'accessories',
      'product',
      'device',
      'مبيع',
    ])) {
      return 'Product Sales';
    }
    return _clearCustomCategory(transaction, 'Other Income');
  }

  static String _clearCustomCategory(
    FinancialTransaction transaction,
    String fallback,
  ) {
    final category = transaction.category.trim();
    final key = category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final descriptionKey = transaction.description
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final isGeneric =
        key.isEmpty ||
        key == 'uncategorized' ||
        key == 'category' ||
        key == 'other' ||
        key == 'expense' ||
        key == 'income' ||
        key == 'otherexpense' ||
        key == 'otherincome' ||
        key == 'smallpurchase' ||
        key == 'smallpurchases' ||
        (fallback == 'Other Income' && key.endsWith('income')) ||
        (fallback == 'Other Expense' && key.endsWith('expense'));
    final isTransactionTitle =
        descriptionKey.isNotEmpty && key == descriptionKey;
    final isClearEnglish = RegExp(r"^[A-Za-z0-9 &'/-]+$").hasMatch(category);
    if (isGeneric || isTransactionTitle || !isClearEnglish) {
      return fallback;
    }
    return category
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty || word == '&') return word;
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  static String _searchText(FinancialTransaction transaction) {
    return [
      transaction.category,
      transaction.description,
      transaction.notes,
    ].join(' ').toLowerCase();
  }

  static bool _containsAny(String text, List<String> values) {
    return values.any((value) => text.contains(value));
  }
}
