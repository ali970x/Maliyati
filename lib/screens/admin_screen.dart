import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';
import '../services/firebase_finance_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String? _selectedUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.refreshAdminUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final users = controller.adminUsers;
    final fallbackUid = users.isEmpty ? null : users.first.user.uid;
    AdminUserSnapshot? selected;
    for (final item in users) {
      if (item.user.uid == (_selectedUid ?? fallbackUid)) {
        selected = item;
        break;
      }
    }
    if (_selectedUid == null && selected != null) {
      _selectedUid = selected.user.uid;
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Admin',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _editUser(),
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Add user profile'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 290,
                  child: _UsersList(
                    users: users,
                    selectedUid: selected?.user.uid,
                    onSelected: (uid) => setState(() => _selectedUid = uid),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: selected == null
                      ? const Center(child: Text('No users yet.'))
                      : Builder(
                          builder: (context) {
                            final active = selected!;
                            return _AdminUserPanel(
                              snapshot: active,
                              onEditUser: () => _editUser(active.user),
                              onDeleteUser: () => _deleteUser(active.user),
                              onEditTransaction: (transaction) =>
                                  _editTransaction(
                                    active.user.uid,
                                    transaction,
                                  ),
                              onDeleteTransaction: (transaction) =>
                                  _deleteTransaction(
                                    active.user.uid,
                                    transaction,
                                  ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editUser([FinanceUser? user]) async {
    final saved = await showDialog<FinanceUser>(
      context: context,
      builder: (context) => _UserDialog(user: user),
    );
    if (saved == null) {
      return;
    }
    await widget.controller.saveAdminUserProfile(saved);
    setState(() => _selectedUid = saved.uid);
  }

  Future<void> _deleteUser(FinanceUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user data?'),
        content: Text(
          'This deletes Firestore profile and transactions for ${user.email ?? user.uid}. It does not delete the Firebase Auth login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete data'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.controller.deleteAdminUserData(user.uid);
      setState(() => _selectedUid = null);
    }
  }

  Future<void> _editTransaction(
    String uid,
    FinancialTransaction transaction,
  ) async {
    final saved = await showDialog<FinancialTransaction>(
      context: context,
      builder: (context) => _TransactionDialog(transaction: transaction),
    );
    if (saved != null) {
      await widget.controller.saveAdminTransaction(
        uid: uid,
        transaction: saved,
      );
    }
  }

  Future<void> _deleteTransaction(
    String uid,
    FinancialTransaction transaction,
  ) async {
    final id = transaction.id;
    if (id == null || id.isEmpty) {
      return;
    }
    await widget.controller.deleteAdminTransaction(uid: uid, transactionId: id);
  }
}

class _UsersList extends StatelessWidget {
  const _UsersList({
    required this.users,
    required this.selectedUid,
    required this.onSelected,
  });

  final List<AdminUserSnapshot> users;
  final String? selectedUid;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = users[index];
        final user = item.user;
        final selected = user.uid == selectedUid;
        return ListTile(
          selected: selected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: CircleAvatar(
            child: Text((user.accountId ?? user.email ?? '?').characters.first),
          ),
          title: Text(
            user.displayName?.isNotEmpty == true
                ? user.displayName!
                : user.accountId ?? 'User',
          ),
          subtitle: Text(
            '${user.email ?? ''}\n${item.transactions.length} rows',
          ),
          isThreeLine: true,
          onTap: () => onSelected(user.uid),
        );
      },
    );
  }
}

class _AdminUserPanel extends StatelessWidget {
  const _AdminUserPanel({
    required this.snapshot,
    required this.onEditUser,
    required this.onDeleteUser,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
  });

  final AdminUserSnapshot snapshot;
  final VoidCallback onEditUser;
  final VoidCallback onDeleteUser;
  final ValueChanged<FinancialTransaction> onEditTransaction;
  final ValueChanged<FinancialTransaction> onDeleteTransaction;

  @override
  Widget build(BuildContext context) {
    final transactions = snapshot.transactions;
    final income = _sum(transactions, true);
    final expense = _sum(transactions, false);
    final topCategories = _topCategories(transactions);
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                snapshot.user.email ??
                    snapshot.user.accountId ??
                    snapshot.user.uid,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              onPressed: onEditUser,
              icon: const Icon(Icons.edit_rounded),
            ),
            IconButton(
              onPressed: onDeleteUser,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatTile(label: 'Transactions', value: '${transactions.length}'),
            _StatTile(label: 'Income USD', value: income.toStringAsFixed(2)),
            _StatTile(label: 'Expense USD', value: expense.toStringAsFixed(2)),
            _StatTile(
              label: 'Net USD',
              value: (income - expense).toStringAsFixed(2),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Top categories', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final item in topCategories)
          ListTile(
            dense: true,
            leading: const Icon(Icons.category_rounded),
            title: Text(item.key),
            trailing: Text(item.value.toStringAsFixed(2)),
          ),
        const SizedBox(height: 18),
        Text(
          'Latest transactions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final transaction in transactions.take(50))
          ListTile(
            leading: Icon(
              transaction.isIncome
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
            ),
            title: Text(transaction.description),
            subtitle: Text(
              '${transaction.id ?? ''} • ${transaction.type.label} • ${transaction.category}',
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                Text(
                  '${transaction.amount.toStringAsFixed(2)} ${transaction.currency.label}',
                ),
                IconButton(
                  onPressed: () => onEditTransaction(transaction),
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  onPressed: () => onDeleteTransaction(transaction),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static double _sum(List<FinancialTransaction> transactions, bool income) {
    return transactions
        .where((item) => income ? item.isIncome : item.isExpense)
        .fold<double>(0, (sum, item) => sum + item.amountInUsd(89000));
  }

  static List<MapEntry<String, double>> _topCategories(
    List<FinancialTransaction> transactions,
  ) {
    final totals = <String, double>{};
    for (final item in transactions) {
      totals[item.category] =
          (totals[item.category] ?? 0) + item.amountInUsd(89000);
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(4).toList();
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({this.user});

  final FinanceUser? user;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  late final _uid = TextEditingController(text: widget.user?.uid ?? '');
  late final _accountId = TextEditingController(
    text: widget.user?.accountId ?? '',
  );
  late final _email = TextEditingController(text: widget.user?.email ?? '');
  late final _name = TextEditingController(
    text: widget.user?.displayName ?? '',
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user == null ? 'Add user profile' : 'Edit user'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _uid,
              decoration: const InputDecoration(labelText: 'UID'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _accountId,
              decoration: const InputDecoration(labelText: 'User ID'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
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
          onPressed: () => Navigator.pop(
            context,
            FinanceUser(
              uid: _uid.text.trim(),
              accountId: _accountId.text.trim(),
              email: _email.text.trim(),
              displayName: _name.text.trim(),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _TransactionDialog extends StatefulWidget {
  const _TransactionDialog({required this.transaction});

  final FinancialTransaction transaction;

  @override
  State<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<_TransactionDialog> {
  late final _title = TextEditingController(
    text: widget.transaction.description,
  );
  late final _category = TextEditingController(
    text: widget.transaction.category,
  );
  late final _amount = TextEditingController(
    text: widget.transaction.amount.toString(),
  );
  late final _payment = TextEditingController(
    text: widget.transaction.paymentMethod,
  );
  late TransactionType _type = widget.transaction.type;
  late CurrencyCode _currency = widget.transaction.currency;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit transaction'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<TransactionType>(
              initialValue: _type,
              items: TransactionType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _payment,
              decoration: const InputDecoration(labelText: 'Payment method'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<CurrencyCode>(
                    initialValue: _currency,
                    items: CurrencyCode.values
                        .map(
                          (currency) => DropdownMenuItem(
                            value: currency,
                            child: Text(currency.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _currency = value ?? _currency),
                    decoration: const InputDecoration(labelText: 'Currency'),
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
          onPressed: () => Navigator.pop(
            context,
            widget.transaction.copyWith(
              type: _type,
              description: _title.text.trim(),
              category: _category.text.trim(),
              paymentMethod: _payment.text.trim(),
              amount:
                  double.tryParse(_amount.text.trim()) ??
                  widget.transaction.amount,
              currency: _currency,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
