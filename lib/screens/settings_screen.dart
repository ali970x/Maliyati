import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../l10n/app_strings.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/smart_clipboard_settings_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _sheetUrlController;
  final _sheetFormKey = GlobalKey<FormState>();
  bool _isSavingSheet = false;
  bool _isImporting = false;
  bool _isExporting = false;
  int _sheetCompleted = 0;
  int _sheetTotal = 0;
  String _sheetProgressLabel = '';
  DateTime? _sheetStartedAt;

  DashboardController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _sheetUrlController = TextEditingController(text: controller.sheetUrl);
  }

  @override
  void dispose() {
    _sheetUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: AppResponsive.pagePadding(context),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppResponsive.isWideWeb(context)
                    ? 980
                    : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Settings',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _showSideSettings,
                        tooltip: 'Settings',
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AccountSection(controller: controller),
                  if (controller.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _MessageBox(
                      message: controller.errorMessage!,
                      isError: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSheetSettings() async {
    if (!_sheetFormKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSavingSheet = true);
    try {
      await controller.updateSettings(
        sheetUrl: _sheetUrlController.text,
        sheetExportEndpoint: controller.sheetExportEndpoint,
        sheetExportSecret: controller.sheetExportSecret,
        exchangeRate: controller.exchangeRate,
      );
      _showMessage('Google Sheet settings saved.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSavingSheet = false);
      }
    }
  }

  Future<void> _importSheet() async {
    if (!_sheetFormKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isImporting = true;
      _sheetCompleted = 0;
      _sheetTotal = 0;
      _sheetProgressLabel = 'Reading Google Sheet';
      _sheetStartedAt = DateTime.now();
    });
    try {
      await controller.updateSettings(
        sheetUrl: _sheetUrlController.text,
        sheetExportEndpoint: controller.sheetExportEndpoint,
        sheetExportSecret: controller.sheetExportSecret,
        exchangeRate: controller.exchangeRate,
      );
      final count = await controller.importGoogleSheetToFirestore(
        onProgress: _updateSheetProgress,
      );
      _showMessage(
        'Imported $count rows from Google Sheet. Your Firestore data was replaced.',
      );
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _sheetProgressLabel = '';
        });
      }
    }
  }

  Future<void> _exportSheet() async {
    if (!_sheetFormKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isExporting = true;
      _sheetCompleted = 0;
      _sheetTotal = controller.transactions.length;
      _sheetProgressLabel = 'Preparing export';
      _sheetStartedAt = DateTime.now();
    });
    try {
      await controller.updateSettings(
        sheetUrl: _sheetUrlController.text,
        sheetExportEndpoint: controller.sheetExportEndpoint,
        sheetExportSecret: controller.sheetExportSecret,
        exchangeRate: controller.exchangeRate,
      );
      final count = await controller.exportCurrentTransactionsToSheet(
        onProgress: _updateSheetProgress,
      );
      _showMessage('Exported $count rows to Google Sheet.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _sheetProgressLabel = '';
        });
      }
    }
  }

  void _updateSheetProgress(int completed, int total, String label) {
    if (!mounted) {
      return;
    }
    setState(() {
      _sheetCompleted = completed;
      _sheetTotal = total;
      _sheetProgressLabel = label;
      _sheetStartedAt ??= DateTime.now();
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSideSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SheetSideSettings(
        controller: controller,
        sheetFormKey: _sheetFormKey,
        sheetUrlController: _sheetUrlController,
        isSavingSheet: _isSavingSheet,
        isImporting: _isImporting,
        isExporting: _isExporting,
        onSaveSheet: _saveSheetSettings,
        onImportSheet: _importSheet,
        onExportSheet: _exportSheet,
        sheetProgress: _SheetOperationProgress(
          active: _isImporting || _isExporting,
          mode: _isImporting ? 'Importing' : 'Exporting',
          completed: _sheetCompleted,
          total: _sheetTotal,
          label: _sheetProgressLabel,
          startedAt: _sheetStartedAt,
        ),
      ),
    );
  }
}

