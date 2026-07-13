enum AppLanguage {
  english('en'),
  arabic('ar');

  const AppLanguage(this.code);

  final String code;

  bool get isArabic => this == AppLanguage.arabic;

  static AppLanguage fromCode(String? code) {
    return code == arabic.code ? arabic : english;
  }
}

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isArabic => language.isArabic;

  String get appName => isArabic ? 'ماليّاتي' : 'Maliyati';
  String get selectedPeriod => isArabic ? 'الفترة المختارة' : 'Selected period';
  String get incomeVsExpenses =>
      isArabic ? 'الدخل مقابل المصاريف' : 'Income vs expenses';
  String get keyInsights => isArabic ? 'أهم المؤشرات' : 'Key insights';
  String get categoryRanking => isArabic ? 'ترتيب الفئات' : 'Category ranking';
  String get expenseCategoryRanking =>
      isArabic ? 'ترتيب فئات المصاريف' : 'Expense category ranking';
  String get incomeCategoryRanking =>
      isArabic ? 'ترتيب فئات الدخل' : 'Income category ranking';
  String get paymentMethodRanking =>
      isArabic ? 'ترتيب طرق الدفع' : 'Payment method ranking';
  String get incomePaymentMethodRanking =>
      isArabic ? 'ترتيب طرق دفع الدخل' : 'Income payment method ranking';
  String get expensePaymentMethodRanking =>
      isArabic ? 'ترتيب طرق دفع المصاريف' : 'Expense payment method ranking';
  String get noPaymentMethodData => isArabic
      ? 'لا توجد طرق دفع ضمن هذه الفترة.'
      : 'No payment method data in this period.';
  String get unspecifiedPaymentMethod => isArabic ? 'غير محدد' : 'Unspecified';
  String get spendingConcentration =>
      isArabic ? 'تركيز الصرف' : 'Spending concentration';
  String get notesCoverage =>
      isArabic ? 'العمليات مع ملاحظات' : 'Transactions with notes';
  String notesCount(int count, int total) =>
      isArabic ? '$count من $total عملية' : '$count of $total transactions';
  String get topCategoryShare =>
      isArabic ? 'حصة أعلى فئة' : 'Top category share';
  String get noCategoryData => isArabic
      ? 'لا توجد فئات ضمن هذه الفترة.'
      : 'No category data in this period.';
  String get dashboard => isArabic ? 'الرئيسية' : 'Dashboard';
  String get transactions => isArabic ? 'العمليات' : 'Transactions';
  String get analytics => isArabic ? 'التحليلات' : 'Analytics';
  String get settings => isArabic ? 'الإعدادات' : 'Settings';
  String get refresh => isArabic ? 'تحديث' : 'Refresh';
  String get tryAgain => isArabic ? 'حاول مجدداً' : 'Try again';
  String get readyToSync => isArabic ? 'جاهز للمزامنة' : 'Ready to sync';
  String updated(String value) =>
      isArabic ? 'آخر تحديث $value' : 'Updated $value';
  String get couldNotLoadSheet =>
      isArabic ? 'تعذر تحميل الجدول' : 'Could not load sheet';
  String get noTransactionsYet =>
      isArabic ? 'لا توجد عمليات بعد' : 'No transactions yet';
  String get noValidRows => isArabic
      ? 'تم تحميل الجدول، لكن لم يتم العثور على صفوف صالحة بالأعمدة المتوقعة.'
      : 'The sheet loaded, but no valid rows matched the expected columns.';
  String get netBalance => isArabic ? 'الصافي' : 'Net balance';
  String get usdNet => isArabic ? 'صافي الدولار' : 'USD net';
  String get lbpNet => isArabic ? 'صافي اللبناني' : 'LBP net';
  String get vsPrevious => isArabic ? 'مقارنة بالسابق' : 'vs previous';
  String get income => isArabic ? 'الدخل' : 'Income';
  String get expense => isArabic ? 'المصاريف' : 'Expense';
  String get expenses => isArabic ? 'المصاريف' : 'Expenses';
  String get showIncomeTransactions =>
      isArabic ? 'عمليات الدخل' : 'Income transactions';
  String get showExpenseTransactions =>
      isArabic ? 'عمليات المصاريف' : 'Expense transactions';
  String get tapIncomeOrExpenses => isArabic
      ? 'اضغط على كرت الدخل أو المصاريف لعرض العمليات هنا.'
      : 'Tap Income or Expenses to review the matching transactions here.';
  String get noIncomeInPeriod =>
      isArabic ? 'لا يوجد دخل ضمن هذه الفترة.' : 'No income in this period.';
  String get expensesFocus => isArabic ? 'تركيز المصاريف' : 'Expenses focus';
  String get expenseUsd => isArabic ? 'مصاريف USD' : 'Expense USD';
  String get expenseLbp => isArabic ? 'مصاريف LBP' : 'Expense LBP';
  String get totalAsUsd => isArabic ? 'المجموع بالدولار' : 'Total as USD';
  String get totalAsLbp => isArabic ? 'المجموع باللبناني' : 'Total as LBP';
  String get netAfterIncomeExpenses =>
      isArabic ? 'الصافي بعد الدخل والمصاريف' : 'Net after income and expenses';
  String get averageDailyExpense =>
      isArabic ? 'متوسط المصروف اليومي' : 'Average daily expense';
  String get dailyExpenses => isArabic ? 'المصاريف اليومية' : 'Daily expenses';
  String get noExpensesInPeriod => isArabic
      ? 'لا توجد مصاريف ضمن هذه الفترة.'
      : 'No expenses in this period.';
  String undatedRows(int count) => isArabic
      ? '$count صف بلا تاريخ في الجدول. تظهر في كل الوقت، لكنها لا تدخل في فلاتر اليوم/الأسبوع/الشهر.'
      : '$count rows have no Date in the sheet. They appear in All time, but not in Today/Week/Month filters.';
  String get quickStats => isArabic ? 'إحصائيات سريعة' : 'Quick stats';
  String get expenseRatio => isArabic ? 'نسبة المصاريف' : 'Expense ratio';
  String get topExpenseCategory =>
      isArabic ? 'أعلى فئة مصاريف' : 'Top expense category';
  String get topIncomeCategory =>
      isArabic ? 'أعلى فئة دخل' : 'Top income category';
  String get averageDailySpend =>
      isArabic ? 'متوسط الصرف اليومي' : 'Average daily spend';
  String get transactionCount => isArabic ? 'عدد العمليات' : 'Transactions';
  String get largestExpense => isArabic ? 'أكبر مصروف' : 'Largest expense';
  String get largestIncome => isArabic ? 'أكبر دخل' : 'Largest income';
  String get noData => isArabic ? 'لا توجد بيانات' : 'No data';
  String get noDateInSheet =>
      isArabic ? 'لا يوجد تاريخ في الجدول' : 'No date in sheet';
  String get noMatchingTransactions =>
      isArabic ? 'لا توجد عمليات مطابقة' : 'No matching transactions';
  String get tryChangingFilters => isArabic
      ? 'جرّب إزالة البحث أو تغيير الفلاتر.'
      : 'Try clearing search or changing the filters.';
  String get searchTransactions =>
      isArabic ? 'بحث في العمليات' : 'Search transactions';
  String get clear => isArabic ? 'مسح' : 'Clear';
  String get allTypes => isArabic ? 'كل الأنواع' : 'All types';
  String get allCurrencies => isArabic ? 'كل العملات' : 'All currencies';
  String get category => isArabic ? 'الفئة' : 'Category';
  String get allCategories => isArabic ? 'كل الفئات' : 'All categories';
  String get sort => isArabic ? 'ترتيب' : 'Sort';
  String get newest => isArabic ? 'الأحدث' : 'Newest';
  String get oldest => isArabic ? 'الأقدم' : 'Oldest';
  String get highestAmount => isArabic ? 'الأكبر مبلغاً' : 'Highest amount';
  String get lowestAmount => isArabic ? 'الأصغر مبلغاً' : 'Lowest amount';
  String get noAnalyticsYet =>
      isArabic ? 'لا توجد تحليلات بعد' : 'No analytics yet';
  String get loadTransactionsForCharts => isArabic
      ? 'حمّل العمليات أو اختر فترة أوسع لعرض الرسوم.'
      : 'Load transactions or choose a wider date range to see charts.';
  String get bestDay => isArabic ? 'أفضل يوم' : 'Best day';
  String get worstDay => isArabic ? 'أسوأ يوم' : 'Worst day';
  String get dailyTrend => isArabic ? 'الاتجاه اليومي' : 'Daily trend';
  String get dailyBreakdown => isArabic ? 'تفاصيل الأيام' : 'Daily breakdown';
  String get expensesByCategory =>
      isArabic ? 'المصاريف حسب الفئة' : 'Expenses by category';
  String get incomeByCategory =>
      isArabic ? 'الدخل حسب الفئة' : 'Income by category';
  String get weeklySummary => isArabic ? 'ملخص أسبوعي' : 'Weekly summary';
  String get monthlySummary => isArabic ? 'ملخص شهري' : 'Monthly summary';
  String weekOf(String value) => isArabic ? 'أسبوع $value' : 'Week of $value';
  String get dataSource => isArabic ? 'مصدر البيانات' : 'Data source';
  String get googleSheetUrl =>
      isArabic ? 'رابط Google Sheet' : 'Google Sheet URL';
  String get enterSheetUrl => isArabic
      ? 'أدخل رابط Google Sheet عام.'
      : 'Enter a public Google Sheet URL.';
  String get exchangeRate => isArabic ? 'سعر الصرف' : 'Exchange rate';
  String get lbpEqualsUsd => isArabic ? 'ليرة = 1 دولار' : 'LBP = 1 USD';
  String get enterValidExchangeRate =>
      isArabic ? 'أدخل سعر صرف صحيح.' : 'Enter a valid exchange rate.';
  String get saveSettings => isArabic ? 'حفظ الإعدادات' : 'Save settings';
  String get csvExportUrl => isArabic ? 'رابط CSV' : 'CSV export URL';
  String get lastUpdate => isArabic ? 'آخر تحديث' : 'Last update';
  String get notSyncedYet =>
      isArabic ? 'لم تتم المزامنة بعد' : 'Not synced yet';
  String get configuredRate =>
      isArabic ? 'سعر الصرف الحالي' : 'Configured rate';
  String get loadedRows => isArabic ? 'الصفوف المحملة' : 'Loaded rows';
  String rowsLoaded(int count) =>
      isArabic ? '$count عملية' : '$count transactions';
  String get restoreDefaults =>
      isArabic ? 'استعادة الافتراضي' : 'Restore defaults';
  String get settingsSaved => isArabic
      ? 'تم حفظ الإعدادات وتحديث البيانات.'
      : 'Settings saved and refreshed.';
  String get languageTitle => isArabic ? 'اللغة' : 'Language';
  String get english => isArabic ? 'الإنجليزية' : 'English';
  String get arabic => isArabic ? 'العربية' : 'Arabic';
  String get transactionDetails =>
      isArabic ? 'تفاصيل العملية' : 'Transaction details';
  String get editLocally => isArabic ? 'تعديل محلي' : 'Edit locally';
  String get localEditNotice => isArabic
      ? 'هذا التعديل مؤقت داخل التطبيق فقط. عند تحديث البيانات من Google Sheet سيعود السجل كما هو في الجدول.'
      : 'This edit is temporary inside the app only. Refreshing from Google Sheet will restore the sheet version.';
  String get localChangesSaved =>
      isArabic ? 'تم حفظ التعديل محلياً.' : 'Local changes saved.';
  String get save => isArabic ? 'حفظ' : 'Save';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get chooseDateFilter =>
      isArabic ? 'اختر نوع التاريخ' : 'Choose date filter';
  String get singleDay => isArabic ? 'يوم واحد' : 'Single day';
  String get dateRange => isArabic ? 'من تاريخ إلى تاريخ' : 'Date range';
  String get chooseRecentDay =>
      isArabic ? 'اختر يومًا من آخر 3 أيام' : 'Choose one of the last 3 days';
  String get yesterday => isArabic ? 'البارح' : 'Yesterday';
  String get twoDaysAgo => isArabic ? 'قبل يومين' : '2 days ago';
  String get amount => isArabic ? 'المبلغ' : 'Amount';
  String get hasDate => isArabic ? 'يوجد تاريخ' : 'Has date';
  String get overview => isArabic ? 'نظرة عامة' : 'Overview';
  String get originalSheetData =>
      isArabic ? 'بيانات Google Sheet الأصلية' : 'Original Google Sheet data';
  String get type => isArabic ? 'النوع' : 'Type';
  String get description => isArabic ? 'الوصف' : 'Description';
  String get date => isArabic ? 'التاريخ' : 'Date';
  String get paymentMethod => isArabic ? 'طريقة الدفع' : 'Payment method';
  String get notes => isArabic ? 'ملاحظات' : 'Notes';
  String get amountUsd => isArabic ? 'المبلغ بالدولار' : 'Amount USD';
  String get amountLbp => isArabic ? 'المبلغ بالليرة' : 'Amount LBP';
  String get convertedUsd =>
      isArabic ? 'القيمة المحولة للدولار' : 'Converted USD';
  String get sheetColumn => isArabic ? 'عمود الجدول' : 'Sheet column';
  String get value => isArabic ? 'القيمة' : 'Value';

  String timeFilterLabel(dynamic filterName) {
    switch ('$filterName') {
      case 'today':
        return isArabic ? 'اليوم' : 'Today';
      case 'last3Days':
        return isArabic ? 'آخر 3 أيام' : 'Last 3 days';
      case 'thisWeek':
        return isArabic ? 'هذا الأسبوع' : 'This week';
      case 'thisMonth':
        return isArabic ? 'هذا الشهر' : 'This month';
      case 'custom':
        return isArabic ? 'مخصص' : 'Custom';
      case 'allTime':
        return isArabic ? 'كل الوقت' : 'All time';
      default:
        return '$filterName';
    }
  }
}
