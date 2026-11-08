import 'dart:async';

import '../../core/tdlib/td_api.dart';
import '../../core/tdlib/td_dispatcher.dart';
import '../chats/chat_summary.dart';
import 'chat_message.dart';

class MessagesRepository {
  MessagesRepository(this._td, this.chatId) {
    _sub = _td.updates.listen(_onUpdate);
  }

  final TdApi _td;
  final int chatId;
  final _byId = <int, ChatMessage>{};
  final _out = StreamController<List<ChatMessage>>.broadcast();
  late final StreamSubscription<TdObject> _sub;
  List<ChatMessage> _current = const [];
  bool _loading = false;
  bool _reachedStart = false;

  /// Newest first.
  List<ChatMessage> get current => _current;
  Stream<List<ChatMessage>> get messages => _out.stream;
  bool get reachedStart => _reachedStart;

  Future<void> open() async {
    await _td.send({'@type': 'openChat', 'chat_id': chatId});
    await loadOlder();
  }

  Future<void> close() => _td.send({'@type': 'closeChat', 'chat_id': chatId});

  Future<void> loadOlder({int limit = 50}) async {
    if (_loading || _reachedStart) return;
    _loading = true;
    try {
      // first page from TDLib is often a single cached message, so keep asking
      var fetched = 0;
      while (fetched < limit) {
        final from = _current.isEmpty ? 0 : _current.last.id;
        final res = await _td.send({
          '@type': 'getChatHistory',
          'chat_id': chatId,
          'from_message_id': from,
          'offset': 0,
          'limit': limit - fetched,
          'only_local': false,
        });
        final list = (res['messages'] as List?) ?? const [];
        if (list.isEmpty) {
          _reachedStart = true;
          break;
        }
        for (final m in list) {
          final msg = ChatMessage.fromJson(m as TdObject);
          _byId[msg.id] = msg;
        }
        fetched += list.length;
        _emit();
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> sendText(String text) async {
    final res = await _td.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text},
      },
    });
    _put(ChatMessage.fromJson(res));
  }

  Future<void> markRead() async {
    final incoming = _current.where((m) => !m.isOutgoing).take(100);
    if (incoming.isEmpty) return;
    await _td.send({
      '@type': 'viewMessages',
      'chat_id': chatId,
      'message_ids': [for (final m in incoming) m.id],
      'force_read': true,
    });
  }

  void _onUpdate(TdObject u) {
    if (u['chat_id'] != chatId &&
        (u['message'] as TdObject?)?['chat_id'] != chatId) {
      return;
    }
    switch (u['@type']) {
      case 'updateNewMessage':
        _put(ChatMessage.fromJson(u['message'] as TdObject));
      case 'updateMessageSendSucceeded' || 'updateMessageSendFailed':
        _byId.remove(u['old_message_id']);
        _put(ChatMessage.fromJson(u['message'] as TdObject));
      case 'updateMessageContent':
        final id = u['message_id'] as int;
        final old = _byId[id];
        if (old == null) return;
        _byId[id] = old.copyWith(
          content: MessagePreview.fromContent(u['new_content'] as TdObject),
        );
        _emit();
      case 'updateMessageEdited':
        final id = u['message_id'] as int;
        final old = _byId[id];
        final edit = u['edit_date'] as int? ?? 0;
        if (old == null || edit == 0) return;
        _byId[id] = old.copyWith(
          editDate: DateTime.fromMillisecondsSinceEpoch(edit * 1000),
        );
        _emit();
      case 'updateDeleteMessages':
        if (u['is_permanent'] != true) return;
        for (final id in (u['message_ids'] as List? ?? const [])) {
          _byId.remove(id);
        }
        _emit();
    }
  }

  void _put(ChatMessage msg) {
    if (msg.chatId != chatId) return;
    _byId[msg.id] = msg;
    _emit();
  }

  void _emit() {
    if (_out.isClosed) return;
    _current = _byId.values.toList()..sort((a, b) => b.id.compareTo(a.id));
    _out.add(_current);
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await _out.close();
  }
}
