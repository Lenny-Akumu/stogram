import 'package:app/data/chats/chat_summary.dart';
import 'package:app/data/messages/chat_message.dart';
import 'package:app/data/messages/messages_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_td.dart';

Map<String, dynamic> _msg(
  int id, {
  int chatId = 7,
  String text = 'hi',
  bool out = false,
  String? sending,
}) => {
  '@type': 'message',
  'id': id,
  'chat_id': chatId,
  'is_outgoing': out,
  'sender_id': {'@type': 'messageSenderUser', 'user_id': 42},
  'date': 1700000000,
  'edit_date': 0,
  'content': {
    '@type': 'messageText',
    'text': {'text': text},
  },
  'sending_state': ?(sending == null ? null : {'@type': sending}),
};

void main() {
  late FakeTd td;
  late MessagesRepository repo;

  setUp(() {
    td = FakeTd();
    repo = MessagesRepository(td, 7);
  });
  tearDown(() => repo.dispose());

  test('history is paged until TDLib returns empty', () async {
    var call = 0;
    td.handler = (r) {
      if (r['@type'] != 'getChatHistory') return {'@type': 'ok'};
      call++;
      return {
        '@type': 'messages',
        'messages': switch (call) {
          1 => [_msg(30)],
          2 => [_msg(20), _msg(10)],
          _ => <Object>[],
        },
      };
    };
    await repo.open();
    expect(repo.current.map((m) => m.id), [30, 20, 10]);
    expect(repo.reachedStart, isTrue);
    final froms = td.sent
        .where((r) => r['@type'] == 'getChatHistory')
        .map((r) => r['from_message_id']);
    expect(froms, [0, 30, 10]);
  });

  test('ignores other chats and applies edits', () async {
    td
      ..push({'@type': 'updateNewMessage', 'message': _msg(1)})
      ..push({'@type': 'updateNewMessage', 'message': _msg(2, chatId: 8)})
      ..push({
        '@type': 'updateMessageContent',
        'chat_id': 7,
        'message_id': 1,
        'new_content': {
          '@type': 'messageText',
          'text': {'text': 'fixed'},
        },
      })
      ..push({
        '@type': 'updateMessageEdited',
        'chat_id': 7,
        'message_id': 1,
        'edit_date': 1700000100,
      });
    final m = repo.current.single;
    expect(m.content.text, 'fixed');
    expect(m.isEdited, isTrue);
  });

  test('send succeeded replaces temporary message', () async {
    td.handler = (_) =>
        _msg(1000, out: true, sending: 'messageSendingStatePending');
    await repo.sendText('yo');
    expect(repo.current.single.sendState, SendState.pending);

    td.push({
      '@type': 'updateMessageSendSucceeded',
      'old_message_id': 1000,
      'message': _msg(55, out: true),
    });
    expect(repo.current.single.id, 55);
    expect(repo.current.single.sendState, SendState.sent);
    final req = td.sent.single;
    expect(req['@type'], 'sendMessage');
    expect((req['input_message_content'] as Map)['@type'], 'inputMessageText');
  });

  test('permanent delete removes, cache eviction does not', () async {
    td
      ..push({'@type': 'updateNewMessage', 'message': _msg(1)})
      ..push({'@type': 'updateNewMessage', 'message': _msg(2)})
      ..push({
        '@type': 'updateDeleteMessages',
        'chat_id': 7,
        'message_ids': [1],
        'is_permanent': false,
        'from_cache': true,
      });
    expect(repo.current, hasLength(2));
    td.push({
      '@type': 'updateDeleteMessages',
      'chat_id': 7,
      'message_ids': [1],
      'is_permanent': true,
      'from_cache': false,
    });
    expect(repo.current.single.id, 2);
  });

  test('markRead sends incoming ids only', () async {
    td
      ..push({'@type': 'updateNewMessage', 'message': _msg(1)})
      ..push({'@type': 'updateNewMessage', 'message': _msg(2, out: true)});
    await repo.markRead();
    expect(td.sent.single['message_ids'], [1]);
  });

  test('media content keeps its kind', () {
    final m = ChatMessage.fromJson({
      ..._msg(1),
      'content': {
        '@type': 'messageSticker',
        'sticker': {'emoji': '🙂'},
      },
    });
    expect(m.content.kind, PreviewKind.sticker);
    expect(m.content.text, '🙂');
  });

  test('reply, edit and delete send the right requests', () async {
    td.handler = (r) => switch (r['@type']) {
      'sendMessage' => _msg(5, out: true),
      'editMessageText' => _msg(5, text: 'new', out: true),
      _ => {'@type': 'ok'},
    };
    await repo.sendText('yo', replyTo: 3);
    expect(td.sent.last['reply_to'], {
      '@type': 'inputMessageReplyToMessage',
      'message_id': 3,
    });

    await repo.editText(5, 'new');
    expect(td.sent.last['@type'], 'editMessageText');
    expect(repo.current.single.content.text, 'new');

    await repo.delete([5], revoke: true);
    expect(td.sent.last, {
      '@type': 'deleteMessages',
      'chat_id': 7,
      'message_ids': [5],
      'revoke': true,
    });
  });

  test('outgoing becomes read after updateChatReadOutbox', () async {
    td.push({'@type': 'updateNewMessage', 'message': _msg(4, out: true)});
    final m = repo.current.single;
    expect(repo.isRead(m), isFalse);
    td.push({
      '@type': 'updateChatReadOutbox',
      'chat_id': 7,
      'last_read_outbox_message_id': 4,
    });
    expect(repo.isRead(m), isTrue);
  });

  test('reply target outside history is fetched once', () async {
    td.handler = (r) => r['@type'] == 'getMessage'
        ? _msg(1, text: 'original')
        : {'@type': 'ok'};
    td.push({
      '@type': 'updateNewMessage',
      'message': {
        ..._msg(9),
        'reply_to': {
          '@type': 'messageReplyToMessage',
          'chat_id': 7,
          'message_id': 1,
        },
      },
    });
    final m = repo.current.single;
    expect(m.replyToId, 1);
    expect(repo.repliedTo(m), isNull);
    repo.repliedTo(m);
    await pumpEventQueue();
    expect(repo.repliedTo(m)?.content.text, 'original');
    expect(td.sent.where((r) => r['@type'] == 'getMessage'), hasLength(1));
  });
}
