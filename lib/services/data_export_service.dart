import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/transaction.dart';

enum DataExportFormat { pdf, csv, excel }

class DataExportFile {
  const DataExportFile({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String name;
  final String mimeType;
}

class DataExportService {
  Future<DataExportFile> build(
    DataExportFormat format,
    List<FinancialTransaction> transactions,
  ) async {
    return switch (format) {
      DataExportFormat.pdf => _pdf(transactions),
      DataExportFormat.csv => _csv(transactions),
      DataExportFormat.excel => _excel(transactions),
    };
  }

  List<String> get headers => const [
    'Date',
    'Type',
    'Title',
    'Category',
    'USD',
    'LBP',
    'Account',
    'Notes',
  ];

  List<List<String>> rows(List<FinancialTransaction> transactions) =>
      transactions
          .map((item) {
            return [
              DateFormat('yyyy-MM-dd').format(item.date),
              item.type.label,
              item.description,
              item.category,
              item.amountUsd.toStringAsFixed(2),
              item.amountLbp.toStringAsFixed(0),
              item.walletId,
              item.notes,
            ];
          })
          .toList(growable: false);

  DataExportFile _csv(List<FinancialTransaction> transactions) {
    final text = const ListToCsvConverter().convert([
      headers,
      ...rows(transactions),
    ]);
    return DataExportFile(
      bytes: Uint8List.fromList(utf8.encode('\uFEFF$text')),
      name: _name('csv'),
      mimeType: 'text/csv',
    );
  }

  DataExportFile _excel(List<FinancialTransaction> transactions) {
    final workbook = Excel.createExcel();
    final sheet = workbook['Transactions'];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final row in rows(transactions)) {
      sheet.appendRow(row.map(TextCellValue.new).toList());
    }
    final bytes = workbook.encode() ?? const <int>[];
    return DataExportFile(
      bytes: Uint8List.fromList(bytes),
      name: _name('xlsx'),
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<DataExportFile> _pdf(List<FinancialTransaction> transactions) async {
    final document = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/NotoSansArabic.ttf');
    final font = pw.Font.ttf(fontData);
    final data = rows(transactions);
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 14),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Maliyati financial report',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('${transactions.length} transactions'),
            ],
          ),
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1478C9),
            ),
            cellPadding: const pw.EdgeInsets.all(4),
          ),
        ],
      ),
    );
    return DataExportFile(
      bytes: await document.save(),
      name: _name('pdf'),
      mimeType: 'application/pdf',
    );
  }

  String _name(String extension) =>
      'maliyati_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.$extension';
}
