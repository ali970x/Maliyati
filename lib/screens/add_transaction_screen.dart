import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';
import '../services/gemini_transaction_parser.dart';
import '../services/label_normalizer.dart';
import '../widgets/amount_limit_input_formatter.dart';
import '../widgets/finance_formatters.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/transaction_identity.dart';
import 'transaction_detail_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    required this.controller,
    this.initialScript,
    this.autoRunInitialScript = false,
    this.scriptOnly = false,
    this.initialType,
    this.initialWalletId,
  });

  final DashboardController controller;
  final String? initialScript;
  final bool autoRunInitialScript;
  final bool scriptOnly;
  final TransactionType? initialType;
  final String? initialWalletId;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialScript?.trim().isNotEmpty == true ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scriptOnly) {
      return _ScriptAddForm(
        controller: widget.controller,
        initialScript: widget.initialScript,
        autoRunInitialScript: widget.autoRunInitialScript,
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: double.infinity),
        child: Column(
          children: [
            Padding(
              padding: AppResponsive.pagePadding(context).copyWith(bottom: 0),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.edit_note_rounded), text: 'Manual'),
                  Tab(icon: Icon(Icons.data_object_rounded), text: 'By script'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ManualAddForm(
                    controller: widget.controller,
                    initialType: widget.initialType,
                    initialWalletId: widget.initialWalletId,
                  ),
                  _ScriptAddForm(
                    controller: widget.controller,
                    initialScript: widget.initialScript,
                    autoRunInitialScript: widget.autoRunInitialScript,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualAddForm extends StatefulWidget {
  const _ManualAddForm({
    required this.controller,
    this.initialType,
    this.initialWalletId,
  });

  final DashboardController controller;
  final TransactionType? initialType;
  final String? initialWalletId;

  @override
  State<_ManualAddForm> createState() => _ManualAddFormState();
}

enum _ManualStatus { expense, income, credit, debt, transfer }

class _ManualAddFormState extends State<_ManualAddForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountUsdController = TextEditingController();
  final _amountLbpController = TextEditingController();
  final _categoryController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  final _destinationWalletController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now();
  DateTime _createdAt = DateTime.now();
  TransactionType _type = TransactionType.expense;
  _ManualStatus _status = _ManualStatus.expense;
  bool _useWishMoney = false;
  TransactionSource _source = TransactionSource.application;
  FinancialTransaction? _settlementTarget;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? TransactionType.expense;
    _status = switch (_type) {
      TransactionType.income => _ManualStatus.income,
      TransactionType.reserveable => _ManualStatus.credit,
      TransactionType.debt => _ManualStatus.debt,
      TransactionType.transfer => _ManualStatus.transfer,
      _ => _ManualStatus.expense,
    };
    _paymentMethodController.text =
        widget.initialWalletId?.trim().isNotEmpty == true
        ? widget.initialWalletId!.trim()
        : 'My Wallet';
    _useWishMoney = LabelNormalizer.isWishMoney(_paymentMethodController.text);
    _destinationWalletController.text = 'Whish Money';
    if (_isCreditOrDebt) {
      _categoryController.text = _fixedCategory;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountUsdController.dispose();
    _amountLbpController.dispose();
    _categoryController.dispose();
    _paymentMethodController.dispose();
    _destinationWalletController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _typeColor(_type);
    return ListView(
      padding: AppResponsive.pagePadding(context).copyWith(top: 12),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: accent.withValues(alpha: 0.35), width: 1.4),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Manual transaction',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<_ManualStatus>(
                    initialValue: _status,
                    decoration: _coloredDecoration(
                      context,
                      labelText: 'Status',
                      icon: Icons.label_rounded,
                      color: accent,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _ManualStatus.expense,
                        child: Text('Expense'),
                      ),
                      DropdownMenuItem(
                        value: _ManualStatus.income,
                        child: Text('Income'),
                      ),
                      DropdownMenuItem(
                        value: _ManualStatus.credit,
                        child: Text('Credit'),
                      ),
                      DropdownMenuItem(
                        value: _ManualStatus.debt,
                        child: Text('Debt'),
                      ),
                      DropdownMenuItem(
                        value: _ManualStatus.transfer,
                        child: Text('Transfer'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _status = value;
                          _type = switch (value) {
                            _ManualStatus.income => TransactionType.income,
                            _ManualStatus.credit => TransactionType.reserveable,
                            _ManualStatus.debt => TransactionType.debt,
                            _ManualStatus.transfer => TransactionType.transfer,
                            _ManualStatus.expense => TransactionType.expense,
                          };
                          _settlementTarget = null;
                          if (_type == TransactionType.transfer &&
                              _destinationWalletController.text
                                  .trim()
                                  .isEmpty) {
                            _destinationWalletController.text = 'Whish Money';
                          }
                          if (_isCreditOrDebt) {
                            _categoryController.text = _fixedCategory;
                          } else {
                            final allowed = _categoryOptionsFor(_type);
                            if (!allowed.contains(
                              _categoryController.text.trim(),
                            )) {
                              _categoryController.clear();
                            }
                          }
                        });
                      }
                    },
                  ),
                  if (_type == TransactionType.expense ||
                      _type == TransactionType.income) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _chooseSettlementTarget,
                      icon: Icon(
                        _type == TransactionType.expense
                            ? Icons.payments_rounded
                            : Icons.savings_rounded,
                      ),
                      label: Text(
                        _type == TransactionType.expense
                            ? 'Pay an existing debt'
                            : 'Collect an existing credit',
                      ),
                    ),
                    if (_settlementTarget != null) ...[
                      const SizedBox(height: 8),
                      _SettlementTargetTile(
                        target: _settlementTarget!,
                        isDebt: _type == TransactionType.expense,
                        onClear: () => setState(() => _settlementTarget = null),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: _coloredDecoration(
                      context,
                      labelText: 'Title',
                      icon: Icons.title_rounded,
                      color: const Color(0xFF2563EB),
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Enter a title.' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amountUsdController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: _amountInputFormatters(
                            CurrencyCode.usd,
                          ),
                          decoration: _coloredDecoration(
                            context,
                            labelText: 'Amount (\$)',
                            hintText: _amountUsdHint(),
                            icon: Icons.attach_money_rounded,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _amountLbpController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: _amountInputFormatters(
                            CurrencyCode.lbp,
                          ),
                          decoration: _coloredDecoration(
                            context,
                            labelText: 'Amount (LBP)',
                            hintText: _amountLbpHint(),
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_isCreditOrDebt) ...[
                    const SizedBox(height: 12),
                    _ListTextField(
                      controller: _categoryController,
                      label: 'Category',
                      icon: Icons.category_rounded,
                      color: const Color(0xFF9333EA),
                      options: _categoryOptionsFor(_type),
                      fallbackOptions: _categoryOptionsFor(_type),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    _type == TransactionType.transfer
                        ? 'Source wallet'
                        : _type == TransactionType.reserveable
                        ? 'Credit source'
                        : _type == TransactionType.debt
                        ? 'Debt source'
                        : 'Wallet',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _WalletDestinationChoice(
                          label: 'My Wallet',
                          icon: Icons.account_balance_wallet_rounded,
                          selected: !_useWishMoney && !_usesService,
                          onTap: () => setState(() {
                            _useWishMoney = false;
                            _paymentMethodController.text = 'My Wallet';
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _WalletDestinationChoice(
                          label: 'Whish Money',
                          selected: _useWishMoney,
                          imageAsset: 'assets/branding/wish_money_logo.jpg',
                          onTap: () => setState(() {
                            _useWishMoney = true;
                            _paymentMethodController.text = 'Whish Money';
                          }),
                        ),
                      ),
                    ],
                  ),
                  if (_isCreditOrDebt) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: SizedBox(
                        width: 190,
                        child: _WalletDestinationChoice(
                          label: 'Service',
                          icon: Icons.miscellaneous_services_rounded,
                          selected: _usesService,
                          onTap: () => setState(() {
                            _useWishMoney = false;
                            _paymentMethodController.text =
                                LabelNormalizer.service;
                          }),
                        ),
                      ),
                    ),
                  ],
                  if (_type == TransactionType.transfer) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Destination wallet',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _WalletDestinationChoice(
                            label: 'My Wallet',
                            icon: Icons.account_balance_wallet_rounded,
                            selected: !LabelNormalizer.isWishMoney(
                              _destinationWalletController.text,
                            ),
                            onTap: () => setState(
                              () => _destinationWalletController.text =
                                  'My Wallet',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _WalletDestinationChoice(
                            label: 'Whish Money',
                            selected: LabelNormalizer.isWishMoney(
                              _destinationWalletController.text,
                            ),
                            imageAsset: 'assets/branding/wish_money_logo.jpg',
                            onTap: () => setState(
                              () => _destinationWalletController.text =
                                  'Whish Money',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _coloredDecoration(
                      context,
                      labelText: 'Notes',
                      icon: Icons.notes_rounded,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DateRow(
                    label: 'Date',
                    value: FinanceFormatters.date(_date),
                    onTap: () => _pickDate(isCreatedAt: false),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: const Text('Add transaction'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _RecentTransactionsPanel(controller: widget.controller),
      ],
    );
  }

  Future<void> _pickDate({required bool isCreatedAt}) async {
    final initial = isCreatedAt ? _createdAt : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isCreatedAt) {
        _createdAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          initial.hour,
          initial.minute,
          initial.second,
        );
      } else {
        _date = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final usd = _parseAmount(_amountUsdController.text);
    final lbp = _parseAmount(_amountLbpController.text);
    if (usd <= 0 && lbp <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter USD or LBP amount.')));
      return;
    }
    final settlementTarget = _settlementTarget;
    if (settlementTarget != null) {
      setState(() => _isSaving = true);
      try {
        await widget.controller.settleTransaction(
          settlementTarget,
          walletId: _selectedWalletId,
          date: _date,
          amountUsd: usd,
          amountLbp: lbp,
          conversionRate: widget.controller.exchangeRate,
        );
        if (!mounted) return;
        final message = settlementTarget.isDebt
            ? 'Debt payment saved.'
            : 'Credit collection saved.';
        _clear();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }
    if (_type == TransactionType.transfer) {
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
    if (_requiresWalletFunds) {
      final balance = _selectedWalletBalance();
      if (usd > balance.balanceUsd || lbp > balance.balanceLbp) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_type == TransactionType.reserveable ? 'Credit' : 'Paid Now'} cannot be more than ${FinanceFormatters.usd(balance.balanceUsd)} or ${FinanceFormatters.lbp(balance.balanceLbp)} in ${_selectedWalletName()}.',
            ),
          ),
        );
        return;
      }
    }

    final category = _isCreditOrDebt
        ? _fixedCategory
        : _categoryController.text.trim().isEmpty
        ? 'Uncategorized'
        : _categoryController.text.trim();
    final raw = {
      'Date': _date.toIso8601String(),
      'Status': _type.label,
      'Title': _titleController.text.trim(),
      'Amount (\$)': usd.toString(),
      'Amount (LBP)': lbp.toString(),
      'Category': category,
      'Payment Method': _selectedWalletId,
      'Notes': _notesController.text.trim(),
      'Created At': _createdAt.toIso8601String(),
      'Source': _source.label,
      'wallet_id': _selectedWalletId,
      'destination_wallet_id': _destinationWalletController.text.trim(),
      'settlement_status':
          _type == TransactionType.debt || _type == TransactionType.reserveable
          ? AccountingSettlementStatus.open.label
          : '',
      'wallet_direction': switch (_type) {
        TransactionType.income => '1',
        TransactionType.expense => '-1',
        // A credit is money advanced from the selected wallet.  Keeping the
        // direction explicit makes My Wallet and Whish Money behave identically.
        TransactionType.reserveable => _usesService ? '0' : '-1',
        TransactionType.debt => _usesService ? '0' : '1',
        TransactionType.transfer || TransactionType.unknown => '0',
      },
    };
    final transaction = _buildTransaction(
      baseRaw: raw,
      category: category,
      usd: usd,
      lbp: lbp,
    );

    setState(() => _isSaving = true);
    try {
      if (_type == TransactionType.expense) {
        await widget.controller.addExpenseWithPaymentTiming(
          transaction,
          paidNow: true,
        );
      } else {
        await widget.controller.addTransaction(transaction);
      }
      if (!mounted) {
        return;
      }
      _clear();
      final walletName = _selectedWalletName();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _type == TransactionType.reserveable
                ? 'Credit added from $walletName.'
                : 'Transaction added to $walletName.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _clear() {
    _titleController.clear();
    _amountUsdController.clear();
    _amountLbpController.clear();
    _categoryController.clear();
    _paymentMethodController.clear();
    _notesController.clear();
    _paymentMethodController.text = 'My Wallet';
    _destinationWalletController.text = 'Whish Money';
    setState(() {
      _date = DateTime.now();
      _createdAt = DateTime.now();
      _type = TransactionType.expense;
      _status = _ManualStatus.expense;
      _source = TransactionSource.application;
      _settlementTarget = null;
      _useWishMoney = false;
    });
  }

  double _parseAmount(String value) {
    return double.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  }

  List<String> _categoryOptionsFor(TransactionType type) {
    return widget.controller.categoryOptionsFor(type);
  }

  FinancialTransaction _buildTransaction({
    required Map<String, String> baseRaw,
    required String category,
    required double usd,
    required double lbp,
  }) {
    final primaryCurrency = usd > 0 ? CurrencyCode.usd : CurrencyCode.lbp;
    final primaryAmount = usd > 0 ? usd : lbp;
    final raw = Map<String, String>.from(baseRaw)
      ..['amount_usd'] = usd.toString()
      ..['amount_lbp'] = lbp.toString()
      ..['Amount (\$)'] = usd.toString()
      ..['Amount (LBP)'] = lbp.toString();
    return FinancialTransaction(
      createdAt: _createdAt,
      source: _source,
      date: _date,
      hasDate: true,
      type: _type,
      category: category,
      description: _titleController.text.trim(),
      currency: primaryCurrency,
      amount: primaryAmount,
      paymentMethod: _selectedWalletId,
      notes: _notesController.text.trim(),
      raw: raw,
    );
  }

  WalletAccountSummary _selectedWalletBalance() {
    return _useWishMoney
        ? widget.controller.walletSummary.wish
        : widget.controller.walletSummary.cash;
  }

  String _selectedWalletName() {
    return _useWishMoney ? 'Whish Money' : 'My Wallet';
  }

  String get _selectedWalletId => _useWishMoney ? 'Whish Money' : 'My Wallet';

  Color _typeColor(TransactionType type) {
    return switch (type) {
      TransactionType.income => const Color(0xFF168A5B),
      TransactionType.expense => const Color(0xFFC74949),
      TransactionType.reserveable => const Color(0xFFD97706),
      TransactionType.debt => const Color(0xFF7C3AED),
      TransactionType.transfer => const Color(0xFF2563EB),
      TransactionType.unknown => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  InputDecoration _coloredDecoration(
    BuildContext context, {
    required String labelText,
    String? hintText,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(icon, color: color),
      filled: true,
      fillColor: Color.alphaBlend(
        color.withValues(alpha: 0.08),
        theme.colorScheme.surface,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color.withValues(alpha: 0.28)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: 1.5),
      ),
    );
  }

  String? _amountUsdHint() {
    if (_requiresWalletFunds) {
      return compactUsdLimit(_selectedWalletBalance().balanceUsd);
    }
    return null;
  }

  String? _amountLbpHint() {
    if (_requiresWalletFunds) {
      return compactLbpLimit(_selectedWalletBalance().balanceLbp);
    }
    return null;
  }

  List<TextInputFormatter> _amountInputFormatters(CurrencyCode currency) {
    if (!_requiresWalletFunds) {
      return const [];
    }
    final balance = _selectedWalletBalance();
    return [
      AmountLimitInputFormatter(
        currency == CurrencyCode.usd ? balance.balanceUsd : balance.balanceLbp,
      ),
    ];
  }

  bool get _requiresWalletFunds =>
      (_type == TransactionType.reserveable && !_usesService) ||
      _type == TransactionType.expense;

  bool get _usesService =>
      LabelNormalizer.isService(_paymentMethodController.text);

  bool get _isCreditOrDebt =>
      _type == TransactionType.reserveable || _type == TransactionType.debt;

  String get _fixedCategory =>
      _type == TransactionType.debt ? 'Debt' : 'Credit';

  Future<void> _chooseSettlementTarget() async {
    final isDebt = _type == TransactionType.expense;
    final candidates =
        widget.controller.transactions
            .where(
              (transaction) =>
                  !transaction.isSettlementEntry &&
                  transaction.hasOutstandingBalance &&
                  (isDebt ? transaction.isDebt : transaction.isCredit),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final target = await showModalBottomSheet<FinancialTransaction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  isDebt ? 'Choose debt to pay' : 'Choose credit to collect',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Expanded(
                child: candidates.isEmpty
                    ? Center(
                        child: Text(
                          isDebt
                              ? 'No open debts to pay.'
                              : 'No open credits to collect.',
                        ),
                      )
                    : ListView.separated(
                        itemCount: candidates.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = candidates[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                isDebt
                                    ? Icons.payments_rounded
                                    : Icons.savings_rounded,
                              ),
                            ),
                            title: Text(
                              item.description.isEmpty
                                  ? item.category
                                  : item.description,
                            ),
                            subtitle: Text(
                              '${FinanceFormatters.shortDate(item.date)} · ${item.category}',
                            ),
                            trailing: Text(
                              '${FinanceFormatters.usd(item.remainingAmountUsd)}\n${FinanceFormatters.lbp(item.remainingAmountLbp)}',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onTap: () => Navigator.of(context).pop(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (target == null || !mounted) return;
    setState(() {
      _settlementTarget = target;
      _titleController.text = target.isDebt
          ? 'Debt payment: ${target.description}'
          : 'Credit collection: ${target.description}';
      _categoryController.text = target.category;
      _amountUsdController.text = _amountText(target.remainingAmountUsd);
      _amountLbpController.text = _amountText(target.remainingAmountLbp);
    });
  }

  String _amountText(double value) => value <= 0
      ? ''
      : value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
}

class _SettlementTargetTile extends StatelessWidget {
  const _SettlementTargetTile({
    required this.target,
    required this.isDebt,
    required this.onClear,
  });

  final FinancialTransaction target;
  final bool isDebt;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Theme.of(context).colorScheme.primaryContainer,
    child: ListTile(
      leading: Icon(isDebt ? Icons.payments_rounded : Icons.savings_rounded),
      title: Text(
        target.description.isEmpty ? target.category : target.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        'Remaining: ${FinanceFormatters.usd(target.remainingAmountUsd)} | ${FinanceFormatters.lbp(target.remainingAmountLbp)}',
      ),
      trailing: IconButton(
        tooltip: 'Choose another',
        onPressed: onClear,
        icon: const Icon(Icons.close_rounded),
      ),
    ),
  );
}

class _ScriptAddForm extends StatefulWidget {
  const _ScriptAddForm({
    required this.controller,
    this.initialScript,
    this.autoRunInitialScript = false,
  });

  final DashboardController controller;
  final String? initialScript;
  final bool autoRunInitialScript;

  @override
  State<_ScriptAddForm> createState() => _ScriptAddFormState();
}

class _ScriptAddFormState extends State<_ScriptAddForm> {
  final _scriptController = TextEditingController();
  final _parser = GeminiTransactionParser();
  List<SmartTransactionAction> _preview = const [];
  String? _error;
  bool _isSaving = false;
  int _completed = 0;
  int _total = 0;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    final script = widget.initialScript?.trim() ?? '';
    if (script.isEmpty) {
      return;
    }
    _scriptController.text = script;
    try {
      _preview = _parser.parseActions(script);
      if (widget.autoRunInitialScript && _preview.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _save();
          }
        });
      }
    } catch (error) {
      _error = error.toString();
    }
  }

  @override
  void dispose() {
    _scriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasInput = _scriptController.text.trim().isNotEmpty;
    final statusColor = _preview.isEmpty
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.primary;
    return ListView(
      padding: AppResponsive.pagePadding(context).copyWith(top: 12),
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: .24)),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: .06),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .09),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.code_rounded, color: statusColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _preview.isEmpty ? 'Script input' : _inputStatus(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _paste,
                      tooltip: 'Paste',
                      icon: const Icon(Icons.content_paste_rounded),
                    ),
                    IconButton(
                      onPressed: hasInput ? _clear : null,
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              TextField(
                controller: _scriptController,
                minLines: 12,
                maxLines: 18,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.35,
                ),
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  hintText:
                      'Paste one transaction JSON or a batch here.\nActions: add, edit, delete, settle.\nStatuses: Expense, Income, Credit, Debt, Transfer.',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
                onChanged: (_) => _parsePreview(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isSaving || _preview.isEmpty ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add_check_rounded),
                label: Text(_insertLabel()),
              ),
            ),
          ],
        ),
        if (_isSaving || _total > 0) ...[
          const SizedBox(height: 12),
          _InsertProgressCard(
            completed: _completed,
            total: _total,
            startedAt: _startedAt,
            isSaving: _isSaving,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          _MessageBox(message: _error!, isError: true),
        ],
        if (_preview.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ScriptPreviewGrid(
            actions: _preview,
            exchangeRate: widget.controller.exchangeRate,
          ),
        ],
        const SizedBox(height: 12),
        _RecentTransactionsPanel(controller: widget.controller),
      ],
    );
  }

  String _inputStatus() {
    if (_error != null) {
      return 'Needs a valid JSON transaction';
    }
    if (_preview.isEmpty) {
      return 'Input by code';
    }
    if (_preview.length == 1) {
      return '1 action detected';
    }
    return '${_preview.length} actions detected';
  }

  String _insertLabel() {
    if (_preview.length <= 1) {
      return 'Run action';
    }
    return 'Run ${_preview.length} actions';
  }

  void _parsePreview() {
    try {
      final value = _scriptController.text.trim();
      setState(() {
        _preview = value.isEmpty ? const [] : _parser.parseActions(value);
        _error = null;
      });
    } catch (error) {
      setState(() {
        _preview = const [];
        _error = error.toString();
      });
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      return;
    }
    _scriptController.text = text;
    _parsePreview();
  }

  Future<void> _save() async {
    final confirmed = await _confirmImport();
    if (!confirmed) {
      return;
    }
    setState(() {
      _isSaving = true;
      _completed = 0;
      _total = _preview.length;
      _startedAt = DateTime.now();
      _error = null;
    });
    try {
      final result = await widget.controller.executeSmartTransactionScript(
        _scriptController.text,
        onProgress: (completed, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            _completed = completed;
            _total = total;
          });
        },
      );
      if (!mounted) {
        return;
      }
      _clear();
      _showExecutionResult(result);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showExecutionResult(SmartActionExecutionSummary result) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.hasFailures ? 'Completed with issues' : 'Done'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total actions: ${result.total}'),
            const SizedBox(height: 8),
            Text('Added: ${result.added}'),
            Text('Edited: ${result.edited}'),
            Text('Deleted: ${result.deleted}'),
            Text('Settled: ${result.settled}'),
            if (result.failures.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Not completed:'),
              const SizedBox(height: 6),
              for (final failure in result.failures.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('- $failure'),
                ),
              if (result.failures.length > 5)
                Text('+ ${result.failures.length - 5} more issue(s)'),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmImport() async {
    final income = _preview
        .where((item) => item.transaction?.type == TransactionType.income)
        .length;
    final expense = _preview
        .where((item) => item.transaction?.type == TransactionType.expense)
        .length;
    final reserveable = _preview
        .where((item) => item.transaction?.type == TransactionType.reserveable)
        .length;
    final add = _preview
        .where((item) => item.type == SmartTransactionActionType.add)
        .length;
    final edit = _preview
        .where((item) => item.type == SmartTransactionActionType.edit)
        .length;
    final delete = _preview
        .where((item) => item.type == SmartTransactionActionType.delete)
        .length;
    final settle = _preview
        .where((item) => item.type == SmartTransactionActionType.settle)
        .length;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm smart actions'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to run ${_preview.length} action(s)?',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ActionCountChip(label: 'Add', value: add),
                    _ActionCountChip(label: 'Edit', value: edit),
                    _ActionCountChip(label: 'Delete', value: delete),
                    _ActionCountChip(label: 'Settle', value: settle),
                    _ActionCountChip(label: 'Income', value: income),
                    _ActionCountChip(label: 'Expense', value: expense),
                    _ActionCountChip(label: 'Credit', value: reserveable),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Actions to apply',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < _preview.length; index += 1)
                  _ConfirmActionRow(index: index + 1, action: _preview[index]),
                const SizedBox(height: 8),
                Text(
                  'If anything is wrong, choose Review and edit the code before running.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Review'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Run now'),
          ),
        ],
      ),
    );
    return approved ?? false;
  }

  void _clear() {
    _scriptController.clear();
    setState(() {
      _preview = const [];
      _error = null;
      _completed = 0;
      _total = 0;
      _startedAt = null;
    });
  }
}

