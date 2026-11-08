import 'package:intl/intl.dart';

String formatChatDate(DateTime date, DateTime now, String locale) {
  final sameDay =
      date.year == now.year && date.month == now.month && date.day == now.day;
  if (sameDay) return DateFormat.Hm(locale).format(date);
  if (now.difference(date).inDays < 7 && date.isBefore(now)) {
    return DateFormat.E(locale).format(date);
  }
  if (date.year == now.year) return DateFormat('dd.MM', locale).format(date);
  return DateFormat('dd.MM.yy', locale).format(date);
}
