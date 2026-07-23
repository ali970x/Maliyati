import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';
import '../services/firebase_finance_service.dart';
import '../widgets/amount_limit_input_formatter.dart';
import '../widgets/finance_formatters.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/transaction_identity.dart';

enum _EditTransactionStatus { income, expense, credit, debt, transfer }

class _SettlementRequest {
  const _SettlementRequest({
    required this.amountUsd,
    required this.amountLbp,
    required this.walletId,
  });

  final double amountUsd;
  final double amountLbp;
  final String walletId;
}

class _WalletSelectionButton extends StatelessWidget {
  const _WalletSelectionButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isWish = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isWish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isWish ? const Color(0xFF6D4AFF) : theme.colorScheme.primary;
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: isWish
            ? ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/branding/wish_money_logo.jpg',
                  width: 23,
                  height: 23,
                  fit: BoxFit.cover,
                ),
              )
            : const Icon(Icons.account_balance_wallet_rounded),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? color : theme.colorScheme.onSurface,
          backgroundColor: selected ? color.withValues(alpha: .14) : null,
          side: BorderSide(
            color: selected ? color : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SettlementSheet extends StatefulWidget {
  const _SettlementSheet({required this.target, required this.initialWalletId});

  final FinancialTransaction target;
  final String initialWalletId;

  @override
  State<_SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<_SettlementSheet> {
  late final TextEditingController _usdController;
  late final TextEditingController _lbpController;
  late String _walletId;
  var _payFullAmount = true;

  @override
  void initState() {
    super.initState();
    _usdController = TextEditingController(
      text: _amountText(widget.target.remainingAmountUsd),
    );
    _lbpController = TextEditingController(
      text: _amountText(widget.target.remainingAmountLbp),
    );
    final initial = widget.initialWalletId.trim().toLowerCase();
    _walletId = initial.contains('wish') ? 'Whish Money' : 'My Wallet';
  }

  @override
  void dispose() {
    _usdController.dispose();
    _lbpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final isDebt = target.isDebt;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDebt ? 'Pay debt' : 'Collect credit',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Text(
              'Remaining: ${FinanceFormatters.usd(target.remainingAmountUsd)} | ${FinanceFormatters.lbp(target.remainingAmountLbp)}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.done_all_rounded),
                  label: Text('Full amount'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.edit_rounded),
                  label: Text('Partial amount'),
                ),
              ],
              selected: {_payFullAmount},
              onSelectionChanged: (value) =>
                  setState(() => _payFullAmount = value.first),
            ),
            if (!_payFullAmount) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usdController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'USD'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lbpController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'LBP'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Wallet',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _WalletSelectionButton(
                    label: 'My Wallet',
                    selected: _walletId == 'My Wallet',
                    onTap: () => setState(() => _walletId = 'My Wallet'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _WalletSelectionButton(
                    label: 'Whish Money',
                    isWish: true,
                    selected: _walletId == 'Whish Money',
                    onTap: () => setState(() => _walletId = 'Whish Money'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${isDebt ? 'Payment' : 'Collection'} will be recorded in $_walletId.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(isDebt ? 'Save payment' : 'Save collection'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final target = widget.target;
    final usd = _payFullAmount
        ? target.remainingAmountUsd
        : _parseAmount(_usdController.text);
    final lbp = _payFullAmount
        ? target.remainingAmountLbp
        : _parseAmount(_lbpController.text);
    if (usd <= 0 && lbp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the amount received or paid.')),
      );
      return;
    }
    Navigator.of(context).pop(
      _SettlementRequest(amountUsd: usd, amountLbp: lbp, walletId: _walletId),
    );
  }

  static String _amountText(double amount) => amount <= 0
      ? ''
      : amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);

  static double _parseAmount(String value) {
    final cleaned = value
        .replaceAll(',', '')
        .replaceAll(r'$', '')
        .replaceAll(RegExp('lbp|usd', caseSensitive: false), '')
        .trim();
    return double.tryParse(cleaned) ?? 0;
  }
}

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    super.key,
    required this.controller,
    required this.transaction,
    this.startEditing = false,
    this.openSettlement = false,
  });

  final DashboardController controller;
  final FinancialTransaction transaction;
  final bool startEditing;
  final bool openSettlement;

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
  late final TextEditingController _destinationWalletController;
  late final TextEditingController _notesController;
  late TransactionType _selectedType;
  late CurrencyCode _selectedCurrency;
  late TransactionSource _selectedSource;
  late DateTime _selectedDate;
  late bool _hasDate;
  late bool _paidNow;
  late AccountingSettlementStatus _settlementStatus;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hydratingForm = false;
  bool _hasLocalEdits = false;

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
    _destinationWalletController = TextEditingController();
    _notesController = TextEditingController();
    for (final controller in [
      _descriptionController,
      _categoryController,
      _amountUsdController,
      _amountLbpController,
      _paymentMethodController,
      _destinationWalletController,
      _notesController,
    ]) {
      controller.addListener(_markLocalEdit);
    }
    _loadFormValues(_transaction);
    widget.controller.addListener(_syncTransactionFromController);
    if (widget.openSettlement &&
        (_transaction.isDebt || _transaction.isCredit) &&
        !_transaction.isSettled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _settleCurrent();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncTransactionFromController);
    _descriptionController.dispose();
    _categoryController.dispose();
    _amountUsdController.dispose();
    _amountLbpController.dispose();
    _paymentMethodController.dispose();
    _destinationWalletController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _syncTransactionFromController() {
    final id = _transaction.id;
    if (!mounted || id == null || id.isEmpty || _hasLocalEdits) {
      return;
    }
    final matching = widget.controller.transactions.where(
      (item) => item.id == id,
    );
    if (matching.isEmpty ||
        matching.first.raw.toString() == _transaction.raw.toString()) {
      return;
    }
    setState(() {
      _transaction = matching.first;
      _loadFormValues(_transaction);
    });
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
    _hydratingForm = true;
    _selectedType = transaction.type == TransactionType.unknown
        ? TransactionType.expense
        : transaction.type;
    _selectedCurrency = transaction.currency == CurrencyCode.unknown
        ? CurrencyCode.usd
        : transaction.currency;
    _selectedSource = transaction.source;
    _selectedDate = transaction.date;
    _hasDate = transaction.hasDate;
    _paidNow =
        transaction.type != TransactionType.expense ||
        transaction.walletDirection < 0;
    _settlementStatus = transaction.settlementStatus;
    _descriptionController.text = transaction.description;
    _categoryController.text = transaction.category;
    _amountUsdController.text = _amountText(transaction.amountUsd);
    _amountLbpController.text = _amountText(transaction.amountLbp);
    _paymentMethodController.text =
        transaction.isCredit || transaction.isDebt || transaction.isTransfer
        ? (transaction.paymentMethod.trim().toLowerCase().contains('wish')
              ? 'Whish Money'
              : 'My Wallet')
        : transaction.paymentMethod;
    _destinationWalletController.text =
        transaction.destinationWalletId ??
        (transaction.isTransfer ? _oppositeWallet(transaction.walletId) : '');
    _notesController.text = transaction.notes;
    _hydratingForm = false;
    _hasLocalEdits = false;
  }

  void _markLocalEdit() {
    if (!_hydratingForm) {
      _hasLocalEdits = true;
    }
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
    if (_selectedType == TransactionType.expense && _paidNow) {
      final balance = _editableWalletBalance();
      if (usd > balance.balanceUsd || lbp > balance.balanceLbp) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Paid Now cannot be more than ${FinanceFormatters.usd(balance.balanceUsd)} or ${FinanceFormatters.lbp(balance.balanceLbp)}.',
            ),
          ),
        );
        return;
      }
    }
    if (_selectedType == TransactionType.transfer) {
      final sourceWallet = _paymentMethodController.text.trim();
      final destinationWallet = _destinationWalletController.text.trim();
      if (sourceWallet.isEmpty ||
          destinationWallet.isEmpty ||
          sourceWallet.toLowerCase() == destinationWallet.toLowerCase()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose different source and destination wallets.'),
          ),
        );
        return;
      }
    }
    final raw = Map<String, String>.from(_transaction.raw)
      ..['amount_usd'] = usd.toString()
      ..['amount_lbp'] = lbp.toString()
      ..['Amount (\$)'] = usd.toString()
      ..['Amount (LBP)'] = lbp.toString()
      ..['wallet_id'] = _paymentMethodController.text.trim()
      ..['destination_wallet_id'] = _selectedType == TransactionType.transfer
          ? _destinationWalletController.text.trim()
          : ''
      ..['settlement_status'] = _showsSettlementStatus
          ? _settlementStatus.label
          : ''
      ..['wallet_direction'] = _selectedType == TransactionType.expense
          ? (_paidNow ? '-1' : '0')
          : '';
    final updated = _transaction.copyWith(
      type: _selectedType,
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim(),
      currency: usd > 0 ? CurrencyCode.usd : CurrencyCode.lbp,
      amount: usd > 0 ? usd : lbp,
      paymentMethod: _paymentMethodController.text.trim(),
      notes: _notesController.text.trim(),
      source: _selectedSource,
      raw: raw,
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
        _hasLocalEdits = false;
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
    final request = await _showSettlementSheet();
    if (request == null || !mounted) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.controller.settleTransaction(
        _transaction,
        walletId: request.walletId,
        amountUsd: request.amountUsd,
        amountLbp: request.amountLbp,
      );
      if (mounted) {
        final updated = widget.controller.transactions.where(
          (item) => item.id == _transaction.id,
        );
        if (updated.isNotEmpty) {
          setState(() {
            _transaction = updated.first;
            _loadFormValues(_transaction);
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _transaction.isSettled
                  ? 'Settlement complete.'
                  : 'Payment saved. The remaining balance is shown below.',
            ),
          ),
        );
      }
    } on FirebaseFinanceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<_SettlementRequest?> _showSettlementSheet() =>
      showModalBottomSheet<_SettlementRequest>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _SettlementSheet(
          target: _transaction,
          initialWalletId: _paymentMethodController.text,
        ),
      );

  List<FinancialTransaction> get _settlementHistory {
    final targetId = _transaction.id;
    if (targetId == null || targetId.isEmpty) {
      return const [];
    }
    final entries =
        widget.controller.transactions
            .where((item) => item.linkedTransactionId == targetId)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Future<void> _showSettlementHistory() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _SettlementHistorySheet(
      isDebt: _transaction.isDebt,
      history: _settlementHistory,
    ),
  );

  void _updateType(TransactionType type) {
    setState(() {
      _selectedType = type;
      if (_paymentMethodController.text.trim().isEmpty) {
        _paymentMethodController.text = 'My Wallet';
      }
      if (type == TransactionType.transfer &&
          _destinationWalletController.text.trim().isEmpty) {
        _destinationWalletController.text = _oppositeWallet(
          _paymentMethodController.text,
        );
      }
      final options = widget.controller.categoryOptionsFor(type);
      if (!options.contains(_categoryController.text.trim())) {
        _categoryController.clear();
      }
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
        updated.raw.toString() != _transaction.raw.toString() ||
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
    setState(() {
      _paymentMethodController.text = walletId;
      if (_selectedType == TransactionType.transfer &&
          _destinationWalletController.text.trim().isEmpty) {
        _destinationWalletController.text = _oppositeWallet(walletId);
      }
    });
  }

  String get _selectedPaymentMethodOption {
    final value = _paymentMethodController.text.trim().toLowerCase();
    if (value.contains('wish')) return 'Whish Money';
    return 'My Wallet';
  }

  void _updateDestinationWallet(String walletId) {
    setState(() => _destinationWalletController.text = walletId);
  }

  void _updatePaidNow(bool paidNow) {
    setState(() => _paidNow = paidNow);
  }

  void _updateSettlementStatus(AccountingSettlementStatus status) {
    setState(() => _settlementStatus = status);
  }

  bool get _showsSettlementStatus =>
      _selectedType == TransactionType.debt ||
      _selectedType == TransactionType.reserveable;

  WalletAccountSummary _editableWalletBalance() {
    final usesWish = _paymentMethodController.text
        .trim()
        .toLowerCase()
        .contains('wish');
    final base = usesWish
        ? widget.controller.walletSummary.wish
        : widget.controller.walletSummary.cash;
    var usd = base.balanceUsd;
    var lbp = base.balanceLbp;
    final sameWallet =
        _transaction.paymentMethod.trim().toLowerCase() ==
        _paymentMethodController.text.trim().toLowerCase();
    if (_transaction.type == TransactionType.expense &&
        _transaction.walletDirection < 0 &&
        sameWallet) {
      usd += _transaction.amountUsd;
      lbp += _transaction.amountLbp;
    }
    return WalletAccountSummary(
      openingUsd: 0,
      openingLbp: 0,
      inflowUsd: usd,
      inflowLbp: lbp,
      outflowUsd: 0,
      outflowLbp: 0,
    );
  }

  String? _amountUsdHint() {
    if (_selectedType == TransactionType.expense && _paidNow) {
      return compactUsdLimit(_editableWalletBalance().balanceUsd);
    }
    return null;
  }

  String? _amountLbpHint() {
    if (_selectedType == TransactionType.expense && _paidNow) {
      return compactLbpLimit(_editableWalletBalance().balanceLbp);
    }
    return null;
  }

  List<TextInputFormatter> _amountInputFormatters(CurrencyCode currency) {
    if (_selectedType != TransactionType.expense || !_paidNow) {
      return const [];
    }
    final balance = _editableWalletBalance();
    return [
      AmountLimitInputFormatter(
        currency == CurrencyCode.usd ? balance.balanceUsd : balance.balanceLbp,
      ),
    ];
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

  String _amountText(double amount) {
    if (amount <= 0) {
      return '';
    }
    return amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
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

  String _oppositeWallet(String walletId) {
    return walletId.trim().toLowerCase().contains('wish')
        ? 'My Wallet'
        : 'Whish Money';
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
    final convertedLabel = transaction.hasMixedAmounts
        ? 'Total as USD'
        : transaction.currency == CurrencyCode.usd
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
              label: transaction.hasMixedAmounts
                  ? 'Amounts'
                  : transaction.currency == CurrencyCode.lbp
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
          if (state._transaction.isDebt || state._transaction.isCredit) ...[
            _SettlementProgressCard(
              transaction: state._transaction,
              history: state._settlementHistory,
              onShowAll: state._showSettlementHistory,
            ),
            const SizedBox(height: 12),
          ],
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
                  if (state._selectedType == TransactionType.expense) ...[
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.payments_rounded),
                          label: Text('Paid Now'),
                        ),
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.schedule_rounded),
                          label: Text('On Credit'),
                        ),
                      ],
                      selected: {state._paidNow},
                      onSelectionChanged: (value) =>
                          state._updatePaidNow(value.first),
                    ),
                  ],
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
                          inputFormatters: state._amountInputFormatters(
                            CurrencyCode.usd,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Amount (\$)',
                            hintText: state._amountUsdHint(),
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
                          inputFormatters: state._amountInputFormatters(
                            CurrencyCode.lbp,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Amount (LBP)',
                            hintText: state._amountLbpHint(),
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
                    options: state.widget.controller.categoryOptionsFor(
                      state._selectedType,
                    ),
                    fallbackOptions: state.widget.controller.categoryOptionsFor(
                      state._selectedType,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? strings.category
                        : null,
                  ),
                  if (state._showsSettlementStatus) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Wallet',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _WalletSelectionButton(
                            label: 'My Wallet',
                            selected:
                                state._selectedPaymentMethodOption ==
                                'My Wallet',
                            onTap: () => state._updateWallet('My Wallet'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _WalletSelectionButton(
                            label: 'Whish Money',
                            isWish: true,
                            selected:
                                state._selectedPaymentMethodOption ==
                                'Whish Money',
                            onTap: () => state._updateWallet('Whish Money'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!state._showsSettlementStatus) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        state._selectedType == TransactionType.transfer
                            ? 'Source wallet'
                            : 'Wallet',
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
                            onSelected: (_) => state._updateWallet('My Wallet'),
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
                            label: const Text('Whish Money'),
                            selected: state._paymentMethodController.text
                                .toLowerCase()
                                .contains('wish'),
                            onSelected: (_) =>
                                state._updateWallet('Whish Money'),
                          ),
                        ),
                      ],
                    ),
                    if (state._selectedType == TransactionType.transfer) ...[
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
                              selected: !state._destinationWalletController.text
                                  .toLowerCase()
                                  .contains('wish'),
                              onSelected: (_) =>
                                  state._updateDestinationWallet('My Wallet'),
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
                              label: const Text('Whish Money'),
                              selected: state._destinationWalletController.text
                                  .toLowerCase()
                                  .contains('wish'),
                              onSelected: (_) =>
                                  state._updateDestinationWallet('Whish Money'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
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
              icon: const Icon(Icons.add_card_rounded),
              label: Text(
                state._transaction.isDebt ? 'Add payment' : 'Add collection',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettlementProgressCard extends StatelessWidget {
  const _SettlementProgressCard({
    required this.transaction,
    required this.history,
    required this.onShowAll,
  });

  final FinancialTransaction transaction;
  final List<FinancialTransaction> history;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final isDebt = transaction.isDebt;
    final totalUsd = transaction.amountUsd;
    final totalLbp = transaction.amountLbp;
    final paidUsd = transaction.settledAmountUsd;
    final paidLbp = transaction.settledAmountLbp;
    final remainingUsd = transaction.remainingAmountUsd;
    final remainingLbp = transaction.remainingAmountLbp;
    final total = totalUsd + totalLbp / 89000;
    final remaining = remainingUsd + remainingLbp / 89000;
    final progress = total <= 0 ? 0.0 : (1 - remaining / total).clamp(0.0, 1.0);
    final color = isDebt ? const Color(0xFFB45309) : const Color(0xFF168A5B);
    final status = transaction.isSettled
        ? 'Done'
        : transaction.settlementStatus == AccountingSettlementStatus.partial
        ? 'Partial'
        : 'Open';
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDebt ? Icons.payments_rounded : Icons.savings_rounded,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isDebt ? 'Amount left to pay' : 'Amount left to collect',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  status,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${FinanceFormatters.usd(remainingUsd)}  |  ${FinanceFormatters.lbp(remainingLbp)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress, minHeight: 6),
            const SizedBox(height: 8),
            Text(
              '${isDebt ? 'Paid' : 'Collected'} ${FinanceFormatters.usd(paidUsd)} | ${FinanceFormatters.lbp(paidLbp)} of ${FinanceFormatters.usd(totalUsd)} | ${FinanceFormatters.lbp(totalLbp)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (history.isNotEmpty) ...[
              const Divider(height: 24),
              for (final entry in history.take(3))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.history_rounded, size: 18, color: color),
                  title: Text(
                    '${isDebt ? 'Payment' : 'Collection'} via ${entry.walletId}',
                  ),
                  subtitle: Text(FinanceFormatters.date(entry.date)),
                  trailing: Text(
                    '${FinanceFormatters.usd(entry.amountUsd)}\n${FinanceFormatters.lbp(entry.amountLbp)}',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: onShowAll,
                icon: const Icon(Icons.list_alt_rounded),
                label: Text('View all ${history.length} payments'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettlementHistorySheet extends StatelessWidget {
  const _SettlementHistorySheet({required this.isDebt, required this.history});

  final bool isDebt;
  final List<FinancialTransaction> history;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              isDebt ? Icons.payments_rounded : Icons.savings_rounded,
            ),
            title: Text(
              isDebt ? 'Debt payment history' : 'Credit collection history',
            ),
            subtitle: Text('${history.length} recorded activities'),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: history.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = history[index];
                return ListTile(
                  leading: Icon(
                    isDebt
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                  ),
                  title: Text(
                    '${isDebt ? 'Payment' : 'Collection'} via ${entry.walletId}',
                  ),
                  subtitle: Text(FinanceFormatters.date(entry.date)),
                  trailing: Text(
                    '${FinanceFormatters.usd(entry.amountUsd)}\n${FinanceFormatters.lbp(entry.amountLbp)}',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              },
            ),
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