class SettingsDrawer extends StatefulWidget {
  const SettingsDrawer({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  late final TextEditingController _sheetUrlController;
  late final TextEditingController _rateController;
  final _sheetFormKey = GlobalKey<FormState>();
  final _rateFormKey = GlobalKey<FormState>();
  _SettingsPane _selectedPane = _SettingsPane.sheetConnection;
  bool _isSavingSheet = false;
  bool _isImporting = false;
  bool _isExporting = false;
  bool _isSavingRate = false;
  int _sheetCompleted = 0;
  int _sheetTotal = 0;
  String _sheetProgressLabel = '';
  DateTime? _sheetStartedAt;

  DashboardController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _sheetUrlController = TextEditingController(text: controller.sheetUrl);
    _rateController = TextEditingController(
      text: controller.exchangeRate.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _sheetUrlController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final drawerWidth = MediaQuery.sizeOf(
      context,
    ).width.clamp(320.0, 420.0).toDouble();
    return Drawer(
      width: drawerWidth,
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerAccountHeader(controller: controller),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
              child: _SettingsSideMenu(
                selected: _selectedPane,
                onSelected: (pane) => setState(() => _selectedPane = pane),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 104),
                children: [_selectedPaneContent()],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.72,
                    ),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: TextButton.icon(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size.fromHeight(46),
                    foregroundColor: theme.colorScheme.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await controller.signOut();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSheetSettings() async {
    if (!_sheetFormKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSavingSheet = true);
    try {
      await controller.updateSettings(
        sheetUrl: _sheetUrlController.text,
        sheetExportEndpoint: controller.sheetExportEndpoint,
        sheetExportSecret: controller.sheetExportSecret,
        exchangeRate: controller.exchangeRate,
      );
      _showMessage('Google Sheet settings saved.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSavingSheet = false);
      }
    }
  }

  Future<void> _importSheet() async {
    if (!_sheetFormKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isImporting = true;
      _sheetCompleted = 0;
      _sheetTotal = 0;
      _sheetProgressLabel = 'Reading Google Sheet';
      _sheetStartedAt = DateTime.now();
    });
    try {
      await controller.updateSettings(
        sheetUrl: _sheetUrlController.text,
        sheetExportEndpoint: controller.sheetExportEndpoint,
        sheetExportSecret: controller.sheetExportSecret,
        exchangeRate: controller.exchangeRate,
      );
      final count = await controller.importGoogleSheetToFirestore(
        onProgress: _updateSheetProgress,
      );
      _showMessage(
        'Imported $count rows from Google Sheet. Your Firestore data was replaced.',
      );
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _sheetProgressLabel = '';
        });
      }
    }
  }

