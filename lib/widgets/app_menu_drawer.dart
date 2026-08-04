import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../controllers/dashboard_controller.dart';
import '../l10n/app_strings.dart';
import '../models/budget_plan.dart';
import '../models/transaction.dart';
import '../services/app_lock_service.dart';
import '../services/firebase_finance_service.dart';
import '../services/google_drive_backup_service.dart';
import '../services/category_icon_catalog.dart';
import '../services/smart_clipboard_service.dart';
import 'smart_clipboard_settings_section.dart';

class AppMenuScreen extends StatelessWidget {
  const AppMenuScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = controller.language == AppLanguage.arabic;
    String t(String english, String arabic) => isArabic ? arabic : english;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(controller.strings.settings),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _SettingsWelcomeHeader(controller: controller),
          const SizedBox(height: 20),
          _SettingsSectionLabel(
            title: t('Account & security', 'الحساب والأمان'),
          ),
          if (!kIsWeb) ...[
            _SettingsCard(
              icon: Icons.lock_outline_rounded,
              title: t('Screen lock', 'قفل التطبيق'),
              subtitle: controller.isAppLockEnabled
                  ? t('Fingerprint unlock is on', 'فتح التطبيق بالبصمة مفعّل')
                  : t(
                      'Protect Maliyati with your fingerprint',
                      'احمِ ماليّاتي باستخدام البصمة',
                    ),
              trailing: Switch(
                value: controller.isAppLockEnabled,
                onChanged: (value) => controller.updateAppLockEnabled(value),
              ),
              onTap: () =>
                  _open(context, AppLockScreen(controller: controller)),
            ),
            const SizedBox(height: 12),
          ],
          _SettingsCard(
            icon: Icons.person_outline_rounded,
            title: t('Account information', 'معلومات الحساب'),
            subtitle:
                controller.user?.email ?? t('Signed in', 'تم تسجيل الدخول'),
            onTap: () =>
                _open(context, AccountSettingsScreen(controller: controller)),
          ),
          const SizedBox(height: 22),
          _SettingsSectionLabel(title: t('Finance & data', 'المال والبيانات')),
          _SettingsCard(
            icon: Icons.currency_exchange_rounded,
            title: t('Exchange rate', 'سعر الصرف'),
            subtitle: t(
              'LBP value used for USD conversion',
              'قيمة الليرة المستخدمة للتحويل إلى الدولار',
            ),
            onTap: () =>
                _open(context, ExchangeRateScreen(controller: controller)),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.category_rounded,
            title: t('Categories', 'الفئات'),
            subtitle: t(
              'Organize income and expense categories',
              'تنظيم فئات الدخل والمصاريف',
            ),
            onTap: () =>
                _open(context, CategorySettingsScreen(controller: controller)),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.table_chart_outlined,
            title: t('Google Sheet backup', 'نسخة Google Sheet'),
            subtitle: t(
              'Import or export a manual backup',
              'استيراد أو تصدير نسخة احتياطية يدوياً',
            ),
            onTap: () =>
                _open(context, SheetConnectionScreen(controller: controller)),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.cloud_sync_outlined,
            title: t('Google Drive backup', 'نسخة Google Drive'),
            subtitle: t(
              'Create and restore account backups',
              'إنشاء واستعادة نسخ الحساب الاحتياطية',
            ),
            onTap: () =>
                _open(context, BackupRestoreScreen(controller: controller)),
          ),
          const SizedBox(height: 22),
          _SettingsSectionLabel(title: t('Preferences', 'التفضيلات')),
          if (!kIsWeb) ...[
            const _FloatingQuickInputSettingsCard(),
            const SizedBox(height: 12),
          ],
          _SettingsCard(
            icon: Icons.palette_outlined,
            title: t('Appearance', 'المظهر'),
            subtitle: controller.themeMode == ThemeMode.dark
                ? t('Dark theme is on', 'الوضع الداكن مفعّل')
                : t('Light theme is on', 'الوضع الفاتح مفعّل'),
            trailing: Switch(
              value: controller.themeMode == ThemeMode.dark,
              onChanged: (enabled) => controller.updateThemeMode(
                enabled ? ThemeMode.dark : ThemeMode.light,
              ),
            ),
            onTap: () => controller.updateThemeMode(
              controller.themeMode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.language_rounded,
            title: t('Language', 'اللغة'),
            subtitle: controller.language == AppLanguage.arabic
                ? 'العربية'
                : 'English',
            onTap: () =>
                _open(context, LanguagePickerScreen(controller: controller)),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.delete_forever_outlined,
            color: theme.colorScheme.error,
            title: t('Reset account data', 'تصفير بيانات الحساب'),
            subtitle: t(
              'Permanently delete transactions and wallet history',
              'حذف العمليات وسجل المحافظ نهائياً',
            ),
            onTap: () => _confirmResetAccount(context),
          ),
          const SizedBox(height: 22),
          _SettingsSectionLabel(title: t('Application', 'التطبيق')),
          _SettingsCard(
            icon: Icons.share_outlined,
            title: t('Share app', 'مشاركة التطبيق'),
            subtitle: t(
              'Share Maliyati with your team',
              'شارك ماليّاتي مع فريقك',
            ),
            onTap: () => Share.share('Track your money with Maliyati.'),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.apps_rounded,
            title: t('More applications', 'تطبيقات أخرى'),
            subtitle: t('Coming soon', 'قريباً'),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('More apps will be added soon.')),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.info_outline_rounded,
            title: t('About Maliyati', 'عن ماليّاتي'),
            subtitle: t(
              'Version ${AppConfig.fullVersion}',
              'الإصدار ${AppConfig.fullVersion}',
            ),
            onTap: () => _open(context, const AboutApplicationScreen()),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: theme.colorScheme.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () async {
              await controller.signOut();
              if (context.mounted) {
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).popUntil((route) => route.isFirst);
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: Text(
              t('Log out', 'تسجيل الخروج'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _confirmResetAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        title: const Text('Reset this account?'),
        content: const Text(
          'This permanently deletes all transactions from Firebase and resets My Wallet and Whish Money to zero. Your login stays active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await controller.resetAccountData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account reset. Both wallets are zero.'),
          ),
        );
      }
    } on FirebaseFinanceException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class AboutApplicationScreen extends StatelessWidget {
  const AboutApplicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About application')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 42,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Maliyati',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Version ${AppConfig.fullVersion}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _VersionPill(
                        label: 'Flutter',
                        value: AppConfig.fullVersion,
                      ),
                      _VersionPill(
                        label: 'Server',
                        value: AppConfig.fullVersion,
                      ),
                      _VersionPill(
                        label: 'Build',
                        value: AppConfig.buildNumber,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Maliyati helps you manage income, expenses, My Wallet and Whish Money wallets, backups, and financial insights in one private place.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _AboutLinkCard(
            icon: Icons.verified_user_outlined,
            title: 'Privacy',
            text:
                'Your financial data stays in your account. Google Drive backup is created only when you choose it.',
          ),
          const SizedBox(height: 10),
          _AboutLinkCard(
            icon: Icons.description_outlined,
            title: 'Terms of use',
            text:
                'You control the information you enter and the backup services you connect. Maliyati does not provide financial advice.',
          ),
        ],
      ),
    );
  }
}

