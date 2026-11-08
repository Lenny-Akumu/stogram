import 'package:app/data/auth/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses code state with phone', () {
    final s = AuthState.fromJson({
      '@type': 'authorizationStateWaitCode',
      'code_info': {'phone_number': '380671234512'},
    });
    expect(
      s,
      isA<AuthWaitCode>().having((s) => s.phone, 'phone', '380671234512'),
    );
  });

  test('parses password hint', () {
    final s = AuthState.fromJson({
      '@type': 'authorizationStateWaitPassword',
      'password_hint': 'cat',
    });
    expect(s, isA<AuthWaitPassword>().having((s) => s.hint, 'hint', 'cat'));
  });

  test('unknown state is unsupported', () {
    final s = AuthState.fromJson({
      '@type': 'authorizationStateWaitEmailAddress',
    });
    expect(s, isA<AuthUnsupported>());
  });
}