  Future<void> _exportSheet() async {
    if (!_sheetFormKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isExporting = true;
      _sheetCompleted = 0;
      _sheetTotal = controller.transactions.length;
      _sheetProgressLabel = 'Preparing export';
      _sheetStartedAt = DateTime.now();
    });
    try {
      await controller.updateSettings(
        sheetUrl: _sheetUrlController.text,
        sheetExportEndpoint: controller.sheetExportEndpoint,
        sheetExportSecret: controller.sheetExportSecret,
        exchangeRate: controller.exchangeRate,
      );
      final count = await controller.exportCurrentTransactionsToSheet(
        onProgress: _updateSheetProgress,
      );
      _showMessage('Exported $count rows to Google Sheet.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _sheetProgressLabel = '';
        });
      }
    }
  }

  Future<void> _saveExchangeRate() async {
    if (!_rateFormKey.currentState!.validate()) {
      return;
    }
    final parsed = double.parse(
      _rateController.text.replaceAll(',', '').trim(),
    );
    setState(() => _isSavingRate = true);
    try {
      await controller.updateSettings(
        sheetUrl: controller.sheetUrl,
        sheetExportEndpoint: controller.sheetExportEndpoint,
        sheetExportSecret: controller.sheetExportSecret,
        exchangeRate: parsed,
      );
      _showMessage('Exchange rate saved.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSavingRate = false);
      }
    }
  }

  void _updateSheetProgress(int completed, int total, String label) {
    if (!mounted) {
      return;
    }
    setState(() {
      _sheetCompleted = completed;
      _sheetTotal = total;
      _sheetProgressLabel = label;
      _sheetStartedAt ??= DateTime.now();
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _selectedPaneContent() {
    return switch (_selectedPane) {
      _SettingsPane.sheetConnection => _GoogleSheetSection(
        formKey: _sheetFormKey,
        sheetUrlController: _sheetUrlController,
        isSaving: _isSavingSheet,
        isImporting: _isImporting,
        isExporting: _isExporting,
        onSave: _saveSheetSettings,
        onImport: _importSheet,
        onExport: _exportSheet,
        progress: _SheetOperationProgress(
          active: _isImporting || _isExporting,
          mode: _isImporting ? 'Importing' : 'Exporting',
          completed: _sheetCompleted,
          total: _sheetTotal,
          label: _sheetProgressLabel,
          startedAt: _sheetStartedAt,
        ),
      ),
      _SettingsPane.floatingInput => const SmartClipboardSettingsSection(),
      _SettingsPane.exchangeRate => _ExchangeRateSection(
        formKey: _rateFormKey,
        rateController: _rateController,
        isSaving: _isSavingRate,
        onSave: _saveExchangeRate,
      ),
      _SettingsPane.languageTheme => _AppearanceSection(controller: controller),
      _SettingsPane.about => const _AboutSection(),
    };
  }
}

class _DrawerAccountHeader extends StatelessWidget {
  const _DrawerAccountHeader({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = controller.user;
    final name = (user?.displayName ?? user?.accountId ?? 'Account').trim();
    final email = (user?.email ?? '').trim();
    final photoUrl = (user?.photoUrl ?? '').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/branding/maliyati_app_icon.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Maliyati',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close menu',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Material(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      backgroundImage: photoUrl.isEmpty
                          ? null
                          : NetworkImage(photoUrl),
                      child: photoUrl.isEmpty
                          ? Text(
                              name.isEmpty
                                  ? 'M'
                                  : name.substring(0, 1).toUpperCase(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email.isEmpty ? 'Personal finance account' : email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _GoogleSheetSection extends StatelessWidget {
  const _GoogleSheetSection({
    required this.formKey,
    required this.sheetUrlController,
    required this.isSaving,
    required this.isImporting,
    required this.isExporting,
    required this.onSave,
    required this.onImport,
    required this.onExport,
    required this.progress,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController sheetUrlController;
  final bool isSaving;
  final bool isImporting;
  final bool isExporting;
  final VoidCallback onSave;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final _SheetOperationProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingsPanel(
      icon: Icons.table_chart_rounded,
      title: 'Sheet connection',
      subtitle: 'Save the sheet link, then import or export manually',
      children: [
        Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: sheetUrlController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Google Sheet URL',
                  prefixIcon: Icon(Icons.table_chart_rounded),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) {
                    return 'Enter a Google Sheet URL.';
                  }
                  if (!text.startsWith(
                    'https://docs.google.com/spreadsheets/',
                  )) {
                    return 'Use a Google Sheet link.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isSaving ? null : onSave,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: const Text('Save'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF111827),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.72,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isImporting ? null : onImport,
                    icon: isImporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: const Text('Import'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF111827),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.72,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isExporting ? null : onExport,
                    icon: isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_rounded),
                    label: const Text('Export'),
                  ),
                ],
              ),
              if (progress.active) ...[const SizedBox(height: 14), progress],
            ],
          ),
        ),
      ],
    );
  }
}

class _SheetOperationProgress extends StatelessWidget {
  const _SheetOperationProgress({
    required this.active,
    required this.mode,
    required this.completed,
    required this.total,
    required this.label,
    required this.startedAt,
  });

  final bool active;
  final String mode;
  final int completed;
  final int total;
  final String label;
  final DateTime? startedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKnownTotal = total > 0;
    final progress = hasKnownTotal ? (completed / total).clamp(0.0, 1.0) : null;
    final remaining = hasKnownTotal ? (total - completed).clamp(0, total) : 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label.trim().isEmpty ? mode : '$mode - $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                hasKnownTotal ? '$completed / $total' : 'reading',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: theme.colorScheme.surface,
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OperationPill(label: 'Done', value: '$completed'),
              _OperationPill(
                label: 'Remaining',
                value: hasKnownTotal ? '$remaining' : 'unknown',
              ),
              _OperationPill(label: 'ETA', value: _etaText()),
            ],
          ),
        ],
      ),
    );
  }

  String _etaText() {
    if (startedAt == null || completed <= 0 || total <= 0) {
      return total <= 0 ? 'calculating' : 'starting';
    }
    final elapsed = DateTime.now().difference(startedAt!);
    final averageMs = elapsed.inMilliseconds / completed;
    final remaining = total - completed;
    final etaMs = (averageMs * remaining).round();
    if (etaMs <= 0) {
      return 'almost done';
    }
    final seconds = (etaMs / 1000).ceil();
    if (seconds < 60) {
      return '${seconds}s';
    }
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes}m ${rest}s';
  }
}

