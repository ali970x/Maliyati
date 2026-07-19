import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/dashboard_controller.dart';
import '../l10n/app_strings.dart';
import '../services/app_lock_service.dart';
import '../services/google_drive_backup_service.dart';
import '../services/smart_clipboard_service.dart';
import 'smart_clipboard_settings_section.dart';

class AppMenuScreen extends StatelessWidget {
  const AppMenuScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _SettingsWelcomeHeader(controller: controller),
          const SizedBox(height: 14),
          _SettingsCard(
            icon: Icons.cloud_sync_outlined,
            title: 'Google Drive backup',
            subtitle: 'Create, browse and restore cloud backups',
            onTap: () =>
                _open(context, BackupRestoreScreen(controller: controller)),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.lock_outline_rounded,
            title: 'Screen lock',
            subtitle: controller.isAppLockEnabled
                ? 'Fingerprint unlock is on'
                : 'Protect Maliyati with a PIN or fingerprint',
            trailing: Switch(
              value: controller.isAppLockEnabled,
              onChanged: (value) => controller.updateAppLockEnabled(value),
            ),
            onTap: () => _open(context, AppLockScreen(controller: controller)),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.table_chart_outlined,
            title: 'Sheet connection',
            subtitle: 'Save, import or export your sheet data',
            onTap: () =>
                _open(context, SheetConnectionScreen(controller: controller)),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.currency_exchange_rounded,
            title: 'Exchange rate',
            subtitle: 'LBP value used for conversion',
            onTap: () =>
                _open(context, ExchangeRateScreen(controller: controller)),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: controller.themeMode == ThemeMode.dark
                ? 'Dark theme is on'
                : 'Light theme is on',
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
            title: 'Language',
            subtitle: controller.language == AppLanguage.arabic
                ? 'Arabic'
                : 'English',
            onTap: () =>
                _open(context, LanguagePickerScreen(controller: controller)),
          ),
          const SizedBox(height: 12),
          const _FloatingQuickInputSettingsCard(),
          const SizedBox(height: 20),
          _SettingsCard(
            icon: Icons.share_outlined,
            title: 'Share app',
            subtitle: 'Share Maliyati with your friends',
            onTap: () => Share.share('Track your money with Maliyati.'),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.apps_rounded,
            title: 'More applications',
            subtitle: 'Coming soon',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('More apps will be added soon.')),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.info_outline_rounded,
            title: 'About application',
            subtitle: 'Version, privacy and information',
            onTap: () => _open(context, const AboutApplicationScreen()),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              foregroundColor: const Color(0xFF7252B5),
              side: const BorderSide(color: Color(0xFFD7CBED)),
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
            label: const Text(
              'Log out',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
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
                    'Version 1.3.0',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Maliyati helps you manage income, expenses, Cash and Wish Money wallets, backups, and financial insights in one private place.',
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
            title: language == AppLanguage.english ? 'English' : 'العربية',
            subtitle: language == AppLanguage.english
                ? 'Use the app in English'
                : 'استخدم التطبيق باللغة العربية',
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
    icon: Icons.open_in_new_rounded,
    title: 'Floating quick input',
    subtitle: _service.isSupported
        ? (_enabled
              ? 'Floating button is on'
              : 'Show a button above other apps')
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
      ],
    ),
  );
}

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
                'Welcome ${user?.displayName ?? 'Ali Dandash'}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                user?.email ?? 'alimjdandash@gmail.com',
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
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final VoidCallback? onLongPress;
  final bool showChevron;
  final bool avatar;

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
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(avatar ? 22 : 12),
                ),
                child: Icon(icon, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
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
  int _section = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      await widget.controller.createGoogleDriveBackup();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Drive backup created.')),
        );
      }
    } catch (error) {
      if (mounted) {
        final raw = error.toString();
        final message =
            raw.contains('Drive API has not been used') ||
                raw.contains('Drive API is disabled')
            ? 'Google Drive API is disabled for this project. Enable it in Google Cloud, then try again.'
            : raw;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _load() async {
    final local = await widget.controller.localBackups();
    List<GoogleDriveBackupFile> drive = const [];
    try {
      drive = await widget.controller.googleDriveBackups();
    } catch (_) {
      // The local backup list remains usable while Drive is unavailable.
    }
    if (mounted) {
      setState(() {
        _localBackups = local;
        _driveBackups = drive;
      });
    }
  }

  Future<void> _backupLocal() async {
    setState(() => _busy = true);
    try {
      await widget.controller.createLocalBackup();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local backup created on this device.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(GoogleDriveBackupFile backup) async {
    setState(() => _busy = true);
    try {
      final count = await widget.controller.restoreGoogleDriveBackup(backup.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored $count transactions.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restoreLocal(String id) async {
    setState(() => _busy = true);
    try {
      final count = await widget.controller.restoreLocalBackup(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored $count transactions from local backup.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup and Restore')),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _section,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) => setState(() => _section = index),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.cloud_outlined),
                selectedIcon: Icon(Icons.cloud_rounded),
                label: Text('Drive'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.phone_android_outlined),
                selectedIcon: Icon(Icons.phone_android_rounded),
                label: Text('Local'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.restore_rounded),
                selectedIcon: Icon(Icons.restore_rounded),
                label: Text('Restore'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_section == 0) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage:
                            (user?.photoUrl?.trim().isNotEmpty ?? false)
                            ? NetworkImage(user!.photoUrl!)
                            : null,
                        child: (user?.photoUrl?.trim().isNotEmpty ?? false)
                            ? null
                            : const Icon(
                                Icons.account_circle_rounded,
                                size: 34,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Google Drive',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(user?.email ?? 'Connect your Google account'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _BackupRow(
                    title: 'Back up to Google Drive',
                    subtitle: 'Create a secure cloud copy',
                    onTap: _busy ? null : _backup,
                    trailing: _busy
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.cloud_upload_rounded),
                  ),
                  SwitchListTile.adaptive(
                    title: const Text('Auto backup'),
                    subtitle: const Text(
                      'Back up when Maliyati is opened after midnight.',
                    ),
                    value: widget.controller.isAutoBackupEnabled,
                    onChanged: _busy
                        ? null
                        : widget.controller.updateAutoBackupEnabled,
                  ),
                ] else if (_section == 1) ...[
                  const Text(
                    'Local backup',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text('Save a private copy only on this device.'),
                  const SizedBox(height: 20),
                  _BackupRow(
                    title: 'Create local backup',
                    subtitle: 'This device only',
                    onTap: _busy ? null : _backupLocal,
                    trailing: const Icon(Icons.save_alt_rounded),
                  ),
                ] else ...[
                  _BackupRow(
                    title: 'Refresh backups',
                    subtitle: 'Load local and Google Drive backup lists',
                    onTap: _busy ? null : _load,
                    trailing: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Google Drive backups',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  for (final backup in _driveBackups)
                    ListTile(
                      leading: const Icon(Icons.cloud_done_rounded),
                      title: Text(backup.name),
                      trailing: TextButton(
                        onPressed: _busy ? null : () => _restore(backup),
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
                      trailing: TextButton(
                        onPressed: _busy
                            ? null
                            : () => _restoreLocal('${backup['id']}'),
                        child: const Text('Restore'),
                      ),
                    ),
                ],
              ],
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
