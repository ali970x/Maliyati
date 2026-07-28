import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../widgets/finance_formatters.dart';

enum WalletKind { myWallet, wishMoney }

/// Settings are intentionally scoped to one wallet. There is no shared
/// settings page: changing or resetting one wallet never touches the other.
class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    required this.controller,
    required this.wallet,
  });

  final DashboardController controller;
  final WalletKind wallet;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final TextEditingController _usd;
  late final TextEditingController _lbp;
  bool _saving = false;

  bool get _isWish => widget.wallet == WalletKind.wishMoney;
  String get _title => _isWish ? 'Whish Money' : 'My Wallet';
  Color get _accent =>
      _isWish ? const Color(0xFF7C3AED) : const Color(0xFF5B1E9A);

  @override
  void initState() {
    super.initState();
    final currentSummary = _isWish
        ? widget.controller.walletSummary.wish
        : widget.controller.walletSummary.cash;
    _usd = TextEditingController(text: _numberText(currentSummary.balanceUsd));
    _lbp = TextEditingController(text: _numberText(currentSummary.balanceLbp));
  }

  String _numberText(double value) => value == 0 ? '' : value.toString();
  double? _number(TextEditingController controller) {
    final value = controller.text.trim().replaceAll(',', '');
    if (value.isEmpty) return 0;
    return double.tryParse(value);
  }

  @override
  void dispose() {
    _usd.dispose();
    _lbp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final usd = _number(_usd);
    final lbp = _number(_lbp);
    if (usd == null || lbp == null || usd < 0 || lbp < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid positive USD and LBP balances.'),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await widget.controller.setWalletCurrentBalance(
        isWishMoney: _isWish,
        usd: usd,
        lbp: lbp,
      );
      if (!mounted) return;
      final summary = _isWish
          ? widget.controller.walletSummary.wish
          : widget.controller.walletSummary.cash;
      _usd.text = _numberText(summary.balanceUsd);
      _lbp.text = _numberText(summary.balanceLbp);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_title current balance saved and verified.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save $_title balance: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear $_title completely?'),
        content: Text(
          'This deletes every $_title transaction, including its credit and debt history, then returns $_title to zero. The other wallet remains available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear wallet'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    await widget.controller.resetWalletData(isWishMoney: _isWish);
    _usd.clear();
    _lbp.clear();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_title is now zero and its history was cleared.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _isWish
        ? widget.controller.walletSummary.wish
        : widget.controller.walletSummary.cash;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('$_title settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accent, _accent.withValues(alpha: .72)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: _isWish
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.asset(
                            'assets/branding/wish_money_logo.jpg',
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isWish
                            ? 'Manage your Whish Money balance and tracking separately.'
                            : 'Manage your personal wallet balance and tracking separately.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Current balance',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _BalanceReadout(summary: summary, accent: _accent),
          const SizedBox(height: 22),
          Text(
            'Set current balance',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Enter the amount currently available in each currency. Saving keeps every old transaction and payment log unchanged.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AmountField(
                  label: 'USD',
                  controller: _usd,
                  icon: Icons.attach_money_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AmountField(
                  label: 'LBP',
                  controller: _lbp,
                  icon: Icons.payments_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Dashboard comparison',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Choose what the $_title card compares its live balance against.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<WalletComparisonRange>(
            initialValue: widget.controller.walletComparisonRange(
              isWishMoney: _isWish,
            ),
            decoration: const InputDecoration(
              labelText: 'Compare with',
              prefixIcon: Icon(Icons.compare_arrows_rounded),
            ),
            items: [
              for (final range in WalletComparisonRange.values)
                DropdownMenuItem(value: range, child: Text(range.label)),
            ],
            onChanged: (range) async {
              if (range == null) return;
              await widget.controller.updateWalletComparisonRange(
                isWishMoney: _isWish,
                range: range,
              );
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.account_balance_wallet_rounded),
            label: const Text('Set current balance'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : _reset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text('Clear $_title history'),
          ),
          const SizedBox(height: 8),
          Text(
            'Clear applies only to $_title. The other wallet remains available.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceReadout extends StatelessWidget {
  const _BalanceReadout({required this.summary, required this.accent});
  final WalletAccountSummary summary;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          FinanceFormatters.usd(summary.balanceUsd),
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          FinanceFormatters.lbp(summary.balanceLbp),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.label,
    required this.controller,
    required this.icon,
  });
  final String label;
  final TextEditingController controller;
  final IconData icon;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
  );
}
