import 'package:app/app/app.dart';
import 'package:app/app/providers.dart';
import 'package:app/core/l10n/l10n.dart';
import 'package:app/features/settings/appearance_screen.dart';
import 'package:app/features/settings/basic_settings.dart';
import 'package:app/features/settings/profile_screen.dart';
import 'package:app/ui/theme/skin_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_td.dart';

Widget _app(FakeTd td, Widget home) => ProviderScope(
  overrides: [tdApiProvider.overrideWithValue(td)],
  child: MaterialApp(
    locale: const Locale('uk'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: appLocalizationDelegates,
    home: home,
  ),
);

void main() {
  testWidgets('appearance lists designs and switches skin', (t) async {
    t.view.physicalSize = const Size(900, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(FakeTd(), const AppearanceScreen()));
    expect(find.byType(SkinCard), findsWidgets);
    await t.tap(find.text('Terminal'));
    await t.pump();
    final container = ProviderScope.containerOf(
      t.element(find.byType(AppearanceScreen)),
    );
    expect(container.read(skinProvider).id, 'terminal');
  });

  testWidgets('profile loads me and saves only changed fields', (t) async {
    final td = FakeTd()
      ..handler = (r) => switch (r['@type']) {
        'getMe' => {
          'id': 1,
          'first_name': 'Любомир',
          'last_name': '',
          'phone_number': '380671234512',
          'usernames': {
            'active_usernames': ['lenny'],
          },
        },
        'getUserFullInfo' => {
          'bio': {'text': 'код'},
        },
        _ => {'@type': 'ok'},
      };
    await t.pumpWidget(_app(td, const ProfileScreen()));
    await t.pumpAndSettle();

    expect(find.text('Любомир'), findsOneWidget);
    expect(find.text('код'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'код'), 'флаттер');
    await t.tap(find.byIcon(Icons.check));
    await t.pumpAndSettle();

    final types = td.sent.map((r) => r['@type']).toList();
    expect(types, contains('setBio'));
    expect(types, isNot(contains('setName')));
    expect(types, isNot(contains('setUsername')));
    expect(td.sent.firstWhere((r) => r['@type'] == 'setBio')['bio'], 'флаттер');
  });

  testWidgets('privacy loads rules and saves a choice', (t) async {
    final td = FakeTd()
      ..handler = (r) => switch (r['@type']) {
        'getUserPrivacySettingRules' => {
          'rules': [
            {'@type': 'userPrivacySettingRuleAllowContacts'},
          ],
        },
        _ => {'@type': 'ok'},
      };
    await t.pumpWidget(_app(td, const PrivacyScreen()));
    await t.pumpAndSettle();
    expect(find.text('Мої контакти'), findsWidgets);
    await t.tap(find.text('Номер телефону'));
    await t.pumpAndSettle();
    await t.tap(find.text('Ніхто').last);
    await t.pumpAndSettle();
    final set = td.sent.lastWhere(
      (r) => r['@type'] == 'setUserPrivacySettingRules',
    );
    expect(((set['rules'] as Map)['rules'] as List).single, {
      '@type': 'userPrivacySettingRuleRestrictAll',
    });
  });

  testWidgets('sessions list and terminate others', (t) async {
    final td = FakeTd()
      ..handler = (r) => switch (r['@type']) {
        'getActiveSessions' => {
          'sessions': [
            {
              'id': 1,
              'is_current': true,
              'application_name': 'stogram',
              'application_version': '1',
              'device_model': 'PC',
              'platform': 'Linux',
              'system_version': '',
              'last_active_date': 0,
              'location': '',
            },
            {
              'id': 2,
              'is_current': false,
              'application_name': 'Other',
              'application_version': '2',
              'device_model': 'Phone',
              'platform': 'Android',
              'system_version': '14',
              'last_active_date': 0,
              'location': 'Kyiv',
            },
          ],
        },
        _ => {'@type': 'ok'},
      };
    await t.pumpWidget(_app(td, const SessionsScreen()));
    await t.pumpAndSettle();
    expect(find.text('Other 2'), findsOneWidget);
    await t.tap(find.text('Завершити всі інші сеанси'));
    await t.pumpAndSettle();
    await t.tap(find.text('Завершити'));
    await t.pumpAndSettle();
    expect(
      td.sent.map((r) => r['@type']),
      contains('terminateAllOtherSessions'),
    );
  });
}
