import 'package:app/core/ayu/ayu_archive.dart';
import 'package:app/core/ayu/ayu_settings.dart';
import 'package:app/core/db/app_db.dart';
import 'package:app/data/messages/messages_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_td.dart';

Map<String, dynamic> _msg(int id, String text, {int chatId = 7}) => {
  '@type': 'message',
  'id': id,
  'chat_id': chatId,
  'is_outgoing': false,
  'date': 1700000000,
  'edit_date': 0,
  'content': {
    '@type': 'messageText',
    'text': {'text': text},
  },
};

void main() {
  late FakeTd td;
  late AppDb db;
  late AyuArchive archive;
  var settings = const AyuSettings();

  setUp(() {
    td = FakeTd();
    db = AppDb(NativeDatabase.memory());
    settings = const AyuSettings();
    archive = AyuArchive(td, db, () => settings);
  });
  tearDown(() async {
    await archive.dispose();
    await db.close();
  });

  test('deleted message survives and comes back on reopen', () async {
    td
      ..push({'@type': 'updateNewMessage', 'message': _msg(1, 'секрет')})
      ..push({'@type': 'updateNewMessage', 'message': _msg(2, 'ок')})
      ..push({
        '@type': 'updateDeleteMessages',
        'chat_id': 7,
        'message_ids': [1],
        'is_permanent': true,
        'from_cache': false,
      });
    await archive.idle;

    td.handler = (r) => r['@type'] == 'getChatHistory'
        ? {
            'messages': r['from_message_id'] == 0
                ? [_msg(2, 'ок')]
                : <Object>[],
          }
        : {'@type': 'ok'};
    final repo = MessagesRepository(
      td,
      7,
      archive: archive,
      settings: () => settings,
    );
    addTearDown(repo.dispose);
    await repo.open();

    expect(repo.current.map((m) => m.id), [2, 1]);
    final deleted = repo.current.last;
    expect(deleted.isDeleted, isTrue);
    expect(deleted.content.text, 'секрет');
  });

  test('edits keep the previous text', () async {
    td
      ..push({'@type': 'updateNewMessage', 'message': _msg(5, 'перша')})
      ..push({
        '@type': 'updateMessageContent',
        'chat_id': 7,
        'message_id': 5,
        'new_content': {
          '@type': 'messageText',
          'text': {'text': 'друга'},
        },
      })
      ..push({
        '@type': 'updateMessageContent',
        'chat_id': 7,
        'message_id': 5,
        'new_content': {
          '@type': 'messageText',
          'text': {'text': 'третя'},
        },
      });
    await archive.idle;
    final edits = await archive.edits(7, 5);
    expect(edits.map((e) => e.text), ['перша', 'друга']);
  });

  test('nothing is stored when both features are off', () async {
    settings = const AyuSettings(saveDeleted: false, editHistory: false);
    td.push({'@type': 'updateNewMessage', 'message': _msg(9, 'x')});
    await archive.idle;
    expect(await db.select(db.archivedMessages).get(), isEmpty);
  });
}
