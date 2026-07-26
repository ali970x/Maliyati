import 'dart:convert';
import 'dart:io';

import 'package:finance_tracker/services/gemini_transaction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all AI training examples produce executable Maliyati actions', () {
    final parser = GeminiTransactionParser();
    final lines = File(
      'docs/ai/maliyati_training_examples.jsonl',
    ).readAsLinesSync().where((line) => line.trim().isNotEmpty).toList();

    expect(lines, isNotEmpty);

    for (var index = 0; index < lines.length; index++) {
      final record = jsonDecode(lines[index]) as Map<String, dynamic>;
      final messages = (record['messages'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final finalAnswer = messages.last;

      expect(
        finalAnswer['role'],
        'assistant',
        reason: 'Training record ${index + 1} must end with an AI response.',
      );

      final actions = parser.parseActions(finalAnswer['content'] as String);
      expect(
        actions,
        isNotEmpty,
        reason:
            'Training record ${index + 1} must produce at least one action.',
      );
    }
  });
}
