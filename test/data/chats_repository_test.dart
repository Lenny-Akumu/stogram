import 'package:app/core/tdlib/td_error.dart';
import 'package:app/data/chats/chat_summary.dart';
import 'package:app/data/chats/chats_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_td.dart';

Map<String, dynamic> _pos(int order, {bool pinned = false}) => {
  'list': {'@type': 'chatListMain'},
  'order': '$order',
  'is_pinned': pinned,
};

Map<String, dynamic> _newChat(int id, String title, int order) => {
  '@type': 'updateNewChat',
  'chat': {
    'id': id,
    'title': title,
    'unread_count': 0,
    'positions': [_pos(order)],
  },
};

void main() {
  late FakeTd td;
  late ChatsRepository repo;

  setUp(() {
    td = FakeTd();
    repo = ChatsRepository(td);
  });
  tearDown(() => repo.dispose());

  Future<List<ChatSummary>> settle() async {
    await pumpEventQueue();
    return repo.current;
  }

  test('sorts by order and drops chats without position', () async {
    td
      ..push(_newChat(1, 'a', 10))
      ..push(_newChat(2, 'b', 30))
      ..push(_newChat(3, 'c', 0));
    final chats = await settle();
    expect(chats.map((c) => c.id), [2, 1]);
  });

  test('position and unread updates are applied', () async {
    td
      ..push(_newChat(1, 'a', 10))
      ..push(_newChat(2, 'b', 20))
      ..push({
        '@type': 'updateChatPosition',
        'chat_id': 1,
        'position': _pos(50, pinned: true),
      })
      ..push({'@type': 'updateChatReadInbox', 'chat_id': 2, 'unread_count': 4});
    final chats = await settle();
    expect(chats.first.id, 1);
    expect(chats.first.isPinned, isTrue);
    expect(chats.last.unreadCount, 4);
  });

  test('last message becomes preview', () async {
    td
      ..push(_newChat(1, 'a', 10))
      ..push({
        '@type': 'updateChatLastMessage',
        'chat_id': 1,
        'last_message': {
          'date': 1700000000,
          'content': {
            '@type': 'messagePhoto',
            'caption': {'text': 'sea'},
          },
        },
        'positions': [_pos(99)],
      });
    final chat = (await settle()).single;
    expect(chat.preview?.kind, PreviewKind.photo);
    expect(chat.preview?.text, 'sea');
    expect(chat.order, 99);
  });

  test('closed auth state clears chats', () async {
    td.push(_newChat(1, 'a', 10));
    await settle();
    td.push({
      '@type': 'updateAuthorizationState',
      'authorization_state': {'@type': 'authorizationStateClosed'},
    });
    expect(await settle(), isEmpty);
  });

  test('404 from loadChats marks list as fully loaded', () async {
    td.handler = (_) => throw const TdError(404, 'Not Found');
    await repo.loadMore();
    expect(repo.allLoaded, isTrue);
    await repo.loadMore();
    expect(td.sent, hasLength(1));
  });
}
