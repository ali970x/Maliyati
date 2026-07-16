import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';
import '../services/gemini_transaction_parser.dart';
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
  });

  final DashboardController controller;
  final String? initialScript;
  final bool autoRunInitialScript;

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
                  _ManualAddForm(controller: widget.controller),
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
  const _ManualAddForm({required this.controller});

  final DashboardController controller;

  @override
  State<_ManualAddForm> createState() => _ManualAddFormState();
}

class _ManualAddFormState extends State<_ManualAddForm> {
  static const _expenseCategories = [
    'Masrouf bayt',
    'Transportation',
    'Dyefe',
    'Dyoune',
    'Eshtiraket',
    'Na2rashe',
    'Other expense',
  ];
  static const _incomeCategories = [
    'Income internet',
    'Income zougeib',
    'Income other',
    'Income aboudi',
  ];
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountUsdController = TextEditingController();
  final _amountLbpController = TextEditingController();
  final _categoryController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now();
  DateTime _createdAt = DateTime.now();
  TransactionType _type = TransactionType.expense;
  TransactionSource _source = TransactionSource.application;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountUsdController.dispose();
    _amountLbpController.dispose();
    _categoryController.dispose();
    _paymentMethodController.dispose();
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
                  DropdownButtonFormField<TransactionType>(
                    initialValue: _type,
                    decoration: _coloredDecoration(
                      context,
                      labelText: 'Status',
                      icon: Icons.label_rounded,
                      color: accent,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: TransactionType.expense,
                        child: Text('Expense'),
                      ),
                      DropdownMenuItem(
                        value: TransactionType.income,
                        child: Text('Income'),
                      ),
                      DropdownMenuItem(
                        value: TransactionType.reserveable,
                        child: Text('Receivables'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _type = value;
                          final allowed = _categoryOptionsFor(value);
                          if (!allowed.contains(
                            _categoryController.text.trim(),
                          )) {
                            _categoryController.clear();
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TransactionSource>(
                    initialValue: _source,
                    decoration: _coloredDecoration(
                      context,
                      labelText: 'Source',
                      icon: Icons.source_rounded,
                      color: const Color(0xFF0F766E),
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
                        setState(() => _source = value);
                      }
                    },
                  ),
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
                          decoration: _coloredDecoration(
                            context,
                            labelText: 'Amount (\$)',
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
                          decoration: _coloredDecoration(
                            context,
                            labelText: 'Amount (LBP)',
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ListTextField(
                    controller: _categoryController,
                    label: 'Category',
                    icon: Icons.category_rounded,
                    color: const Color(0xFF9333EA),
                    options: _categoryOptionsFor(_type),
                    fallbackOptions: _categoryOptionsFor(_type),
                  ),
                  const SizedBox(height: 12),
                  _ListTextField(
                    controller: _paymentMethodController,
                    label: 'Payment Method',
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFFD97706),
                    options: widget.controller.paymentMethodOptions,
                    fallbackOptions: const ['Cash', 'Whish money', 'Paid'],
                  ),
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
                  const SizedBox(height: 12),
                  _DateRow(
                    label: 'Created At',
                    value: FinanceFormatters.dateTime(_createdAt),
                    onTap: () => _pickDate(isCreatedAt: true),
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

    final currency = lbp > 0 ? CurrencyCode.lbp : CurrencyCode.usd;
    final amount = lbp > 0 ? lbp : usd;
    final category = _categoryController.text.trim().isEmpty
        ? 'Uncategorized'
        : _categoryController.text.trim();
    final raw = {
      'Date': _date.toIso8601String(),
      'Status': _type.label,
      'Title': _titleController.text.trim(),
      'Amount (\$)': usd.toString(),
      'Amount (LBP)': lbp.toString(),
      'Category': category,
      'Payment Method': _paymentMethodController.text.trim(),
      'Notes': _notesController.text.trim(),
      'Created At': _createdAt.toIso8601String(),
      'Source': _source.label,
    };
    final transaction = FinancialTransaction(
      createdAt: _createdAt,
      source: _source,
      date: _date,
      hasDate: true,
      type: _type,
      category: category,
      description: _titleController.text.trim(),
      currency: currency,
      amount: amount,
      paymentMethod: _paymentMethodController.text.trim(),
      notes: _notesController.text.trim(),
      raw: raw,
    );

    setState(() => _isSaving = true);
    try {
      await widget.controller.addTransaction(transaction);
      if (!mounted) {
        return;
      }
      _clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction added.')));
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
    setState(() {
      _date = DateTime.now();
      _createdAt = DateTime.now();
      _type = TransactionType.expense;
      _source = TransactionSource.application;
    });
  }

  double _parseAmount(String value) {
    return double.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  }

  List<String> _categoryOptionsFor(TransactionType type) {
    return switch (type) {
      TransactionType.income => _incomeCategories,
      TransactionType.expense => _expenseCategories,
      TransactionType.reserveable => const ['Receivables', 'Dyoune'],
      TransactionType.unknown => const ['Uncategorized'],
    };
  }

  Color _typeColor(TransactionType type) {
    return switch (type) {
      TransactionType.income => const Color(0xFF168A5B),
      TransactionType.expense => const Color(0xFFC74949),
      TransactionType.reserveable => const Color(0xFFD97706),
      TransactionType.unknown => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  InputDecoration _coloredDecoration(
    BuildContext context, {
    required String labelText,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: labelText,
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
  bool _showExampleAction = false;
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
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
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
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.code_rounded, color: statusColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _preview.isEmpty ? 'Input by code' : _inputStatus(),
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
                      onPressed: _revealExampleAction,
                      tooltip: 'More',
                      icon: const Icon(Icons.more_horiz_rounded),
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
                  hintText: 'Paste one transaction JSON or a batch here...',
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
        if (_showExampleAction) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _insertExample,
              icon: const Icon(Icons.code_rounded),
              label: const Text('Example'),
            ),
          ),
        ],
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
                    _ActionCountChip(label: 'Income', value: income),
                    _ActionCountChip(label: 'Expense', value: expense),
                    _ActionCountChip(label: 'Reserveable', value: reserveable),
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
      _showExampleAction = false;
    });
  }

  Future<void> _revealExampleAction() async {
    setState(() => _showExampleAction = false);
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) {
      return;
    }
    setState(() => _showExampleAction = true);
  }

  void _insertExample() {
    _scriptController.text = '''[
  {
    "action": "add_transaction",
    "date": "2026-07-15",
    "status": "Expense",
    "title": "10 kg tomatoes",
    "amount_lbp": 450000,
    "category": "Masrouf bayt",
    "payment_method": "Cash",
    "notes": "Voice entry"
  },
  {
    "action": "edit_transaction",
    "target_title": "Cable payment",
    "date": "2026-07-15",
    "status": "Income",
    "title": "Cable payment",
    "amount_usd": 25,
    "category": "Income internet",
    "payment_method": "Whish money"
  },
  {
    "action": "delete_transaction",
    "target_title": "Old test expense"
  }
]''';
    _parsePreview();
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
    };
    final icon = switch (action.type) {
      SmartTransactionActionType.add => Icons.add_task_rounded,
      SmartTransactionActionType.edit => Icons.edit_note_rounded,
      SmartTransactionActionType.delete => Icons.delete_outline_rounded,
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

class _RecentTransactionsPanel extends StatelessWidget {
  const _RecentTransactionsPanel({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = controller.transactions.take(8).toList(growable: false);
    return Card(
      elevation: 0,
      child: ExpansionTile(
        initiallyExpanded: false,
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
            for (final transaction in recent)
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
                        controller: controller,
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
