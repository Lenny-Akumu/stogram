import 'package:app/app/app.dart';
import 'package:app/app/providers.dart';
import 'package:app/core/l10n/l10n.dart';
import 'package:app/features/chat/chat_screen.dart';
import 'package:flutter/material.dart';
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

void main() {
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
}
