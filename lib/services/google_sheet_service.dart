import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'csv_parser.dart';
import '../models/transaction.dart';

class GoogleSheetService {
  GoogleSheetService({http.Client? client, CsvParser? parser})
    : _client = client ?? http.Client(),
      _parser = parser ?? CsvParser();

  final http.Client _client;
  final CsvParser _parser;

  Future<List<FinancialTransaction>> fetchTransactions(String sheetUrl) async {
    final csvUrls = csvExportUrls(sheetUrl);
    http.Response? lastResponse;

    for (final csvUrl in csvUrls) {
      final response = await _client.get(_requestUri(csvUrl));
      lastResponse = response;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _parser.parse(response.body);
      }
    }

    throw GoogleSheetException(
      'Google Sheet returned HTTP ${lastResponse?.statusCode ?? 'unknown'}. Make sure the sheet is shared publicly or published to the web.',
    );
  }

  Uri _requestUri(String csvUrl) {
    if (!kIsWeb) {
      return Uri.parse(csvUrl);
    }
    return Uri.base
        .resolve('/api/sheet')
        .replace(queryParameters: {'url': csvUrl});
  }

  String toCsvExportUrl(String input) {
    return csvExportUrls(input).first;
  }

  List<String> csvExportUrls(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);

    if (uri == null || !uri.host.contains('docs.google.com')) {
      return [trimmed];
    }

    final idMatch = RegExp(r'/spreadsheets/d/([^/]+)').firstMatch(trimmed);
    final spreadsheetId = idMatch?.group(1);
    if (spreadsheetId == null || spreadsheetId.isEmpty) {
      return [
        uri
            .replace(
              queryParameters: {
                ...uri.queryParameters,
                if (trimmed.contains('/pub')) 'output': 'csv',
                if (trimmed.contains('/gviz/tq')) 'tqx': 'out:csv',
              },
            )
            .toString(),
      ];
    }

    final gid = uri.queryParameters['gid'] ?? '0';
    final encodedGid = Uri.encodeQueryComponent(gid);

    final urls = [
      'https://docs.google.com/spreadsheets/d/$spreadsheetId/gviz/tq?tqx=out:csv&gid=$encodedGid',
      'https://docs.google.com/spreadsheets/d/$spreadsheetId/export?format=csv&gid=$encodedGid',
      'https://docs.google.com/spreadsheets/d/e/$spreadsheetId/pub?output=csv&gid=$encodedGid',
    ];

    if (trimmed.contains('/export') ||
        trimmed.contains('/gviz/tq') ||
        trimmed.contains('/pub')) {
      return [trimmed, ...urls.where((url) => url != trimmed)];
    }

    return urls;
  }
}

class GoogleSheetException implements Exception {
  const GoogleSheetException(this.message);

  final String message;

  @override
  String toString() => message;
}