class _AboutLinkCard extends StatelessWidget {
  const _AboutLinkCard({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF7252B5)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _VersionPill extends StatelessWidget {
  const _VersionPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class LanguagePickerScreen extends StatelessWidget {
  const LanguagePickerScreen({super.key, required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      title: const Text('Language'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final language in AppLanguage.values) ...[
          _SettingsCard(
            icon: language == AppLanguage.english
                ? Icons.language_rounded
                : Icons.translate_rounded,
            title: language == AppLanguage.english
                ? 'English'
                : 'Ø§Ù„Ø¹Ø±Ø¨ÙŠØ©',
            subtitle: language == AppLanguage.english
                ? 'Use the app in English'
                : 'Ø§Ø³ØªØ®Ø¯Ù… Ø§Ù„ØªØ·Ø¨ÙŠÙ‚ Ø¨Ø§Ù„Ù„ØºØ© Ø§Ù„Ø¹Ø±Ø¨ÙŠØ©',
            trailing: controller.language == language
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF7252B5),
                  )
                : const Icon(Icons.circle_outlined, color: Color(0xFF77717D)),
            onTap: () async {
              await controller.updateLanguage(language);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    ),
  );
}

class FloatingQuickInputScreen extends StatelessWidget {
  const FloatingQuickInputScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      title: const Text('Floating quick input'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
    ),
    body: const Padding(
      padding: EdgeInsets.all(16),
      child: SmartClipboardSettingsSection(),
    ),
  );
}

class _FloatingQuickInputSettingsCard extends StatefulWidget {
  const _FloatingQuickInputSettingsCard();

  @override
  State<_FloatingQuickInputSettingsCard> createState() =>
      _FloatingQuickInputSettingsCardState();
}

class _FloatingQuickInputSettingsCardState
    extends State<_FloatingQuickInputSettingsCard> {
  final _service = SmartClipboardService.instance;
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _service.isEnabled;
    if (mounted)
      setState(() {
        _enabled = enabled;
        _loading = false;
      });
  }

  Future<void> _setEnabled(bool enabled) async {
    if (enabled &&
        _service.isSupported &&
        !await _service.requestOverlayPermission()) {
      return;
    }
    await _service.setEnabled(enabled);
    if (mounted) setState(() => _enabled = enabled);
  }

  @override
  Widget build(BuildContext context) => _SettingsCard(
    icon: Icons.translate_rounded,
    title: 'Floating script button',
    subtitle: _service.isSupported
        ? (_enabled
              ? 'On: tap it to paste clipboard into Input by script'
              : 'Show a Google Translate style button above other apps')
        : 'Available on Android only',
    trailing: Switch(
      value: _enabled,
      onChanged: _loading || !_service.isSupported ? null : _setEnabled,
    ),
    onTap: () => _setEnabled(!_enabled),
    onLongPress: () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FloatingQuickInputScreen())),
  );
}

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key, required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
    return _PlainSettingsScaffold(
      title: 'Account',
      child: Column(
        children: [
          _SettingsCard(
            icon: Icons.person_outline_rounded,
            title: user?.displayName ?? 'Your account',
            subtitle: user?.email ?? 'Signed in to Maliyati',
            showChevron: false,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Account privacy',
            subtitle: 'Your transactions are private to your account',
            showChevron: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _LegacyCategorySettingsScreen extends StatefulWidget {
  const _LegacyCategorySettingsScreen({required this.controller});

  final DashboardController controller;

  @override
  State<_LegacyCategorySettingsScreen> createState() =>
      _LegacyCategorySettingsScreenState();
}

class _LegacyCategorySettingsScreenState
    extends State<_LegacyCategorySettingsScreen> {
  late List<CategoryRule> _rules;
  final _newNameController = TextEditingController();
  final Set<TransactionType> _newStatuses = {TransactionType.expense};

  @override
  void initState() {
    super.initState();
    _rules = widget.controller.categoryRules.toList();
  }

  @override
  void dispose() {
    _newNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFD8E2EA)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add category',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newNameController,
                    decoration: const InputDecoration(
                      labelText: 'Category name',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StatusPicker(
                    selected: _newStatuses,
                    onChanged: (values) =>
                        setState(() => _replaceStatuses(_newStatuses, values)),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _addCategory,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add category'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < _rules.length; index += 1) ...[
            _CategoryRuleCard(
              key: ValueKey('${_rules[index].name}-$index'),
              rule: _rules[index],
              onChanged: (rule) => _updateRule(index, rule),
              onDelete: () => _deleteRule(index),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  void _addCategory() {
    final name = _newNameController.text.trim();
    if (name.isEmpty || _newStatuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name and choose a status.')),
      );
      return;
    }
    if (_rules.any((rule) => rule.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This category already exists.')),
      );
      return;
    }
    setState(() {
      _rules = [
        ..._rules,
        CategoryRule(
          name: name,
          statuses: {..._newStatuses},
          budgetBucket: BudgetBucketDetails.infer(name, _newStatuses),
        ),
      ]..sort((a, b) => a.name.compareTo(b.name));
      _newNameController.clear();
      _newStatuses
        ..clear()
        ..add(TransactionType.expense);
    });
    _save();
  }

  void _updateRule(int index, CategoryRule rule) {
    setState(() {
      _rules[index] = rule;
      _rules.sort((a, b) => a.name.compareTo(b.name));
    });
    _save();
  }

  void _deleteRule(int index) {
    setState(() => _rules.removeAt(index));
    _save();
  }

  void _replaceStatuses(
    Set<TransactionType> target,
    Set<TransactionType> values,
  ) {
    target
      ..clear()
      ..addAll(values);
  }

  Future<void> _save() => widget.controller.saveCategoryRules(_rules);
}

class _CategoryRuleCard extends StatefulWidget {
  const _CategoryRuleCard({
    super.key,
    required this.rule,
    required this.onChanged,
    required this.onDelete,
  });

  final CategoryRule rule;
  final ValueChanged<CategoryRule> onChanged;
  final VoidCallback onDelete;

  @override
  State<_CategoryRuleCard> createState() => _CategoryRuleCardState();
}

class _CategoryRuleCardState extends State<_CategoryRuleCard> {
  late final TextEditingController _nameController;
  late Set<TransactionType> _statuses;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rule.name);
    _statuses = {...widget.rule.statuses};
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFD8E2EA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _emitChange(),
                    onEditingComplete: _emitChange,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _StatusPicker(
              selected: _statuses,
              onChanged: (values) {
                setState(() => _statuses = values);
                _emitChange();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _emitChange() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _statuses.isEmpty) return;
    widget.onChanged(
      CategoryRule(
        name: name,
        statuses: _statuses,
        colorValue: widget.rule.effectiveColorValue,
        budgetBucket: widget.rule.effectiveBudgetBucket,
        budgetExcluded: widget.rule.budgetExcluded,
      ),
    );
  }
}

class _StatusPicker extends StatelessWidget {
  const _StatusPicker({required this.selected, required this.onChanged});

  final Set<TransactionType> selected;
  final ValueChanged<Set<TransactionType>> onChanged;

  static const _types = [
    TransactionType.expense,
    TransactionType.income,
    TransactionType.reserveable,
    TransactionType.debt,
    TransactionType.transfer,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in _types)
          FilterChip(
            label: Text(type.label),
            selected: selected.contains(type),
            onSelected: (isSelected) {
              final next = {...selected};
              if (isSelected) {
                next.add(type);
              } else {
                next.remove(type);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class SheetConnectionScreen extends StatefulWidget {
  const SheetConnectionScreen({super.key, required this.controller});
  final DashboardController controller;

  @override
  State<SheetConnectionScreen> createState() => _SheetConnectionScreenState();
}

class _SheetConnectionScreenState extends State<SheetConnectionScreen> {
  late final TextEditingController _sheet;
  late final TextEditingController _endpoint;
  late final TextEditingController _secret;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sheet = TextEditingController(text: widget.controller.sheetUrl);
    _endpoint = TextEditingController(
      text: widget.controller.sheetExportEndpoint,
    );
    _secret = TextEditingController(text: widget.controller.sheetExportSecret);
  }

  @override
  void dispose() {
    _sheet.dispose();
    _endpoint.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.controller.updateSettings(
      sheetUrl: _sheet.text,
      sheetExportEndpoint: _endpoint.text,
      sheetExportSecret: _secret.text,
      exchangeRate: widget.controller.exchangeRate,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sheet connection saved.')));
  }

  Future<void> _runSheetAction(Future<int> Function() action) async {
    setState(() => _saving = true);
    try {
      final count = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count transactions completed successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google Sheet error: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _PlainSettingsScaffold(
    title: 'Sheet connection',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Add both links to connect your sheet for importing and exporting.',
          style: TextStyle(color: Color(0xFF77717D)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _sheet,
          maxLines: 3,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Google Sheet link',
            hintText: 'https://docs.google.com/spreadsheets/...',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _endpoint,
          maxLines: 3,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Apps Script Web App URL',
            hintText: 'https://script.google.com/macros/s/.../exec',
          ),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Advanced connection'),
          subtitle: const Text('Optional security key'),
          children: [
            TextField(
              controller: _secret,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Connection secret (optional)',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Save connection'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _saving
              ? null
              : () => _runSheetAction(
                  widget.controller.importGoogleSheetToFirestore,
                ),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Import from Google Sheet'),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: _saving
              ? null
              : () => _runSheetAction(
                  widget.controller.exportCurrentTransactionsToSheet,
                ),
          icon: const Icon(Icons.upload_rounded),
          label: const Text('Export to Google Sheet'),
        ),
      ],
    ),
  );
}

class CategorySettingsScreen extends StatefulWidget {
  const CategorySettingsScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<CategorySettingsScreen> createState() => _CategorySettingsScreenState();
}

class _CategorySettingsScreenState extends State<CategorySettingsScreen> {
  late List<_EditableCategoryRule> _rules;

  static const _statusOptions = [
    TransactionType.expense,
    TransactionType.income,
    TransactionType.reserveable,
    TransactionType.debt,
    TransactionType.transfer,
  ];

  @override
  void initState() {
    super.initState();
    _rules = widget.controller.categoryRules
        .map(
          (rule) => _EditableCategoryRule(
            controller: TextEditingController(text: rule.name),
            statuses: {...rule.statuses},
            colorValue: rule.effectiveColorValue,
            icon: CategoryIconCatalog.iconFor(rule.name, savedIcon: rule.icon),
            budgetBucket: rule.effectiveBudgetBucket,
            budgetExcluded: rule.budgetExcluded,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final rule in _rules) {
      rule.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    await widget.controller.saveCategoryRules(
      _rules
          .map(
            (rule) => CategoryRule(
              name: rule.controller.text,
              statuses: rule.statuses,
              colorValue: rule.colorValue,
              icon: rule.icon,
              budgetBucket: rule.budgetBucket,
              budgetExcluded: rule.budgetExcluded,
            ),
          )
          .toList(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Categories saved.')));
  }

  void _addCategory() {
    setState(() {
      _rules.insert(
        0,
        _EditableCategoryRule(
          controller: TextEditingController(),
          statuses: {TransactionType.expense},
          colorValue: CategoryRule
              .colorPalette[_rules.length % CategoryRule.colorPalette.length],
          budgetBucket: BudgetBucket.expenses,
          budgetExcluded: false,
          icon: '🏷️',
        ),
      );
    });
  }

  void _removeCategory(int index) {
    setState(() {
      final removed = _rules.removeAt(index);
      removed.controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final counts = widget.controller.categoryTransactionCounts;
    return _PlainSettingsScaffold(
      title: 'Categories',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Choose where every category appears and which 33/33/34 budget group it belongs to.',
            style: TextStyle(color: Color(0xFF77717D)),
          ),
          const SizedBox(height: 10),
          const _BudgetGroupLegend(),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _addCategory,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add category'),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < _rules.length; index += 1) ...[
            _CategoryRuleEditor(
              rule: _rules[index],
              transactionCount:
                  counts[_rules[index].controller.text.trim().toLowerCase()] ??
                  0,
              statusOptions: _statusOptions,
              onChanged: () => setState(() {}),
              onRemove: () => _removeCategory(index),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save categories'),
          ),
        ],
      ),
    );
  }
}

class _EditableCategoryRule {
  _EditableCategoryRule({
    required this.controller,
    required this.statuses,
    required this.colorValue,
    required this.budgetBucket,
    required this.budgetExcluded,
    required this.icon,
  });

  final TextEditingController controller;
  final Set<TransactionType> statuses;
  final int colorValue;
  BudgetBucket budgetBucket;
  bool budgetExcluded;
  String icon;
}

class _CategoryRuleEditor extends StatelessWidget {
  const _CategoryRuleEditor({
    required this.rule,
    required this.transactionCount,
    required this.statusOptions,
    required this.onChanged,
    required this.onRemove,
  });

  final _EditableCategoryRule rule;
  final int transactionCount;
  final List<TransactionType> statusOptions;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E0EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: rule.controller,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Category name',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => CategoryIconPicker(
                selected: rule.icon,
                onSelected: (icon) {
                  rule.icon = icon;
                  onChanged();
                  Navigator.pop(context);
                },
              ),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(rule.icon, style: const TextStyle(fontSize: 25)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Category icon (optional)',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Icon(Icons.grid_view_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: Color(0xFF49657C),
                ),
                const SizedBox(width: 7),
                Text(
                  '$transactionCount ${transactionCount == 1 ? 'transaction' : 'transactions'}',
                  style: const TextStyle(
                    color: Color(0xFF49657C),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in statusOptions)
                FilterChip(
                  label: Text(status.label),
                  selected: rule.statuses.contains(status),
                  onSelected: (selected) {
                    if (selected) {
                      rule.statuses.add(status);
                    } else {
                      rule.statuses.remove(status);
                    }
                    onChanged();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Budget group',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final bucket in BudgetBucket.values)
                FilterChip(
                  avatar: Icon(
                    _budgetBucketIcon(bucket),
                    size: 17,
                    color: Color(bucket.colorValue),
                  ),
                  label: Text('${bucket.label} ${bucket.percentage}%'),
                  selected: !rule.budgetExcluded && rule.budgetBucket == bucket,
                  selectedColor: Color(
                    bucket.colorValue,
                  ).withValues(alpha: .14),
                  side: BorderSide(
                    color: !rule.budgetExcluded && rule.budgetBucket == bucket
                        ? Color(bucket.colorValue)
                        : const Color(0xFFD7DCE3),
                  ),
                  onSelected: (_) {
                    rule.budgetExcluded = false;
                    rule.budgetBucket = bucket;
                    onChanged();
                  },
                ),
              FilterChip(
                avatar: const Icon(
                  Icons.remove_circle_outline_rounded,
                  size: 17,
                ),
                label: const Text('Not in plan'),
                selected: rule.budgetExcluded,
                onSelected: (_) {
                  rule.budgetExcluded = true;
                  onChanged();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetGroupLegend extends StatelessWidget {
  const _BudgetGroupLegend();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E7EE)),
    ),
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final bucket in BudgetBucket.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _budgetBucketIcon(bucket),
                size: 18,
                color: Color(bucket.colorValue),
              ),
              const SizedBox(width: 5),
              Text(
                '${bucket.label} ${bucket.percentage}%',
                style: TextStyle(
                  color: Color(bucket.colorValue),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

IconData _budgetBucketIcon(BudgetBucket bucket) => switch (bucket) {
  BudgetBucket.investment => Icons.trending_up_rounded,
  BudgetBucket.commitments => Icons.event_repeat_rounded,
  BudgetBucket.expenses => Icons.shopping_bag_outlined,
};

class ExchangeRateScreen extends StatefulWidget {
  const ExchangeRateScreen({super.key, required this.controller});
  final DashboardController controller;

  @override
  State<ExchangeRateScreen> createState() => _ExchangeRateScreenState();
}

class _ExchangeRateScreenState extends State<ExchangeRateScreen> {
  late final TextEditingController _rate;
  @override
  void initState() {
    super.initState();
    _rate = TextEditingController(
      text: widget.controller.exchangeRate.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rate = double.tryParse(_rate.text.replaceAll(',', '').trim());
    if (rate == null || rate <= 0) return;
    await widget.controller.updateSettings(
      sheetUrl: widget.controller.sheetUrl,
      sheetExportEndpoint: widget.controller.sheetExportEndpoint,
      sheetExportSecret: widget.controller.sheetExportSecret,
      exchangeRate: rate,
    );
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Exchange rate saved.')));
  }

  @override
  Widget build(BuildContext context) => _PlainSettingsScaffold(
    title: 'Exchange rate',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Used to convert LBP values to USD.',
          style: TextStyle(color: Color(0xFF77717D)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _rate,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'LBP for 1 USD',
            prefixIcon: Icon(Icons.currency_exchange_rounded),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Save exchange rate'),
        ),
      ],
    ),
  );
}

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key, required this.controller});
  final DashboardController controller;
  @override
  Widget build(BuildContext context) => _PlainSettingsScaffold(
    title: 'Appearance',
    child: _SettingsCard(
      icon: Icons.dark_mode_outlined,
      title: 'Dark theme',
      subtitle: 'Use the darker Maliyati appearance',
      trailing: Switch(
        value: controller.themeMode == ThemeMode.dark,
        onChanged: (enabled) => controller.updateThemeMode(
          enabled ? ThemeMode.dark : ThemeMode.light,
        ),
      ),
      onTap: () {},
    ),
  );
}

class _PlainSettingsScaffold extends StatelessWidget {
  const _PlainSettingsScaffold({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      title: Text(title),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    body: ListView(padding: const EdgeInsets.all(16), children: [child]),
  );
}

class _SettingsWelcomeHeader extends StatelessWidget {
  const _SettingsWelcomeHeader({required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
    final theme = Theme.of(context);
    final isArabic = controller.language == AppLanguage.arabic;
    final displayName = user?.displayName?.trim() ?? '';
    final email = user?.email?.trim() ?? '';
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          foregroundColor: theme.colorScheme.onSurface,
          backgroundImage: (user?.photoUrl?.trim().isNotEmpty ?? false)
              ? NetworkImage(user!.photoUrl!)
              : null,
          child: (user?.photoUrl?.trim().isNotEmpty ?? false)
              ? null
              : const Icon(Icons.person_rounded, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName.isNotEmpty
                    ? displayName
                    : controller.strings.appName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                email.isNotEmpty
                    ? email
                    : (isArabic ? 'تم تسجيل الدخول' : 'Signed in'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({required this.title, this.color});

  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: color ?? theme.colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.onLongPress,
    this.showChevron = true,
    this.avatar = false,
    this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final VoidCallback? onLongPress;
  final bool showChevron;
  final bool avatar;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: avatar ? 44 : 40,
                height: avatar ? 44 : 40,
                decoration: BoxDecoration(
                  color:
                      color?.withValues(alpha: 0.1) ??
                      theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(avatar ? 22 : 12),
                ),
                child: Icon(icon, color: color ?? theme.colorScheme.onSurface),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color ?? theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThemeGalleryScreen extends StatelessWidget {
  const ThemeGalleryScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Themes')),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 14,
          childAspectRatio: .68,
        ),
        itemCount: AppThemeStyle.values.length,
        itemBuilder: (context, index) {
          final style = AppThemeStyle.values[index];
          final selected = style == controller.themeStyle;
          return _ThemePreview(
            style: style,
            selected: selected,
            onApply: () => controller.updateThemeStyle(style),
          );
        },
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({
    required this.style,
    required this.selected,
    required this.onApply,
  });

  final AppThemeStyle style;
  final bool selected;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final color = style.seedColor;
    final dark = style.isDark;
    final background = dark
        ? Color.alphaBlend(
            color.withValues(alpha: .35),
            const Color(0xFF12131B),
          )
        : Color.alphaBlend(color.withValues(alpha: .16), Colors.white);
    final foreground = dark ? Colors.white : const Color(0xFF25242B);
    return Column(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onApply,
            child: Container(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? color : color.withValues(alpha: .28),
                  width: selected ? 3 : 1,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => Column(
                  children: [
                    Container(
                      height: constraints.maxHeight * .31,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(19),
                        ),
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: .45)],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: foreground.withValues(alpha: .20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 9),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: foreground.withValues(alpha: .09),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: foreground.withValues(alpha: .09),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          style.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        selected
            ? CircleAvatar(
                radius: 16,
                backgroundColor: color,
                foregroundColor: Colors.white,
                child: const Icon(Icons.check_rounded),
              )
            : SizedBox(
                height: 36,
                child: FilledButton.tonal(
                  onPressed: onApply,
                  child: const Text('APPLY'),
                ),
              ),
      ],
    );
  }
}

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _lock = AppLockService();
  bool _busy = false;

  Future<void> _changeLock(bool enabled) async {
    setState(() => _busy = true);
    try {
      if (enabled) {
        if (!await _lock.authenticate()) return;
      }
      await widget.controller.updateAppLockEnabled(enabled);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.controller.isAppLockEnabled;
    return Scaffold(
      appBar: AppBar(title: const Text('App Lock')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.lock_rounded,
            size: 82,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Protect your financial data',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            'Choose how you want to unlock the app after returning to it.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 34),
          Card(
            child: SwitchListTile.adaptive(
              value: enabled,
              onChanged: _busy ? null : _changeLock,
              title: const Text(
                'App lock',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                enabled ? 'App lock is active.' : 'Turn on a secure app lock.',
              ),
              secondary: const Icon(Icons.shield_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Unlock method',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          _LockMethodTile(
            icon: Icons.fingerprint_rounded,
            title: 'Fingerprint',
            subtitle: 'Use the fingerprint saved on this device.',
            selected: true,
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _LockMethodTile extends StatelessWidget {
  const _LockMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: selected ? theme.colorScheme.primary : null),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: selected ? theme.colorScheme.primary : null,
        ),
      ),
    );
  }
}

class _SetPinDialog extends StatefulWidget {
  const _SetPinDialog();
  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  final _first = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _first.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    final pin = _first.text.trim();
    if (!RegExp(r'^\\d{4,8}$').hasMatch(pin)) {
      setState(() => _error = 'Use 4 to 8 digits.');
    } else if (pin != _confirm.text.trim()) {
      setState(() => _error = 'The PIN codes do not match.');
    } else {
      Navigator.of(context).pop(pin);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Set PIN code'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _first,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          decoration: const InputDecoration(labelText: 'New PIN'),
        ),
        TextField(
          controller: _confirm,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          decoration: InputDecoration(
            labelText: 'Confirm PIN',
            errorText: _error,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save PIN')),
    ],
  );
}

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  List<GoogleDriveBackupFile> _driveBackups = const [];
  List<Map<String, dynamic>> _localBackups = const [];
  bool _busy = false;
  double _progress = 0;
  String _progressLabel = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _backup() async {
    setState(() {
      _busy = true;
      _progress = .15;
      _progressLabel = 'Preparing Google Drive backup...';
    });
    try {
      setState(() {
        _progress = .55;
        _progressLabel = 'Uploading to Google Drive...';
      });
      await widget.controller.createGoogleDriveBackup();
      await _load();
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _progressLabel = 'Google Drive backup complete';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Drive backup created.')),
      );
    } catch (error) {
      if (!mounted) return;
      final raw = error.toString();
      final message =
          raw.contains('Drive API has not been used') ||
              raw.contains('Drive API is disabled')
          ? 'Google Drive API is disabled for this project. Enable it in Google Cloud, then try again.'
          : raw;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleAutoBackup(bool enabled) async {
    setState(() {
      _busy = true;
      _progress = enabled ? .2 : 0;
      _progressLabel = enabled
          ? 'Connecting Google Drive and creating the first backup...'
          : 'Automatic backup disabled';
    });
    try {
      await widget.controller.updateAutoBackupEnabled(enabled);
      if (!mounted) return;
      setState(() {
        _progress = enabled ? 1 : 0;
        _progressLabel = enabled
            ? 'Automatic Google Drive backup is active'
            : 'Automatic backup disabled';
      });
      if (enabled) {
        await _load();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Auto backup is active and the first backup was created.'
                : 'Auto backup is off.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _progress = 0;
        _progressLabel = 'Google Drive backup could not be completed';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupLocal() async {
    setState(() {
      _busy = true;
      _progress = .15;
      _progressLabel = 'Preparing local backup...';
    });
    try {
      final now = DateTime.now().toIso8601String().replaceAll(':', '-');
      final json = widget.controller.createBackupJson();
      setState(() {
        _progress = .55;
        _progressLabel = 'Choose where to save the backup...';
      });
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Maliyati backup',
        fileName: 'maliyati-backup-$now.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(json)),
      );
      if (savedPath == null) return;
      await widget.controller.createLocalBackup();
      await _load();
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _progressLabel = 'Local backup saved successfully';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local backup saved successfully.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final local = await widget.controller.localBackups();
    List<GoogleDriveBackupFile> drive = const [];
    try {
      drive = await widget.controller.googleDriveBackups();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _localBackups = local;
      _driveBackups = drive;
    });
  }

  Future<void> _restoreDriveBackup(GoogleDriveBackupFile backup) async {
    setState(() {
      _busy = true;
      _progress = .45;
      _progressLabel = 'Restoring Google Drive backup...';
    });
    try {
      final count = await widget.controller.restoreGoogleDriveBackup(backup.id);
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _progressLabel = 'Restored $count transactions';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restored $count transactions.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreLocal(String id) async {
    setState(() {
      _busy = true;
      _progress = .45;
      _progressLabel = 'Restoring local backup...';
    });
    try {
      final count = await widget.controller.restoreLocalBackup(id);
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _progressLabel = 'Restored $count transactions';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored $count transactions from local backup.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _browseBackupFile({required bool fromGoogleDrive}) async {
    setState(() {
      _busy = true;
      _progress = .2;
      _progressLabel = fromGoogleDrive
          ? 'Open Google Drive and choose a Maliyati backup...'
          : 'Choose a local Maliyati backup...';
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: fromGoogleDrive
            ? 'Choose Maliyati backup from Google Drive'
            : 'Choose local Maliyati backup',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      final bytes = result?.files.single.bytes;
      if (bytes == null) return;
      setState(() {
        _progress = .65;
        _progressLabel = fromGoogleDrive
            ? 'Restoring Google Drive backup...'
            : 'Restoring local backup...';
      });
      final count = await widget.controller.restoreBackupJson(
        utf8.decode(bytes),
      );
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _progressLabel = 'Restored $count transactions';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fromGoogleDrive
                ? 'Restored $count transactions from Google Drive file.'
                : 'Restored $count transactions from local file.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseRestoreSource() => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.cloud_download_rounded),
            title: const Text('Restore Google Drive Backup'),
            subtitle: const Text('Open Drive and choose a JSON backup file'),
            onTap: () {
              Navigator.pop(sheetContext);
              _browseBackupFile(fromGoogleDrive: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_rounded),
            title: const Text('Restore Local Backup'),
            subtitle: const Text('Choose a JSON backup from this device'),
            onTap: () {
              Navigator.pop(sheetContext);
              _browseBackupFile(fromGoogleDrive: false);
            },
          ),
        ],
      ),
    ),
  );

  Future<void> _chooseBackupTarget() => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.cloud_upload_rounded),
            title: const Text('Backup to Google Drive'),
            subtitle: const Text('Upload a cloud copy to your account'),
            onTap: () {
              Navigator.pop(sheetContext);
              _backup();
            },
          ),
          ListTile(
            leading: const Icon(Icons.save_alt_rounded),
            title: const Text('Local Backup'),
            subtitle: const Text('Save a JSON file on this device'),
            onTap: () {
              Navigator.pop(sheetContext);
              _backupLocal();
            },
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup and Restore')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_progressLabel.isNotEmpty) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(_progressLabel),
            const SizedBox(height: 16),
          ],
          _BackupRow(
            title: 'Backup',
            subtitle: 'Choose Google Drive or local file',
            onTap: _busy ? null : _chooseBackupTarget,
            trailing: _busy
                ? const CircularProgressIndicator()
                : const Icon(Icons.backup_rounded),
          ),
          const SizedBox(height: 12),
          _BackupRow(
            title: 'Restore Backup',
            subtitle: 'Choose Google Drive Backup or Local Backup',
            onTap: _busy ? null : _chooseRestoreSource,
            trailing: const Icon(Icons.folder_open_rounded),
          ),
          const SizedBox(height: 12),
          _BackupRow(
            title: 'Refresh Backups',
            subtitle: 'Load backup lists again',
            onTap: _busy ? null : _load,
            trailing: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            title: const Text('Auto backup'),
            subtitle: const Text(
              'Create one Google Drive backup daily and retry after changes.',
            ),
            value: widget.controller.isAutoBackupEnabled,
            onChanged: _busy ? null : _toggleAutoBackup,
          ),
          if (widget.controller.lastAutoBackup != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.cloud_done_rounded),
              title: const Text('Last automatic backup'),
              subtitle: Text(
                widget.controller.lastAutoBackup!.toLocal().toString(),
              ),
            ),
          if (widget.controller.lastAutoBackupError != null)
            ListTile(
              dense: true,
              leading: Icon(
                Icons.cloud_off_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Automatic backup needs attention'),
              subtitle: Text(widget.controller.lastAutoBackupError!),
            ),
          const SizedBox(height: 16),
          const Text(
            'Google Drive backups',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          for (final backup in _driveBackups)
            ListTile(
              leading: const Icon(Icons.cloud_done_rounded),
              title: Text(backup.name),
              subtitle: Text(backup.modifiedAt?.toLocal().toString() ?? ''),
              trailing: TextButton(
                onPressed: _busy ? null : () => _restoreDriveBackup(backup),
                child: const Text('Restore'),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Local backups',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          for (final backup in _localBackups)
            ListTile(
              leading: const Icon(Icons.phone_android_rounded),
              title: Text('${backup['label'] ?? 'Local backup'}'),
              subtitle: Text('${backup['savedAt'] ?? ''}'),
              trailing: TextButton(
                onPressed: _busy
                    ? null
                    : () => _restoreLocal('${backup['id']}'),
                child: const Text('Restore'),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackupRow extends StatelessWidget {
  const _BackupRow({
    required this.title,
    required this.subtitle,
    this.onTap,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    title: Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(subtitle),
    ),
    trailing: trailing,
    onTap: onTap,
  );
}
