import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';
import '../widgets/finance_formatters.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/transaction_identity.dart';

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    super.key,
    required this.controller,
    required this.transaction,
  });

  final DashboardController controller;
  final FinancialTransaction transaction;

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late FinancialTransaction _transaction;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _amountController;
  late final TextEditingController _paymentMethodController;
  late final TextEditingController _notesController;
  late TransactionType _selectedType;
  late CurrencyCode _selectedCurrency;
  late TransactionSource _selectedSource;
  late DateTime _selectedDate;
  late bool _hasDate;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _descriptionController = TextEditingController();
    _categoryController = TextEditingController();
    _amountController = TextEditingController();
    _paymentMethodController = TextEditingController();
    _notesController = TextEditingController();
    _loadFormValues(_transaction);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    _paymentMethodController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.controller.strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.transactionDetails),
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (!_isEditing)
            IconButton(
              tooltip: 'Delete',
              onPressed: _isSaving ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          TextButton.icon(
            onPressed: _isSaving
                ? null
                : _isEditing
                ? _saveChanges
                : _startEditing,
            icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_rounded),
            label: Text(_isEditing ? strings.save : strings.editLocally),
          ),
          if (_isEditing)
            IconButton(
              tooltip: strings.cancel,
              onPressed: _cancelEditing,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppResponsive.isWideWeb(context)
                ? AppResponsive.webDetailMaxWidth
                : double.infinity,
          ),
          child: _isEditing
              ? _EditBody(state: this)
              : _ReadOnlyBody(state: this),
        ),
      ),
    );
  }

  void _startEditing() {
    _loadFormValues(_transaction);
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    _loadFormValues(_transaction);
    setState(() => _isEditing = false);
  }

  void _loadFormValues(FinancialTransaction transaction) {
    _selectedType = transaction.type == TransactionType.unknown
        ? TransactionType.expense
        : transaction.type;
    _selectedCurrency = transaction.currency == CurrencyCode.unknown
        ? CurrencyCode.usd
        : transaction.currency;
    _selectedSource = transaction.source;
    _selectedDate = transaction.date;
    _hasDate = transaction.hasDate;
    _descriptionController.text = transaction.description;
    _categoryController.text = transaction.category;
    _amountController.text = transaction.amount == 0
        ? ''
        : transaction.amount.toStringAsFixed(
            transaction.amount.truncateToDouble() == transaction.amount ? 0 : 2,
          );
    _paymentMethodController.text = transaction.paymentMethod;
    _notesController.text = transaction.notes;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final updated = _transaction.copyWith(
      type: _selectedType,
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim(),
      currency: _selectedCurrency,
      amount: _parseAmount(_amountController.text),
      paymentMethod: _paymentMethodController.text.trim(),
      notes: _notesController.text.trim(),
      source: _selectedSource,
      date: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      ),
      hasDate: _hasDate,
    );
    setState(() => _isSaving = true);
    try {
      await widget.controller.updateTransaction(_transaction, updated);
      if (!mounted) {
        return;
      }
      setState(() {
        _transaction = updated;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.strings.localChangesSaved)),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _updateType(TransactionType type) {
    setState(() => _selectedType = type);
  }

  void _updateCurrency(CurrencyCode currency) {
    setState(() => _selectedCurrency = currency);
  }

  void _updateSource(TransactionSource source) {
    setState(() => _selectedSource = source);
  }

  void _updateHasDate(bool hasDate) {
    setState(() => _hasDate = hasDate);
  }

  void _updateDate(DateTime date) {
    setState(() => _selectedDate = date);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This removes it from the app database.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(widget.controller.strings.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.controller.deleteTransaction(_transaction);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  double _parseAmount(String value) {
    final cleaned = value
        .replaceAll(',', '')
        .replaceAll(r'$', '')
        .replaceAll(RegExp('lbp|usd', caseSensitive: false), '')
        .trim();
    return double.tryParse(cleaned) ?? 0;
  }

  String _typeLabel(TransactionType type) {
    final strings = widget.controller.strings;
    if (type == TransactionType.income) {
      return strings.income;
    }
    if (type == TransactionType.expense) {
      return strings.expense;
    }
    if (type == TransactionType.reserveable) {
      return strings.reserveable;
    }
    return strings.noData;
  }

  String _emptyFallback(String value) {
    return value.trim().isEmpty ? '-' : value.trim();
  }

  String _prettyKey(String key) {
    return key
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _ReadOnlyBody extends StatelessWidget {
  const _ReadOnlyBody({required this.state});

  final _TransactionDetailScreenState state;

  @override
  Widget build(BuildContext context) {
    final transaction = state._transaction;
    final strings = state.widget.controller.strings;
    final exchangeRate = state.widget.controller.exchangeRate;
    final theme = Theme.of(context);
    final (color, accent, typeIcon) = switch (transaction.type) {
      TransactionType.income => (
        const Color(0xFF168A5B),
        const Color(0xFF2563EB),
        Icons.trending_up_rounded,
      ),
      TransactionType.expense => (
        const Color(0xFFC74949),
        const Color(0xFF9333EA),
        Icons.trending_down_rounded,
      ),
      TransactionType.reserveable => (
        const Color(0xFFD97706),
        const Color(0xFFEAB308),
        Icons.request_quote_rounded,
      ),
      TransactionType.unknown => (
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.secondary,
        Icons.help_outline_rounded,
      ),
    };
    final description = transaction.description.isEmpty
        ? transaction.category
        : transaction.description;
    final transactionId = TransactionIdentity.fullId(transaction);
    final convertedAmount = FinanceFormatters.convertedAmount(
      transaction,
      exchangeRate,
    );
    final convertedLabel = transaction.currency == CurrencyCode.usd
        ? strings.convertedLbp
        : strings.convertedUsd;

    return ListView(
      padding: AppResponsive.isWideWeb(context)
          ? const EdgeInsets.fromLTRB(24, 16, 24, 32)
          : const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [color, accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(typeIcon, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state._typeLabel(transaction.type),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                description,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                FinanceFormatters.amount(transaction),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (convertedAmount.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  '≈ $convertedAmount',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeaderChip(
                    label: strings.date,
                    value: transaction.hasDate
                        ? FinanceFormatters.date(transaction.date)
                        : strings.noDateInSheet,
                  ),
                  _HeaderChip(label: 'Source', value: transaction.source.label),
                  _HeaderChip(
                    label: 'ID',
                    value: TransactionIdentity.shortId(transaction),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: strings.overview,
          children: [
            _CopyableDetailRow(
              label: 'Transaction ID',
              value: transactionId.isEmpty ? '-' : transactionId,
            ),
            _DetailRow(
              label: strings.type,
              value: state._typeLabel(transaction.type),
            ),
            _DetailRow(label: strings.description, value: description),
            _DetailRow(label: strings.category, value: transaction.category),
            _DetailRow(
              label: strings.date,
              value: transaction.hasDate
                  ? FinanceFormatters.date(transaction.date)
                  : strings.noDateInSheet,
            ),
            _DetailRow(
              label: 'Created at',
              value: transaction.createdAt == null
                  ? '-'
                  : FinanceFormatters.dateTime(transaction.createdAt!),
            ),
            _DetailRow(label: 'Source', value: transaction.source.label),
            _DetailRow(
              label: strings.paymentMethod,
              value: state._emptyFallback(transaction.paymentMethod),
            ),
            _DetailRow(
              label: strings.notes,
              value: state._emptyFallback(transaction.notes),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: strings.value,
          children: [
            _DetailRow(
              label: transaction.currency == CurrencyCode.lbp
                  ? strings.amountLbp
                  : strings.amountUsd,
              value: FinanceFormatters.amount(transaction),
            ),
            _DetailRow(label: convertedLabel, value: convertedAmount),
            _DetailRow(
              label: strings.exchangeRate,
              value: '${exchangeRate.toStringAsFixed(0)} LBP = 1 USD',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: strings.originalSheetData,
          children: [
            for (final entry in transaction.raw.entries)
              _DetailRow(
                label: state._prettyKey(entry.key),
                value: state._emptyFallback(entry.value),
              ),
          ],
        ),
      ],
    );
  }
}

class _EditBody extends StatelessWidget {
  const _EditBody({required this.state});

  final _TransactionDetailScreenState state;

  @override
  Widget build(BuildContext context) {
    final strings = state.widget.controller.strings;
    final theme = Theme.of(context);

    return Form(
      key: state._formKey,
      child: ListView(
        padding: AppResponsive.isWideWeb(context)
            ? const EdgeInsets.fromLTRB(24, 16, 24, 32)
            : const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<TransactionType>(
                    initialValue: state._selectedType,
                    decoration: InputDecoration(
                      labelText: strings.type,
                      prefixIcon: const Icon(Icons.label_rounded),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: TransactionType.income,
                        child: Text(strings.income),
                      ),
                      DropdownMenuItem(
                        value: TransactionType.expense,
                        child: Text(strings.expense),
                      ),
                      DropdownMenuItem(
                        value: TransactionType.reserveable,
                        child: Text(strings.reserveable),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        state._updateType(value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<TransactionSource>(
                    initialValue: state._selectedSource,
                    decoration: const InputDecoration(
                      labelText: 'Source',
                      prefixIcon: Icon(Icons.source_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: TransactionSource.application,
                        child: Text('application'),
                      ),
                      DropdownMenuItem(
                        value: TransactionSource.googleSheet,
                        child: Text('Google Sheet'),
                      ),
                      DropdownMenuItem(
                        value: TransactionSource.script,
                        child: Text('script'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        state._updateSource(value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: state._descriptionController,
                    decoration: InputDecoration(
                      labelText: strings.description,
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _OptionTextField(
                    controller: state._categoryController,
                    label: strings.category,
                    icon: Icons.category_rounded,
                    options: state.widget.controller.categoryOptions,
                    fallbackOptions: const [
                      'Masrouf bayt',
                      'Transportation',
                      'Income internet',
                      'Dyefe',
                    ],
                    validator: (value) => value == null || value.trim().isEmpty
                        ? strings.category
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: state._amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: strings.amount,
                            prefixIcon: const Icon(Icons.payments_rounded),
                          ),
                          validator: (value) {
                            if (value == null ||
                                state._parseAmount(value) <= 0) {
                              return strings.amount;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<CurrencyCode>(
                          initialValue: state._selectedCurrency,
                          decoration: InputDecoration(
                            labelText: strings.value,
                            prefixIcon: const Icon(Icons.attach_money_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: CurrencyCode.usd,
                              child: Text('USD'),
                            ),
                            DropdownMenuItem(
                              value: CurrencyCode.lbp,
                              child: Text('LBP'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              state._updateCurrency(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: state._hasDate,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      strings.hasDate,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    secondary: const Icon(Icons.event_rounded),
                    onChanged: state._updateHasDate,
                  ),
                  if (state._hasDate)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month_rounded),
                      title: Text(strings.date),
                      subtitle: Text(
                        FinanceFormatters.date(state._selectedDate),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: state._selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          state._updateDate(picked);
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                  _OptionTextField(
                    controller: state._paymentMethodController,
                    label: strings.paymentMethod,
                    icon: Icons.credit_card_rounded,
                    options: state.widget.controller.paymentMethodOptions,
                    fallbackOptions: const ['Cash', 'Whish money', 'Paid'],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: state._notesController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: strings.notes,
                      prefixIcon: const Icon(Icons.sticky_note_2_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: state._saveChanges,
            icon: const Icon(Icons.check_rounded),
            label: Text(strings.save),
          ),
        ],
      ),
    );
  }
}

class _OptionTextField extends StatelessWidget {
  const _OptionTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.options,
    required this.fallbackOptions,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final List<String> options;
  final List<String> fallbackOptions;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final values = {...options, ...fallbackOptions}.toList()..sort();
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: PopupMenuButton<String>(
          tooltip: 'Choose $label',
          icon: const Icon(Icons.arrow_drop_down_rounded),
          onSelected: (value) => controller.text = value,
          itemBuilder: (context) => [
            for (final value in values)
              PopupMenuItem(value: value, child: Text(value)),
          ],
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyableDetailRow extends StatelessWidget {
  const _CopyableDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: SelectableText(
                    value,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (value != '-') ...[
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Copy ID',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaction ID copied.')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
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
