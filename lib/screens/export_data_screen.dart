import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/dashboard_controller.dart';
import '../services/data_export_service.dart';
import '../widgets/responsive_layout.dart';

class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  final _service = DataExportService();
  DataExportFormat _format = DataExportFormat.pdf;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Export data')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: AppResponsive.pagePadding(context),
              children: [
                const SizedBox(height: 24),
                Icon(
                  Icons.ios_share_rounded,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Export Data',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate a report of your financial activity.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 34),
                Text(
                  '${widget.controller.transactions.length} transactions ready',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 14),
                ...DataExportFormat.values.map(
                  (format) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FormatTile(
                      format: format,
                      selected: _format == format,
                      onSelected: () => setState(() => _format = format),
                      onPreview: () => _preview(format),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                      _exporting || widget.controller.transactions.isEmpty
                      ? null
                      : _export,
                  icon: _exporting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download_outlined),
                  label: Text(
                    _exporting ? 'Preparing report...' : 'Export now',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await _service.build(
        _format,
        widget.controller.transactions,
      );
      await Share.shareXFiles([
        XFile.fromData(file.bytes, name: file.name, mimeType: file.mimeType),
      ], subject: 'Maliyati financial report');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _preview(DataExportFormat format) {
    final rows = _service.rows(widget.controller.transactions).take(8).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_formatTitle(format)} preview',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Text('No transactions to preview.')
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(row[2]),
                        subtitle: Text('${row[0]}  •  ${row[3]}  •  ${row[6]}'),
                        trailing: Text(_rowAmount(row)),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _rowAmount(List<String> row) {
  final usd = double.tryParse(row[4]) ?? 0;
  return usd > 0 ? '\$${usd.toStringAsFixed(2)}' : 'LBP ${row[5]}';
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.format,
    required this.selected,
    required this.onSelected,
    required this.onPreview,
  });

  final DataExportFormat format;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (format) {
      DataExportFormat.pdf => const Color(0xFFE53935),
      DataExportFormat.csv => const Color(0xFF65A30D),
      DataExportFormat.excel => const Color(0xFF168A5B),
    };
    return Material(
      color: selected
          ? color.withValues(alpha: 0.08)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? color : theme.colorScheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_formatIcon(format), color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatTitle(format),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatSubtitle(format),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onPreview,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('View'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTitle(DataExportFormat format) => switch (format) {
  DataExportFormat.pdf => 'PDF document (.pdf)',
  DataExportFormat.csv => 'CSV document (.csv)',
  DataExportFormat.excel => 'Excel spreadsheet (.xlsx)',
};

String _formatSubtitle(DataExportFormat format) => switch (format) {
  DataExportFormat.pdf => 'A clean report ready to share or print',
  DataExportFormat.csv => 'Best for analysis and external tools',
  DataExportFormat.excel => 'Open in Excel or import into Google Sheets',
};

IconData _formatIcon(DataExportFormat format) => switch (format) {
  DataExportFormat.pdf => Icons.picture_as_pdf_rounded,
  DataExportFormat.csv => Icons.description_rounded,
  DataExportFormat.excel => Icons.table_chart_rounded,
};