class _OperationPill extends StatelessWidget {
  const _OperationPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SheetSideSettings extends StatefulWidget {
  const _SheetSideSettings({
    required this.controller,
    required this.sheetFormKey,
    required this.sheetUrlController,
    required this.isSavingSheet,
    required this.isImporting,
    required this.isExporting,
    required this.onSaveSheet,
    required this.onImportSheet,
    required this.onExportSheet,
    required this.sheetProgress,
  });

  final DashboardController controller;
  final GlobalKey<FormState> sheetFormKey;
  final TextEditingController sheetUrlController;
  final bool isSavingSheet;
  final bool isImporting;
  final bool isExporting;
  final VoidCallback onSaveSheet;
  final VoidCallback onImportSheet;
  final VoidCallback onExportSheet;
  final _SheetOperationProgress sheetProgress;

  @override
  State<_SheetSideSettings> createState() => _SheetSideSettingsState();
}

class _SheetSideSettingsState extends State<_SheetSideSettings> {
  late final TextEditingController _rateController;
  final _rateFormKey = GlobalKey<FormState>();
  _SettingsPane _selectedPane = _SettingsPane.sheetConnection;
  bool _isSavingRate = false;

  DashboardController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _rateController = TextEditingController(
      text: controller.exchangeRate.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 520;
                  final menu = _SettingsSideMenu(
                    selected: _selectedPane,
                    onSelected: (pane) => setState(() {
                      _selectedPane = pane;
                    }),
                  );
                  final content = _selectedPaneContent();
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 190, child: menu),
                        const SizedBox(width: 12),
                        Expanded(child: content),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [menu, const SizedBox(height: 12), content],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveExchangeRate() async {
    if (!_rateFormKey.currentState!.validate()) {
      return;
    }
    final parsed = double.parse(
      _rateController.text.replaceAll(',', '').trim(),
    );
    setState(() => _isSavingRate = true);
    try {
      await controller.updateSettings(
        sheetUrl: controller.sheetUrl,
        sheetExportEndpoint: controller.sheetExportEndpoint,
        sheetExportSecret: controller.sheetExportSecret,
        exchangeRate: parsed,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Exchange rate saved.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingRate = false);
      }
    }
  }

  Widget _selectedPaneContent() {
    return switch (_selectedPane) {
      _SettingsPane.sheetConnection => _GoogleSheetSection(
        formKey: widget.sheetFormKey,
        sheetUrlController: widget.sheetUrlController,
        isSaving: widget.isSavingSheet,
        isImporting: widget.isImporting,
        isExporting: widget.isExporting,
        onSave: widget.onSaveSheet,
        onImport: widget.onImportSheet,
        onExport: widget.onExportSheet,
        progress: widget.sheetProgress,
      ),
      _SettingsPane.floatingInput => const SmartClipboardSettingsSection(),
      _SettingsPane.exchangeRate => _ExchangeRateSection(
        formKey: _rateFormKey,
        rateController: _rateController,
        isSaving: _isSavingRate,
        onSave: _saveExchangeRate,
      ),
      _SettingsPane.languageTheme => _AppearanceSection(controller: controller),
      _SettingsPane.about => const _AboutSection(),
    };
  }
}

enum _SettingsPane {
  sheetConnection,
  floatingInput,
  exchangeRate,
  languageTheme,
  about,
}

class _SettingsSideMenu extends StatelessWidget {
  const _SettingsSideMenu({required this.selected, required this.onSelected});

