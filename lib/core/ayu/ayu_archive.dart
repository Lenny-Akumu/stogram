import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_db.dart';
import '../tdlib/td_api.dart';
import '../tdlib/td_dispatcher.dart';
import 'ayu_settings.dart';

class EditRecord {
  const EditRecord(this.text, this.at);
  final String text;
  final DateTime at;
}

/// Mirrors incoming messages into SQLite so deletions and edits leave a trace.
class AyuArchive {
  AyuArchive(this._td, this._db, this._settings) {
    _sub = _td.updates.listen((u) => _queue = _queue.then((_) => _onUpdate(u)));
  }

  final TdApi _td;
  final AppDb _db;
  final AyuSettings Function() _settings;
  late final StreamSubscription<TdObject> _sub;
  Future<void> _queue = Future.value();
  final _deleted = StreamController<(int, List<int>)>.broadcast();

  /// (chatId, messageIds) that were kept after a permanent delete.
  Stream<(int, List<int>)> get deletions => _deleted.stream;

  Future<void> store(TdObject message) async {
    if (!_settings().archives) return;
    final chatId = message['chat_id'] as int?;
    final id = message['id'] as int?;
    if (chatId == null || id == null) return;
    await _db
        .into(_db.archivedMessages)
        .insert(
          ArchivedMessagesCompanion.insert(
            chatId: chatId,
            messageId: id,
            json: jsonEncode(message),
            date: message['date'] as int? ?? 0,
          ),
          onConflict: DoUpdate(
            (_) => ArchivedMessagesCompanion(json: Value(jsonEncode(message))),
          ),
        );
  }

  Future<void> storeAll(Iterable<TdObject> messages) async {
    if (!_settings().archives) return;
    await _db.batch((b) {
      for (final m in messages) {
        final chatId = m['chat_id'] as int?;
        final id = m['id'] as int?;
        if (chatId == null || id == null) continue;
        b.insert(
          _db.archivedMessages,
          ArchivedMessagesCompanion.insert(
            chatId: chatId,
            messageId: id,
            json: jsonEncode(m),
            date: m['date'] as int? ?? 0,
          ),
          onConflict: DoUpdate(
            (_) => ArchivedMessagesCompanion(json: Value(jsonEncode(m))),
          ),
        );
      }
    });
  }

  /// Deleted messages of a chat with ids from [fromId] up, oldest first.
  Future<List<(TdObject, DateTime)>> deletedSince(
    int chatId,
    int fromId,
  ) async {
    final rows =
        await (_db.select(_db.archivedMessages)
              ..where(
                (t) =>
                    t.chatId.equals(chatId) &
                    t.messageId.isBiggerOrEqualValue(fromId) &
                    t.deletedAt.isNotNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.messageId)]))
            .get();
    return [
      for (final r in rows)
        (
          jsonDecode(r.json) as TdObject,
          DateTime.fromMillisecondsSinceEpoch(r.deletedAt! * 1000),
        ),
    ];
  }

  Future<List<EditRecord>> edits(int chatId, int messageId) async {
    final rows =
        await (_db.select(_db.messageEdits)
              ..where(
                (t) => t.chatId.equals(chatId) & t.messageId.equals(messageId),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.editedAt)]))
            .get();
    return [
      for (final r in rows)
        EditRecord(
          r.body,
          DateTime.fromMillisecondsSinceEpoch(r.editedAt * 1000),
        ),
    ];
  }

  Future<void> _onUpdate(TdObject u) async {
    switch (u['@type']) {
      case 'updateNewMessage':
        await store(u['message'] as TdObject);
      case 'updateMessageSendSucceeded':
        final m = u['message'] as TdObject;
        await (_db.delete(_db.archivedMessages)..where(
              (t) =>
                  t.chatId.equals(m['chat_id'] as int) &
                  t.messageId.equals(u['old_message_id'] as int),
            ))
            .go();
        await store(m);
      case 'updateMessageContent':
        await _onContent(
          u['chat_id'] as int,
          u['message_id'] as int,
          u['new_content'] as TdObject,
        );
      case 'updateDeleteMessages':
        if (u['is_permanent'] != true || u['from_cache'] == true) return;
        if (!_settings().saveDeleted) return;
        final chatId = u['chat_id'] as int;
        final ids = [for (final id in (u['message_ids'] as List)) id as int];
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await (_db.update(_db.archivedMessages)
              ..where((t) => t.chatId.equals(chatId) & t.messageId.isIn(ids)))
            .write(ArchivedMessagesCompanion(deletedAt: Value(now)));
        _deleted.add((chatId, ids));
    }
  }

  Future<void> _onContent(int chatId, int messageId, TdObject content) async {
    final row =
        await (_db.select(_db.archivedMessages)..where(
              (t) => t.chatId.equals(chatId) & t.messageId.equals(messageId),
            ))
            .getSingleOrNull();
    if (row == null) return;
    final old = jsonDecode(row.json) as TdObject;
    if (_settings().editHistory) {
      final text = _text(old['content'] as TdObject?);
      if (text.isNotEmpty) {
        final at = old['edit_date'] as int? ?? 0;
        await _db
            .into(_db.messageEdits)
            .insert(
              MessageEditsCompanion.insert(
                chatId: chatId,
                messageId: messageId,
                body: text,
                editedAt: at == 0 ? old['date'] as int? ?? 0 : at,
              ),
            );
      }
    }
    old['content'] = content;
    old['edit_date'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await (_db.update(_db.archivedMessages)..where(
          (t) => t.chatId.equals(chatId) & t.messageId.equals(messageId),
        ))
        .write(ArchivedMessagesCompanion(json: Value(jsonEncode(old))));
  }

  static String _text(TdObject? content) {
    final t = (content?['text'] ?? content?['caption']) as TdObject?;
    return t?['text'] as String? ?? '';
  }

  /// Resolves once every update received so far is written.
  Future<void> get idle => _queue;

  Future<void> dispose() async {
    await _sub.cancel();
    await _queue;
    await _deleted.close();
  }
}
