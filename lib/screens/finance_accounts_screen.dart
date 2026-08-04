import 'dart:convert';
import 'dart:math';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../models/finance_account.dart';
import '../services/csv_parser.dart';
import '../widgets/finance_formatters.dart';
import '../widgets/responsive_layout.dart';

class FinanceAccountsScreen extends StatefulWidget {
  const FinanceAccountsScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<FinanceAccountsScreen> createState() => _FinanceAccountsScreenState();
}

class _FinanceAccountsScreenState extends State<FinanceAccountsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Personal'),
            Tab(text: 'Shared'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showActions,
        tooltip: 'Account actions',
        child: const Icon(Icons.add_rounded),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _AccountList(
            controller: widget.controller,
            scope: FinanceAccountScope.personal,
            onEdit: _editAccount,
          ),
          _AccountList(
            controller: widget.controller,
            scope: FinanceAccountScope.shared,
            onEdit: _editAccount,
          ),
        ],
      ),
    );
  }

  void _showActions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionRow(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Add account',
                subtitle: 'Create a personal or shared financial account.',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _editAccount();
                },
              ),
              _ActionRow(
                icon: Icons.file_open_outlined,
                title: 'Upload bank statement',
                subtitle: 'Import transactions from CSV or Excel.',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _importStatement();
                },
              ),
              _ActionRow(
                icon: Icons.group_add_outlined,
                title: 'Join account',
                subtitle: 'Access a shared account using its join code.',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _joinAccount();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editAccount([FinanceAccount? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final usd = TextEditingController(
      text: existing == null ? '' : existing.openingUsd.toStringAsFixed(2),
    );
    final lbp = TextEditingController(
      text: existing == null ? '' : existing.openingLbp.toStringAsFixed(0),
    );
    var kind = existing?.kind ?? FinanceAccountKind.cash;
    var scope = existing?.scope ?? FinanceAccountScope.personal;
    var color = existing?.colorValue ?? 0xFF1478C9;
    final saved = await showDialog<FinanceAccount>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New account' : 'Edit account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  readOnly: existing?.isSystem == true,
                  decoration: const InputDecoration(
                    labelText: 'Account name',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<FinanceAccountKind>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Account type'),
                  items: FinanceAccountKind.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_kindLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: existing?.isSystem == true
                      ? null
                      : (value) => setDialogState(
                          () => kind = value ?? FinanceAccountKind.cash,
                        ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<FinanceAccountScope>(
                  segments: const [
                    ButtonSegment(
                      value: FinanceAccountScope.personal,
                      label: Text('Personal'),
                      icon: Icon(Icons.person_outline_rounded),
                    ),
                    ButtonSegment(
                      value: FinanceAccountScope.shared,
                      label: Text('Shared'),
                      icon: Icon(Icons.group_outlined),
                    ),
                  ],
                  selected: {scope},
                  onSelectionChanged: existing?.isSystem == true
                      ? null
                      : (value) => setDialogState(() => scope = value.first),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: usd,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: existing?.isSystem == true
                              ? 'Current USD balance'
                              : 'Opening USD',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: lbp,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: existing?.isSystem == true
                              ? 'Current LBP balance'
                              : 'Opening LBP',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    for (final value in const [
                      0xFF1478C9,
                      0xFF159A9C,
                      0xFF168A5B,
                      0xFF7C3AED,
                      0xFFD97706,
                      0xFFC74949,
                    ])
                      InkWell(
                        onTap: () => setDialogState(() => color = value),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(value),
                            shape: BoxShape.circle,
                            border: color == value
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final accountName = name.text.trim();
                if (accountName.isEmpty) return;
                final id =
                    existing?.id ??
                    '${accountName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
                final joinCode = scope == FinanceAccountScope.shared
                    ? existing?.joinCode ?? _joinCode()
                    : null;
                Navigator.pop(
                  context,
                  FinanceAccount(
                    id: id,
                    name: accountName,
                    kind: kind,
                    scope: scope,
                    colorValue: color,
                    openingUsd:
                        double.tryParse(usd.text.replaceAll(',', '')) ?? 0,
                    openingLbp:
                        double.tryParse(lbp.text.replaceAll(',', '')) ?? 0,
                    joinCode: joinCode,
                    isSystem: existing?.isSystem ?? false,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    usd.dispose();
    lbp.dispose();
    if (saved == null) return;
    try {
      if (saved.isSystem) {
        await widget.controller.setWalletCurrentBalance(
          isWishMoney: saved.id == 'wish_money',
          usd: saved.openingUsd,
          lbp: saved.openingLbp,
        );
        return;
      }
      final accounts = widget.controller.financeAccounts
          .where((item) => item.id != saved.id)
          .toList();
      if (existing == null) {
        await widget.controller.addFinanceAccount(saved);
      } else if (saved.scope == FinanceAccountScope.shared) {
        await widget.controller.addFinanceAccount(saved);
      } else {
        await widget.controller.saveFinanceAccounts([...accounts, saved]);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save account: $error')),
        );
      }
    }
  }

  Future<void> _joinAccount() async {
    final code = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join shared account'),
        content: TextField(
          controller: code,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Join code',
            prefixIcon: Icon(Icons.key_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, code.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    code.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await widget.controller.joinSharedFinanceAccount(value);
      _tabs.animateTo(1);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _importStatement() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    try {
      String csvText;
      if (file.extension?.toLowerCase() == 'xlsx') {
        final workbook = xls.Excel.decodeBytes(bytes);
        final sheet = workbook.tables.values.isEmpty
            ? null
            : workbook.tables.values.first;
        if (sheet == null)
          throw const FormatException('The workbook is empty.');
        csvText = const ListToCsvConverter().convert(
          sheet.rows
              .map(
                (row) =>
                    row.map((cell) => cell?.value?.toString() ?? '').toList(),
              )
              .toList(),
        );
      } else {
        csvText = utf8.decode(bytes, allowMalformed: true);
      }
      final transactions = CsvParser().parse(csvText);
      if (transactions.isEmpty) {
        throw const FormatException(
          'No supported transaction rows were found.',
        );
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import statement?'),
          content: Text(
            '${transactions.length} transactions were detected. They will be added to your current data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await widget.controller.addTransactions(transactions);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${transactions.length} transactions imported.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
      }
    }
  }

  String _joinCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      8,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}

class _AccountList extends StatelessWidget {
  const _AccountList({
    required this.controller,
    required this.scope,
    required this.onEdit,
  });

  final DashboardController controller;
  final FinanceAccountScope scope;
  final ValueChanged<FinanceAccount> onEdit;

  @override
  Widget build(BuildContext context) {
    final accounts = controller.financeAccounts
        .where((item) => item.scope == scope)
        .toList();
    final summaries = accounts.map(
      (item) => controller.accountSummary(item.name),
    );
    final totalUsd = summaries.fold<double>(
      0,
      (sum, item) => sum + item.balanceUsd,
    );
    final totalLbp = accounts
        .map((item) => controller.accountSummary(item.name))
        .fold<double>(0, (sum, item) => sum + item.balanceLbp);
    return ListView(
      padding: AppResponsive.pagePadding(
        context,
      ).copyWith(top: 18, bottom: 100),
      children: [
        _AccountsSummary(
          totalUsd: totalUsd,
          totalLbp: totalLbp,
          incomeUsd: accounts
              .map((item) => controller.accountSummary(item.name))
              .fold(0, (sum, item) => sum + item.incomeUsd),
          expenseUsd: accounts
              .map((item) => controller.accountSummary(item.name))
              .fold(0, (sum, item) => sum + item.expenseUsd),
        ),
        const SizedBox(height: 20),
        Text(
          '${accounts.length} ${scope == FinanceAccountScope.personal ? 'personal' : 'shared'} accounts',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (accounts.isEmpty)
          const _EmptyAccounts()
        else
          ...accounts.map((account) {
            final summary = controller.accountSummary(account.name);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onEdit(account),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _AccountIcon(account: account),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  if (account.joinCode case final code?)
                                    Text('Join code: $code'),
                                ],
                              ),
                            ),
                            Text(
                              FinanceFormatters.usd(summary.balanceUsd),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _Metric(
                                label: 'Income',
                                value: FinanceFormatters.usd(summary.incomeUsd),
                                color: const Color(0xFF168A5B),
                              ),
                            ),
                            Expanded(
                              child: _Metric(
                                label: 'Expenses',
                                value: FinanceFormatters.usd(
                                  summary.expenseUsd,
                                ),
                                color: const Color(0xFFC74949),
                              ),
                            ),
                            Expanded(
                              child: _Metric(
                                label: 'LBP balance',
                                value: FinanceFormatters.lbp(
                                  summary.balanceLbp,
                                ),
                                color: Color(account.colorValue),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _AccountsSummary extends StatelessWidget {
  const _AccountsSummary({
    required this.totalUsd,
    required this.totalLbp,
    required this.incomeUsd,
    required this.expenseUsd,
  });

  final double totalUsd;
  final double totalLbp;
  final double incomeUsd;
  final double expenseUsd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Text('TOTAL BALANCE', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            FinanceFormatters.usd(totalUsd),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(FinanceFormatters.lbp(totalLbp)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Total income',
                  value: FinanceFormatters.usd(incomeUsd),
                  color: const Color(0xFF168A5B),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Total expenses',
                  value: FinanceFormatters.usd(expenseUsd),
                  color: const Color(0xFFC74949),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 4),
      FittedBox(
        child: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}

class _AccountIcon extends StatelessWidget {
  const _AccountIcon({required this.account});
  final FinanceAccount account;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: Color(account.colorValue).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(_kindIcon(account.kind), color: Color(account.colorValue)),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(subtitle),
    onTap: onTap,
  );
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 42),
    child: Column(
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          size: 52,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 12),
        const Text('No accounts here yet.'),
      ],
    ),
  );
}

IconData _kindIcon(FinanceAccountKind kind) => switch (kind) {
  FinanceAccountKind.cash => Icons.payments_outlined,
  FinanceAccountKind.wallet => Icons.account_balance_wallet_outlined,
  FinanceAccountKind.card => Icons.credit_card_rounded,
  FinanceAccountKind.bank => Icons.account_balance_outlined,
};

String _kindLabel(FinanceAccountKind kind) => switch (kind) {
  FinanceAccountKind.cash => 'Cash',
  FinanceAccountKind.wallet => 'Digital wallet',
  FinanceAccountKind.card => 'Card',
  FinanceAccountKind.bank => 'Bank account',
};