class _ActionCountChip extends StatelessWidget {
  const _ActionCountChip({required this.label, required this.value});

  final String label;
  final int value;

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
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ConfirmActionRow extends StatelessWidget {
  const _ConfirmActionRow({required this.index, required this.action});

  final int index;
  final SmartTransactionAction action;

  @override
  Widget build(BuildContext context) {
    final transaction = action.transaction;
    final color = switch (action.type) {
      SmartTransactionActionType.add => const Color(0xFF168A5B),
      SmartTransactionActionType.edit => const Color(0xFF2563EB),
      SmartTransactionActionType.delete => const Color(0xFFC74949),
      SmartTransactionActionType.settle => const Color(0xFF0F766E),
    };
    final title =
        transaction?.description ??
        action.targetTitle ??
        action.targetId ??
        'Target transaction';
    final detail = transaction == null
        ? 'Target: ${action.targetId ?? action.targetTitle ?? '-'}'
        : '${transaction.type.label} - ${transaction.category} - ${FinanceFormatters.amount(transaction)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Text(
              '$index',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${action.label}: $title',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (action.targetId?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    'ID: ${action.targetId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
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

class _ScriptPreviewGrid extends StatelessWidget {
  const _ScriptPreviewGrid({required this.actions, required this.exchangeRate});

  final List<SmartTransactionAction> actions;
  final double exchangeRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check_rounded),
                const SizedBox(width: 8),
                Text(
                  'Detected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  '${actions.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final action in actions)
              _ActionPreviewTile(action: action, exchangeRate: exchangeRate),
          ],
        ),
      ),
    );
  }
}

