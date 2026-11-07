String maskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 6) return '•' * digits.length;
  final head = digits.substring(0, 3);
  final tail = digits.substring(digits.length - 2);
  return '+$head ${'•' * (digits.length - 5)} $tail';
}
