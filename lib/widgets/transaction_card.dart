import 'package:flutter/material.dart';

import '../models/transaction.dart';
import 'finance_formatters.dart';
import '../l10n/app_strings.dart';

class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    required this.exchangeRate,
    required this.strings,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  final FinancialTransaction transaction;
  final double exchangeRate;
  final AppStrings strings;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = transaction.isIncome;
    final color = isIncome ? const Color(0xFF168A5B) : const Color(0xFFC74949);
    final dateText = transaction.hasDate
        ? FinanceFormatters.date(transaction.date)
        : strings.noDateInSheet;
    final sheetAmount = _sheetAmountText(transaction);

    return Card(
      elevation: 0,
      margin: margin,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isIncome
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: color,
                ),
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_typeLabel(transaction.type)} - $dateText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (transaction.category.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.category_rounded, size: 14, color: color),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              transaction.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (transaction.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sticky_note_2_rounded,
                              size: 15,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                transaction.notes,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (transaction.paymentMethod.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        transaction.paymentMethod,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                constraints: const BoxConstraints(maxWidth: 84),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    sheetAmount,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(TransactionType type) {
    if (type == TransactionType.income) {
      return strings.income;
    }
    if (type == TransactionType.expense) {
      return strings.expense;
    }
    return strings.noData;
  }

  String _sheetAmountText(FinancialTransaction transaction) {
    final rawUsd = _rawValueStartingWith(transaction, 'amount_usd');
    final rawLbp = _rawValueStartingWith(transaction, 'amount_lbp');

    if (rawUsd.isNotEmpty || rawLbp.isNotEmpty) {
      if (transaction.currency == CurrencyCode.usd && rawUsd.isNotEmpty) {
        return rawUsd;
      }
      if (transaction.currency == CurrencyCode.lbp && rawLbp.isNotEmpty) {
        return rawLbp;
      }
    }

    return FinanceFormatters.amount(transaction);
  }

  String _rawValueStartingWith(
    FinancialTransaction transaction,
    String prefix,
  ) {
    for (final entry in transaction.raw.entries) {
      if (entry.key.startsWith(prefix) && entry.value.trim().isNotEmpty) {
        return entry.value.trim();
      }
    }
    return '';
  }
}