class _ActionPreviewTile extends StatelessWidget {
  const _ActionPreviewTile({required this.action, required this.exchangeRate});

  final SmartTransactionAction action;
  final double exchangeRate;

  @override
  Widget build(BuildContext context) {
    final transaction = action.transaction;
    final color = switch (action.type) {
      SmartTransactionActionType.add => const Color(0xFF168A5B),
      SmartTransactionActionType.edit => const Color(0xFF2563EB),
      SmartTransactionActionType.delete => const Color(0xFFC74949),
      SmartTransactionActionType.settle => const Color(0xFF0F766E),
    };
    final icon = switch (action.type) {
      SmartTransactionActionType.add => Icons.add_task_rounded,
      SmartTransactionActionType.edit => Icons.edit_note_rounded,
      SmartTransactionActionType.delete => Icons.delete_outline_rounded,
      SmartTransactionActionType.settle => Icons.verified_rounded,
    };
    final title =
        transaction?.description ??
        action.targetTitle ??
        action.targetId ??
        'Target transaction';
    final subtitle = transaction == null
        ? 'Target: ${action.targetId ?? action.targetTitle ?? ''}'
        : '${transaction.type.label} - ${transaction.category} - ${FinanceFormatters.date(transaction.date)}';
    final idText = transaction == null
        ? (action.targetId?.trim() ?? '')
        : TransactionIdentity.shortId(transaction);
    return Card(
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(
          idText.isEmpty || idText == 'No ID'
              ? subtitle
              : '$subtitle\nID: $idText',
        ),
        isThreeLine: idText.isNotEmpty && idText != 'No ID',
        trailing: Text(
          action.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _InsertProgressCard extends StatelessWidget {
  const _InsertProgressCard({
    required this.completed,
    required this.total,
    required this.startedAt,
    required this.isSaving,
  });

  final int completed;
  final int total;
  final DateTime? startedAt;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeTotal = total <= 0 ? 1 : total;
    final progress = (completed / safeTotal).clamp(0.0, 1.0);
    final remaining = (total - completed).clamp(0, total);
    final eta = _etaText();
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSaving
                      ? Icons.sync_rounded
                      : Icons.check_circle_outline_rounded,
                  color: isSaving
                      ? theme.colorScheme.primary
                      : const Color(0xFF168A5B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSaving ? 'Running actions' : 'Actions complete',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '$completed / $total',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ProgressPill(label: 'Done', value: '$completed'),
                _ProgressPill(label: 'Remaining', value: '$remaining'),
                _ProgressPill(label: 'ETA', value: eta),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _etaText() {
    if (!isSaving || completed <= 0 || startedAt == null || total <= 0) {
      return isSaving ? 'calculating' : '0s';
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

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.label, required this.value});

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

class _RecentTransactionsPanel extends StatefulWidget {
  const _RecentTransactionsPanel({required this.controller});

  final DashboardController controller;

  @override
  State<_RecentTransactionsPanel> createState() =>
      _RecentTransactionsPanelState();
}

class _RecentTransactionsPanelState extends State<_RecentTransactionsPanel> {
  final _panelKey = GlobalKey();

  void _bringPanelIntoView(bool expanded) {
    if (!expanded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 80), () async {
        final target = _panelKey.currentContext;
        if (target == null || !mounted) return;
        await Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = widget.controller.transactions.toList()
      ..sort(
        (a, b) => (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date),
      );
    return Card(
      key: _panelKey,
      elevation: 0,
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: _bringPanelIntoView,
        leading: Icon(Icons.history_rounded, color: theme.colorScheme.primary),
        title: const Text(
          'Recent transactions',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text('Tap any row to edit it'),
        children: [
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No transactions yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final transaction in recent.take(8))
              ListTile(
                leading: Icon(
                  transaction.isIncome
                      ? Icons.south_west_rounded
                      : transaction.isReserveable
                      ? Icons.request_quote_rounded
                      : Icons.north_east_rounded,
                ),
                title: Text(
                  transaction.description.isEmpty
                      ? transaction.category
                      : transaction.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${transaction.type.label} - ${transaction.source.label} - ID: ${TransactionIdentity.shortId(transaction)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  FinanceFormatters.amount(transaction),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TransactionDetailScreen(
                        controller: widget.controller,
                        transaction: transaction,
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}

class _WalletDestinationChoice extends StatelessWidget {
  const _WalletDestinationChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.imageAsset,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF286BEA);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: .12)
              : Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? accent
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .80),
                borderRadius: BorderRadius.circular(9),
              ),
              child: imageAsset == null
                  ? Icon(icon, color: accent, size: 19)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.asset(imageAsset!, fit: BoxFit.cover),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: accent, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ListTextField extends StatelessWidget {
  const _ListTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.color,
    required this.options,
    required this.fallbackOptions,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color color;
  final List<String> options;
  final List<String> fallbackOptions;

  @override
  Widget build(BuildContext context) {
    final values = {...options, ...fallbackOptions}.toList()..sort();
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        filled: true,
        fillColor: Color.alphaBlend(
          color.withValues(alpha: 0.08),
          Theme.of(context).colorScheme.surface,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color.withValues(alpha: 0.28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
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

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
