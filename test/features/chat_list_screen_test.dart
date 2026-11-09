import 'package:app/app/app.dart';
import 'package:app/app/providers.dart';
import 'package:app/core/l10n/l10n.dart';
import 'package:app/data/chats/chats_repository.dart';
import 'package:app/features/chat_list/chat_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_td.dart';

void _noop(int _) {}

void main() {
  testWidgets('renders chats with preview and unread badge', (tester) async {
    final td = FakeTd();
    final repo = ChatsRepository(td);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tdApiProvider.overrideWithValue(td),
          chatsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          locale: Locale('uk'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          home: ChatListPane(onOpen: _noop),
        ),
      ),
    );

    td.push({
      '@type': 'updateNewChat',
      'chat': {
        'id': 1,
        'title': 'Софія',
        'unread_count': 3,
        'positions': [
          {
            'list': {'@type': 'chatListMain'},
            'order': '5',
            'is_pinned': true,
          },
        ],
        'last_message': {
          'date': 1700000000,
          'content': {'@type': 'messageVoiceNote'},
        },
      },
    });
    await tester.pumpAndSettle();

    expect(find.text('Софія'), findsOneWidget);
    expect(find.text('Голосове'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin), findsNothing);
    expect(td.sent.single['@type'], 'loadChats');
  });
}
