import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';
import '../services/gemini_transaction_parser.dart';
import '../widgets/finance_formatters.dart';
import '../widgets/responsive_layout.dart';

class GeminiPasteScreen extends StatefulWidget {
  const GeminiPasteScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<GeminiPasteScreen> createState() => _GeminiPasteScreenState();
}

class _GeminiPasteScreenState extends State<GeminiPasteScreen> {
  final _scriptController = TextEditingController();
  final _parser = GeminiTransactionParser();
  List<FinancialTransaction> _preview = const [];
  String? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _scriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return ListView(
      padding: AppResponsive.pagePadding(context),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppResponsive.isWideWeb(context)
                  ? 900
                  : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Gemini Paste',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _scriptController.text.isEmpty ? null : _clear,
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Paste the JSON from Gemini',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _scriptController,
                          minLines: 10,
                          maxLines: 16,
                          decoration: const InputDecoration(
                            alignLabelWithHint: true,
                            labelText: 'Gemini script',
                            prefixIcon: Icon(Icons.data_object_rounded),
                          ),
                          onChanged: (_) => _parsePreview(),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: _isSaving || _preview.isEmpty
                                  ? null
                                  : _save,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.add_rounded),
                              label: Text(
                                _preview.length <= 1
                                    ? 'Add transaction'
                                    : 'Add ${_preview.length} transactions',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _insertExample,
                              icon: const Icon(Icons.content_paste_rounded),
                              label: const Text('Example'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (!controller.isSignedIn) ...[
                  const SizedBox(height: 12),
                  _Notice(
                    icon: Icons.info_outline_rounded,
                    message:
                        'Sign in first to save transactions online in Firestore.',
                  ),
                ],
                if (!controller.isSheetExportConfigured) ...[
                  const SizedBox(height: 12),
                  _Notice(
                    icon: Icons.table_chart_rounded,
                    message:
                        'Google Sheet export is not configured yet. Add SHEET_EXPORT_ENDPOINT and SHEET_EXPORT_SECRET when the Apps Script is ready.',
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBox(message: _error!),
                ],
                if (_preview.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Preview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final transaction in _preview)
                    _PreviewTile(
                      transaction: transaction,
                      exchangeRate: controller.exchangeRate,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _parsePreview() {
    try {
      final value = _scriptController.text.trim();
      setState(() {
        _preview = value.isEmpty ? const [] : _parser.parse(value);
        _error = null;
      });
    } catch (error) {
      setState(() {
        _preview = const [];
        _error = error.toString();
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final count = await widget.controller.addTransactionsFromGeminiScript(
        _scriptController.text,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Added $count transaction(s).')));
      _clear();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _clear() {
    _scriptController.clear();
    setState(() {
      _preview = const [];
      _error = null;
    });
  }

  void _insertExample() {
    _scriptController.text = '''{
  "action": "add_transaction",
  "date": "2026-07-14",
  "status": "Expense",
  "title": "10 kg tomatoes",
  "amount_usd": 0,
  "amount_lbp": 450000,
  "category": "Masrouf bayt",
  "payment_method": "Cash",
  "notes": "Gemini voice entry"
}''';
    _parsePreview();
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.transaction, required this.exchangeRate});

  final FinancialTransaction transaction;
  final double exchangeRate;

  @override
  Widget build(BuildContext context) {
    final color = switch (transaction.type) {
      TransactionType.income => const Color(0xFF168A5B),
      TransactionType.expense => const Color(0xFFC74949),
      TransactionType.reserveable => const Color(0xFFD97706),
      TransactionType.unknown => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Card(
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(Icons.receipt_long_rounded, color: color),
        ),
        title: Text(transaction.description),
        subtitle: Text(
          '${transaction.type.label} - ${transaction.category} - ${FinanceFormatters.date(transaction.date)}',
        ),
        trailing: Text(
          FinanceFormatters.amount(transaction),
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
