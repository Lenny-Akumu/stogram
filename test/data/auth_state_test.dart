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
      '@type': 'authorizationStateWaitPremiumPurchase',
    });
    expect(s, isA<AuthUnsupported>());
  });

  test('code info carries delivery, next type and timeout', () {
    final s =
        AuthState.fromJson({
              '@type': 'authorizationStateWaitCode',
              'code_info': {
                'phone_number': '380671234512',
                'type': {
                  '@type': 'authenticationCodeTypeTelegramMessage',
                  'length': 5,
                },
                'next_type': {
                  '@type': 'authenticationCodeTypeSms',
                  'length': 5,
                },
                'timeout': 60,
              },
            })
            as AuthWaitCode;
    expect(s.delivery.kind, CodeKind.telegram);
    expect(s.delivery.length, 5);
    expect(s.next?.kind, CodeKind.sms);
    expect(s.timeout, 60);
  });

  test('missed call keeps number prefix', () {
    final d = CodeDelivery.fromJson({
      '@type': 'authenticationCodeTypeMissedCall',
      'phone_number_prefix': '+380 44',
      'length': 4,
    })!;
    expect(d.kind, CodeKind.missedCall);
    expect(d.hint, '+380 44');
  });

  test('parses qr, email and registration states', () {
    expect(
      AuthState.fromJson({
        '@type': 'authorizationStateWaitOtherDeviceConfirmation',
        'link': 'tg://login?token=x',
      }),
      isA<AuthWaitQr>().having((s) => s.link, 'link', 'tg://login?token=x'),
    );
    expect(
      AuthState.fromJson({'@type': 'authorizationStateWaitEmailAddress'}),
      isA<AuthWaitEmail>(),
    );
    expect(
      AuthState.fromJson({
        '@type': 'authorizationStateWaitEmailCode',
        'code_info': {'email_address_pattern': 'a***@b.c', 'length': 6},
      }),
      isA<AuthWaitEmailCode>().having((s) => s.pattern, 'pattern', 'a***@b.c'),
    );
    expect(
      AuthState.fromJson({
        '@type': 'authorizationStateWaitRegistration',
        'terms_of_service': {
          'text': {'text': 'be nice'},
        },
      }),
      isA<AuthWaitRegistration>().having((s) => s.terms, 'terms', 'be nice'),
    );
  });
}
