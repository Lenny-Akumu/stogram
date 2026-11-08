import 'package:app/app/app.dart';
import 'package:app/app/providers.dart';
import 'package:app/core/l10n/l10n.dart';
import 'package:app/features/chat/chat_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_td.dart';

Map<String, dynamic> _msg(int id, String text, {bool out = false}) => {
  'id': id,
  'chat_id': 7,
  'is_outgoing': out,
  'date': 1700000000,
  'edit_date': 0,
  'content': {
    '@type': 'messageText',
    'text': {'text': text},
  },
};

Widget _app(FakeTd td) => ProviderScope(
  overrides: [tdApiProvider.overrideWithValue(td)],
  child: const MaterialApp(
    locale: Locale('uk'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: appLocalizationDelegates,
    home: ChatScreen(chatId: 7),
  ),
);

void main() {
  testWidgets('enter sends on desktop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final td = FakeTd()
      ..handler = (r) => switch (r['@type']) {
        'getChatHistory' => {'messages': <Object>[]},
        'sendMessage' => _msg(3, 'enter', out: true),
        _ => {'@type': 'ok'},
      };
    await tester.pumpWidget(_app(td));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'enter');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(td.sent.map((r) => r['@type']), contains('sendMessage'));
    expect(find.text('enter'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('shows history and sends text', (tester) async {
    final td = FakeTd()
      ..handler = (r) => switch (r['@type']) {
        'getChatHistory' when r['from_message_id'] == 0 => {
          'messages': [_msg(2, 'привіт'), _msg(1, 'ку', out: true)],
        },
        'getChatHistory' => {'messages': <Object>[]},
        'sendMessage' => _msg(3, 'як ти', out: true),
        _ => {'@type': 'ok'},
      };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tdApiProvider.overrideWithValue(td)],
        child: const MaterialApp(
          locale: Locale('uk'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          home: ChatScreen(chatId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('привіт'), findsOneWidget);
    expect(find.text('ку'), findsOneWidget);
    expect(td.sent.map((r) => r['@type']), contains('viewMessages'));

    await tester.enterText(find.byType(TextField), 'як ти');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(find.text('як ти'), findsOneWidget);
  });

  testWidgets('long press reply sends with reply_to', (tester) async {
    final td = FakeTd()
      ..handler = (r) => switch (r['@type']) {
        'getChatHistory' when r['from_message_id'] == 0 => {
          'messages': [_msg(2, 'привіт')],
        },
        'getChatHistory' => {'messages': <Object>[]},
        'getMessageProperties' => {
          'can_be_replied': true,
          'can_be_copied': true,
        },
        'sendMessage' => _msg(3, 'ага', out: true),
        _ => {'@type': 'ok'},
      };
    await tester.pumpWidget(_app(td));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('uk'));

    await tester.longPress(find.text('привіт'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.actionEdit), findsNothing);
    await tester.tap(find.text(l10n.actionReply));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ага');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    final req = td.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect((req['reply_to'] as Map)['message_id'], 2);
  });

  testWidgets('edit prefills the composer and saves', (tester) async {
    final td = FakeTd()
      ..handler = (r) => switch (r['@type']) {
        'getChatHistory' when r['from_message_id'] == 0 => {
          'messages': [_msg(2, 'опечтака', out: true)],
        },
        'getChatHistory' => {'messages': <Object>[]},
        'getMessageProperties' => {'can_be_edited': true},
        'editMessageText' => _msg(2, 'опечатка', out: true),
        _ => {'@type': 'ok'},
      };
    await tester.pumpWidget(_app(td));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('uk'));

    await tester.longPress(find.text('опечтака'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.actionEdit));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'опечтака',
    );

    await tester.enterText(find.byType(TextField), 'опечатка');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(td.sent.last['@type'], 'editMessageText');
    expect(find.text('опечатка'), findsOneWidget);
  });

  testWidgets('photo message downloads its file and shows caption', (
    tester,
  ) async {
    final td = FakeTd()
      ..handler = (r) => switch (r['@type']) {
        'getChatHistory' when r['from_message_id'] == 0 => {
          'messages': [
            {
              ..._msg(2, ''),
              'content': {
                '@type': 'messagePhoto',
                'caption': {'text': 'море'},
                'photo': {
                  'sizes': [
                    {
                      'type': 'x',
                      'width': 800,
                      'height': 600,
                      'photo': {
                        'id': 77,
                        'size': 10,
                        'local': {'path': ''},
                      },
                    },
                  ],
                },
              },
            },
          ],
        },
        'getChatHistory' => {'messages': <Object>[]},
        'downloadFile' => {
          'id': 77,
          'size': 10,
          'local': {'path': ''},
        },
        _ => {'@type': 'ok'},
      };
    await tester.pumpWidget(_app(td));
    await tester.pumpAndSettle();

    expect(find.text('море'), findsOneWidget);
    expect(
      td.sent.where((r) => r['@type'] == 'downloadFile').single['file_id'],
      77,
    );
  });
}
