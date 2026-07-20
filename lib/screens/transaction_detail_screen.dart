import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';
import '../widgets/finance_formatters.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/transaction_identity.dart';

enum _EditTransactionStatus { income, expense, credit, debt, transfer }

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    super.key,
    required this.controller,
    required this.transaction,
    this.startEditing = false,
  });

  final DashboardController controller;
  final FinancialTransaction transaction;
  final bool startEditing;

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late FinancialTransaction _transaction;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _amountUsdController;
  late final TextEditingController _amountLbpController;
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
    _isEditing = true;
    _descriptionController = TextEditingController();
    _categoryController = TextEditingController();
    _amountUsdController = TextEditingController();
    _amountLbpController = TextEditingController();
    _paymentMethodController = TextEditingController();
    _notesController = TextEditingController();
    _loadFormValues(_transaction);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _categoryController.dispose();
    _amountUsdController.dispose();
    _amountLbpController.dispose();
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
          IconButton(
            tooltip: 'Delete',
            onPressed: _isSaving ? null : _confirmDelete,
            icon: const Icon(Icons.delete_outline_rounded),
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
          child: _EditBody(state: this),
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
    final amountText = transaction.amount == 0
        ? ''
        : transaction.amount.toStringAsFixed(
            transaction.amount.truncateToDouble() == transaction.amount ? 0 : 2,
          );
    _amountUsdController.text = transaction.currency == CurrencyCode.usd
        ? amountText
        : '';
    _amountLbpController.text = transaction.currency == CurrencyCode.lbp
        ? amountText
        : '';
    _paymentMethodController.text = transaction.paymentMethod;
    _notesController.text = transaction.notes;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final usd = _parseAmount(_amountUsdController.text);
    final lbp = _parseAmount(_amountLbpController.text);
    if (usd <= 0 && lbp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a USD or LBP amount.')),
      );
      return;
    }
    final updated = _transaction.copyWith(
      type: _selectedType,
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim(),
      currency: lbp > 0 ? CurrencyCode.lbp : CurrencyCode.usd,
      amount: lbp > 0 ? lbp : usd,
      paymentMethod: _paymentMethodController.text.trim(),
      notes: _notesController.text.trim(),
      source: _selectedSource,
      date: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      ),
      hasDate: true,
    );
    if (!_hasMeaningfulChanges(updated)) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No changes to save.')));
      return;
    }
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

  Future<void> _settleCurrent() async {
    setState(() => _isSaving = true);
    try {
      await widget.controller.settleTransaction(
        _transaction,
        walletId: _paymentMethodController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _updateType(TransactionType type) {
    setState(() {
      _selectedType = type;
    });
  }

  void _updateCurrency(CurrencyCode currency) {
    setState(() => _selectedCurrency = currency);
  }

  bool _hasMeaningfulChanges(FinancialTransaction updated) {
    final sameDate =
        updated.date.year == _transaction.date.year &&
        updated.date.month == _transaction.date.month &&
        updated.date.day == _transaction.date.day;
    return updated.type != _transaction.type ||
        updated.category != _transaction.category ||
        updated.description != _transaction.description ||
        updated.currency != _transaction.currency ||
        updated.amount != _transaction.amount ||
        updated.paymentMethod != _transaction.paymentMethod ||
        updated.notes != _transaction.notes ||
        updated.source != _transaction.source ||
        updated.hasDate != _transaction.hasDate ||
        !sameDate;
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

  void _updateWallet(String walletId) {
    setState(() => _paymentMethodController.text = walletId);
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
    if (type == TransactionType.debt) {
      return 'Debt';
    }
    if (type == TransactionType.transfer) {
      return 'Transfer';
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
      TransactionType.debt => (
        const Color(0xFF7C3AED),
        const Color(0xFF8B5CF6),
        Icons.account_balance_rounded,
      ),
      TransactionType.transfer => (
        const Color(0xFF2563EB),
        const Color(0xFF38BDF8),
        Icons.swap_horiz_rounded,
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
                  _HeaderChip(
                    label: strings.category,
                    value: transaction.category,
                  ),
                  _HeaderChip(
                    label: 'Wallet',
                    value: state._emptyFallback(transaction.paymentMethod),
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
                  DropdownButtonFormField<_EditTransactionStatus>(
                    value: switch (state._selectedType) {
                      TransactionType.income => _EditTransactionStatus.income,
                      TransactionType.reserveable =>
                        _EditTransactionStatus.credit,
                      TransactionType.debt => _EditTransactionStatus.debt,
                      TransactionType.transfer =>
                        _EditTransactionStatus.transfer,
                      _ => _EditTransactionStatus.expense,
                    },
                    decoration: InputDecoration(
                      labelText: strings.type,
                      prefixIcon: const Icon(Icons.label_rounded),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: _EditTransactionStatus.income,
                        child: Text(strings.income),
                      ),
                      DropdownMenuItem(
                        value: _EditTransactionStatus.expense,
                        child: Text(strings.expense),
                      ),
                      DropdownMenuItem(
                        value: _EditTransactionStatus.credit,
                        child: Text(strings.reserveable),
                      ),
                      const DropdownMenuItem(
                        value: _EditTransactionStatus.debt,
                        child: Text('Debt'),
                      ),
                      const DropdownMenuItem(
                        value: _EditTransactionStatus.transfer,
                        child: Text('Transfer'),
                      ),
                    ],
                    onChanged: (value) {
                      switch (value) {
                        case _EditTransactionStatus.income:
                          state._updateType(TransactionType.income);
                        case _EditTransactionStatus.expense:
                          state._updateType(TransactionType.expense);
                        case _EditTransactionStatus.credit:
                          state._updateType(TransactionType.reserveable);
                        case _EditTransactionStatus.debt:
                          state._updateType(TransactionType.debt);
                        case _EditTransactionStatus.transfer:
                          state._updateType(TransactionType.transfer);
                        case null:
                          break;
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
                      labelText: 'Title',
                      prefixIcon: const Icon(Icons.title_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a title.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: state._amountUsdController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Amount (\$)',
                            prefixIcon: const Icon(Icons.attach_money_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: state._amountLbpController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Amount (LBP)',
                            prefixIcon: const Icon(Icons.payments_rounded),
                          ),
                        ),
                      ),
                    ],
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Destination wallet',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          avatar: const Icon(
                            Icons.account_balance_wallet_rounded,
                          ),
                          label: const Text('My Wallet'),
                          selected: !state._paymentMethodController.text
                              .toLowerCase()
                              .contains('wish'),
                          onSelected: (_) => state._updateWallet('Cash'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          avatar: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.asset(
                              'assets/branding/wish_money_logo.jpg',
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                            ),
                          ),
                          label: const Text('Wish Money'),
                          selected: state._paymentMethodController.text
                              .toLowerCase()
                              .contains('wish'),
                          onSelected: (_) => state._updateWallet('Wish Money'),
                        ),
                      ),
                    ],
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
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_rounded),
                    title: Text(strings.date),
                    subtitle: Text(FinanceFormatters.date(state._selectedDate)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: state._selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) state._updateDate(picked);
                    },
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
          if ((state._transaction.isDebt || state._transaction.isCredit) &&
              !state._transaction.isSettled) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: state._isSaving ? null : state._settleCurrent,
              icon: const Icon(Icons.verified_rounded),
              label: Text(
                state._transaction.isDebt ? 'Settle debt' : 'Collect credit',
              ),
            ),
          ],
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