  final _SettingsPane selected;
  final ValueChanged<_SettingsPane> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Settings',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        _SettingsMenuTile(
          pane: _SettingsPane.sheetConnection,
          selected: selected,
          icon: Icons.table_chart_rounded,
          label: 'Sheet connection',
          onSelected: onSelected,
        ),
        _SettingsMenuTile(
          pane: _SettingsPane.floatingInput,
          selected: selected,
          icon: Icons.content_paste_search_rounded,
          label: 'Floating input',
          onSelected: onSelected,
        ),
        _SettingsMenuTile(
          pane: _SettingsPane.exchangeRate,
          selected: selected,
          icon: Icons.currency_exchange_rounded,
          label: 'Exchange rate',
          onSelected: onSelected,
        ),
        _SettingsMenuTile(
          pane: _SettingsPane.languageTheme,
          selected: selected,
          icon: Icons.tune_rounded,
          label: 'Language / theme',
          onSelected: onSelected,
        ),
        _SettingsMenuTile(
          pane: _SettingsPane.about,
          selected: selected,
          icon: Icons.info_rounded,
          label: 'About',
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class _SettingsMenuTile extends StatelessWidget {
  const _SettingsMenuTile({
    required this.pane,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final _SettingsPane pane;
  final _SettingsPane selected;
  final IconData icon;
  final String label;
  final ValueChanged<_SettingsPane> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = pane == selected;
    const activeInk = Color(0xFF1D4ED8);
    return Material(
      color: active
          ? const Color(0xFF2563EB).withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelected(pane),
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: active
                      ? activeInk
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: active ? activeInk : theme.colorScheme.onSurface,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
                if (active)
                  const Icon(Icons.chevron_right_rounded, color: activeInk),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = controller.user;
    final email = (user?.email ?? '').trim();
    final title = email.isEmpty ? 'Account' : email;
    return _SettingsPanel(
      icon: Icons.account_circle_rounded,
      title: title,
      subtitle: 'Google account',
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.errorContainer,
            foregroundColor: theme.colorScheme.onErrorContainer,
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          onPressed: () async {
            Navigator.pop(context);
            await controller.signOut();
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  static const _version = '1.2.0';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingsPanel(
      icon: Icons.info_rounded,
      title: 'About',
      subtitle: 'Maliyati version $_version',
      children: [
        Text(
          'Maliyati helps you track income, expenses, Google Sheet sync, quick script input, and spending alerts from one private workspace.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _AboutChip(label: 'Version', value: _version),
            _AboutChip(label: 'Data', value: 'Firebase'),
            _AboutChip(label: 'Sheet', value: 'Manual sync'),
          ],
        ),
      ],
    );
  }
}

class _AboutChip extends StatelessWidget {
  const _AboutChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ExchangeRateSection extends StatelessWidget {
  const _ExchangeRateSection({
    required this.formKey,
    required this.rateController,
    required this.isSaving,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController rateController;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _SettingsPanel(
      icon: Icons.currency_exchange_rounded,
      title: 'Exchange rate',
      subtitle: 'LBP value used for USD/LBP conversion',
      children: [
        Form(
          key: formKey,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'LBP = 1 USD',
                    prefixIcon: Icon(Icons.currency_exchange_rounded),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(
                      (value ?? '').replaceAll(',', '').trim(),
                    );
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid exchange rate.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: isSaving ? null : onSave,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = controller.strings;
    return _SettingsPanel(
      icon: Icons.tune_rounded,
      title: 'Language & theme',
      subtitle: 'Arabic/English and light/dark mode',
      children: [
        Text(
          strings.languageTitle,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<AppLanguage>(
          segments: [
            ButtonSegment(
              value: AppLanguage.english,
              label: Text(strings.english),
              icon: const Icon(Icons.language_rounded),
            ),
            ButtonSegment(
              value: AppLanguage.arabic,
              label: Text(strings.arabic),
              icon: const Icon(Icons.translate_rounded),
            ),
          ],
          selected: {controller.language},
          onSelectionChanged: (selection) {
            controller.updateLanguage(selection.first);
          },
        ),
        const SizedBox(height: 16),
        Text(
          strings.appearance,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
              value: ThemeMode.light,
              label: Text(strings.lightTheme),
              icon: const Icon(Icons.light_mode_rounded),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text(strings.darkTheme),
              icon: const Icon(Icons.dark_mode_rounded),
            ),
          ],
          selected: {controller.themeMode},
          onSelectionChanged: (selection) {
            controller.updateThemeMode(selection.first);
          },
        ),
      ],
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isError
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
