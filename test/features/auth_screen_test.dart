import 'package:app/app/app.dart';
import 'package:app/app/providers.dart';
import 'package:app/core/l10n/l10n.dart';
import 'package:app/features/auth/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../fakes/fake_td.dart';

Widget _app(FakeTd td) => ProviderScope(
  overrides: [
    tdApiProvider.overrideWithValue(td),
    envConfiguredProvider.overrideWithValue(true),
  ],
  child: const MaterialApp(
    locale: Locale('uk'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: appLocalizationDelegates,
    home: AuthScreen(),
  ),
);

Map<String, dynamic> _codeState({int timeout = 2}) => {
  '@type': 'authorizationStateWaitCode',
  'code_info': {
    'phone_number': '380671234512',
    'type': {'@type': 'authenticationCodeTypeTelegramMessage', 'length': 5},
    'next_type': {'@type': 'authenticationCodeTypeSms', 'length': 5},
    'timeout': timeout,
  },
};

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('uk'));
  });

  testWidgets('code step explains delivery and unlocks resend', (t) async {
    final td = FakeTd()..handler = (_) => _codeState();
    await t.pumpWidget(_app(td));
    await t.pump();

    expect(find.text(l10n.codeViaTelegram), findsOneWidget);
    expect(find.text(l10n.resendIn(2)), findsOneWidget);

    await t.pump(const Duration(seconds: 2));
    await t.tap(find.text(l10n.resendSms));
    await t.pump();
    expect(td.sent.last['@type'], 'resendAuthenticationCode');

    await t.enterText(find.byType(TextField), '12345');
    await t.pump();
    expect(td.sent.last, {'@type': 'checkAuthenticationCode', 'code': '12345'});
  });

  testWidgets('change number goes back to phone form', (t) async {
    final td = FakeTd()..handler = (_) => _codeState(timeout: 0);
    await t.pumpWidget(_app(td));
    await t.pump();

    await t.tap(find.text(l10n.authChangePhone));
    await t.pump();
    expect(find.text(l10n.authPhoneLabel), findsOneWidget);
    expect(find.text(l10n.authQrButton), findsOneWidget);
  });

  testWidgets('qr state renders the login link', (t) async {
    final td = FakeTd()
      ..handler = (_) => {
        '@type': 'authorizationStateWaitOtherDeviceConfirmation',
        'link': 'tg://login?token=abc',
      };
    await t.pumpWidget(_app(td));
    await t.pump();

    final qr = t.widget<QrImageView>(find.byType(QrImageView));
    expect(qr, isNotNull);
    expect(find.text(l10n.authUsePhone), findsOneWidget);
  });
}
