import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';
import '../services/wish_receipt_import_service.dart';
import '../widgets/finance_formatters.dart';

class WishReceiptReviewScreen extends StatefulWidget {
  const WishReceiptReviewScreen({
    super.key,
    required this.controller,
    required this.imagePath,
  });

  final DashboardController controller;
  final String imagePath;

  @override
  State<WishReceiptReviewScreen> createState() =>
      _WishReceiptReviewScreenState();
}

class _WishReceiptReviewScreenState extends State<WishReceiptReviewScreen> {
  final _service = WishReceiptImportService();
  WishReceiptDraft? _draft;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    try {
      final draft = await _service.read(widget.imagePath);
      if (mounted) setState(() => _draft = draft);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not read this Whish receipt.');
    }
  }

  Future<void> _pickDate() async {
    final draft = _draft;
    if (draft == null) return;
    final selected = await showDatePicker(
      context: context,
      initialDate: draft.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected != null && mounted) {
      setState(() => _draft = draft.copyWith(date: selected, hasDate: true));
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || draft.amount <= 0 || _saving) return;
    if (draft.id.isNotEmpty &&
        widget.controller.transactions.any(
          (item) => item.id?.trim() == draft.id,
        )) {
      setState(() => _error = 'This Wish Transaction ID was already added.');
      return;
    }
    setState(() => _saving = true);
    try {
      final image = await _service.persistImage(draft);
      if (draft.kind == WishReceiptKind.exchange &&
          draft.exchangeRate != null) {
        await widget.controller.updateExchangeRate(draft.exchangeRate!);
      }
      await widget.controller.addTransaction(
        draft.toTransaction(persistedImagePath: image),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Could not add this receipt. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(title: const Text('Review Whish receipt')),
      body: draft == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(draft.imagePath),
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  draft.kind == WishReceiptKind.exchange
                      ? 'Currency exchange — neutral record'
                      : 'Confirm the extracted details before adding.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _ReviewField(
                  label: 'Transaction ID',
                  value: draft.id.isEmpty ? 'Not found' : draft.id,
                ),
                _ReviewField(label: 'Wallet', value: 'Whish Money'),
                _ReviewField(
                  label: 'Amount',
                  value: '${draft.amount} ${draft.currency.label}',
                ),
                if (draft.exchangeRate != null)
                  _ReviewField(
                    label: 'Whish exchange rate',
                    value:
                        '1 USD = ${draft.exchangeRate!.toStringAsFixed(0)} LBP',
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_rounded),
                  title: const Text('Wish transaction date'),
                  subtitle: Text(
                    draft.hasDate
                        ? FinanceFormatters.date(draft.date)
                        : 'Not visible in receipt — choose it now',
                  ),
                  trailing: const Icon(Icons.edit_calendar_rounded),
                  onTap: _pickDate,
                ),
                DropdownButtonFormField<TransactionType>(
                  initialValue: draft.type,
                  decoration: const InputDecoration(
                    labelText: 'Effect on Wish balance',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: TransactionType.income,
                      child: Text('Money received (+)'),
                    ),
                    DropdownMenuItem(
                      value: TransactionType.expense,
                      child: Text('Money sent / spent (−)'),
                    ),
                    DropdownMenuItem(
                      value: TransactionType.unknown,
                      child: Text('Neutral — do not change balance'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null)
                      setState(() => _draft = draft.copyWith(type: value));
                  },
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_task_rounded),
                  label: const Text('Add to Maliyati Wallet'),
                ),
                const SizedBox(height: 8),
                Text(
                  'The Whish receipt image is saved with this transaction. The share time is kept in its notes.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}

class _ReviewField extends StatelessWidget {
  const _ReviewField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
