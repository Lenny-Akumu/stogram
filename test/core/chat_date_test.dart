import 'package:app/core/util/chat_date.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('uk'));

  final now = DateTime(2026, 11, 8, 15, 30);

  test('same day shows time', () {
    expect(formatChatDate(DateTime(2026, 11, 8, 9, 5), now, 'uk'), '09:05');
  });

  test('same year shows day and month', () {
    expect(formatChatDate(DateTime(2026, 3, 1), now, 'uk'), '01.03');
  });

  test('older shows full date', () {
    expect(formatChatDate(DateTime(2024, 3, 1), now, 'uk'), '01.03.24');
  });
}
