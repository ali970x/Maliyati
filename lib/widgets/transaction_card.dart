import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/transaction.dart';
import 'finance_formatters.dart';

/// A compact transaction row. Wallet branding deliberately stays in the
/// wallet history screen, so a transfer does not look like a wallet card.
class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    required this.exchangeRate,
    required this.strings,
    this.onTap,
    this.onLongPress,
    this.trailingAction,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  final FinancialTransaction transaction;
  final double exchangeRate;
  final AppStrings strings;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailingAction;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (transaction.type) {
      TransactionType.income => const Color(0xFF168A5B),
      TransactionType.expense => const Color(0xFFC74949),
      TransactionType.reserveable => const Color(0xFFD97706),
      TransactionType.debt => const Color(0xFF7C3AED),
      TransactionType.transfer => const Color(0xFF2563EB),
      TransactionType.unknown => theme.colorScheme.onSurfaceVariant,
    };
    final icon = switch (transaction.type) {
      TransactionType.income => Icons.trending_up_rounded,
      TransactionType.expense => Icons.trending_down_rounded,
      TransactionType.reserveable => Icons.request_quote_rounded,
      TransactionType.debt => Icons.account_balance_rounded,
      TransactionType.transfer => Icons.swap_horiz_rounded,
      TransactionType.unknown => Icons.help_outline_rounded,
    };
    final dateText = transaction.hasDate
        ? FinanceFormatters.date(transaction.date)
        : strings.noDateInSheet;
    final convertedAmount = FinanceFormatters.convertedAmount(
      transaction,
      exchangeRate,
    );

    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: color.withValues(alpha: .12),
                  foregroundColor: color,
                  child: Icon(icon, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description.isEmpty
                            ? transaction.category
                            : transaction.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${transaction.category} · $dateText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      FinanceFormatters.amount(transaction),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (convertedAmount.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        '≈ $convertedAmount',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                if (trailingAction != null) ...[
                  const SizedBox(width: 4),
                  trailingAction!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
