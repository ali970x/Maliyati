import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../controllers/dashboard_controller.dart';
import '../l10n/app_strings.dart';
import '../services/google_sheet_service.dart';
import '../widgets/finance_formatters.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _sheetController;
  late final TextEditingController _rateController;
  final _formKey = GlobalKey<FormState>();
  final _sheetService = GoogleSheetService();

  @override
  void initState() {
    super.initState();
    _sheetController = TextEditingController(text: widget.controller.sheetUrl);
    _rateController = TextEditingController(
      text: widget.controller.exchangeRate.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final strings = controller.strings;
    final csvUrl = _sheetService.toCsvExportUrl(_sheetController.text);

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.settings,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: controller.isLoading ? null : controller.refresh,
                tooltip: strings.refresh,
                icon: controller.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.dataSource,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _sheetController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: strings.googleSheetUrl,
                        prefixIcon: const Icon(Icons.link_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return strings.enterSheetUrl;
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _rateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: strings.exchangeRate,
                        prefixIcon: const Icon(Icons.currency_exchange_rounded),
                        suffixText: strings.lbpEqualsUsd,
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(
                          (value ?? '').replaceAll(',', '').trim(),
                        );
                        if (parsed == null || parsed <= 0) {
                          return strings.enterValidExchangeRate;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(strings.saveSettings),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.languageTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.table_chart_rounded,
            title: strings.csvExportUrl,
            value: csvUrl,
          ),
          _InfoTile(
            icon: Icons.schedule_rounded,
            title: strings.lastUpdate,
            value: controller.lastUpdated == null
                ? strings.notSyncedYet
                : FinanceFormatters.dateTime(controller.lastUpdated!),
          ),
          _InfoTile(
            icon: Icons.swap_horiz_rounded,
            title: strings.configuredRate,
            value: '${controller.exchangeRate.toStringAsFixed(0)} LBP = 1 USD',
          ),
          _InfoTile(
            icon: Icons.receipt_long_rounded,
            title: strings.loadedRows,
            value: strings.rowsLoaded(controller.transactions.length),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              _sheetController.text = AppConfig.defaultGoogleSheetUrl;
              _rateController.text = AppConfig.defaultExchangeRate
                  .toStringAsFixed(0);
              setState(() {});
            },
            icon: const Icon(Icons.restore_rounded),
            label: Text(strings.restoreDefaults),
          ),
          if (controller.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                controller.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final exchangeRate = double.parse(
      _rateController.text.replaceAll(',', '').trim(),
    );
    await widget.controller.updateSettings(
      sheetUrl: _sheetController.text,
      exchangeRate: exchangeRate,
    );
    await widget.controller.refresh();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.controller.strings.settingsSaved)),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}
