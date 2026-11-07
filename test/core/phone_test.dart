import 'package:app/core/util/phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps prefix and last two digits', () {
    expect(maskPhone('+380 67 123 45 12'), '+380 ••••••• 12');
  });

  test('short input is fully masked', () {
    expect(maskPhone('1234'), '••••');
  });
}
