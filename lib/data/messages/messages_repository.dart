import 'dart:async';

import '../../core/tdlib/td_api.dart';
import '../../core/tdlib/td_dispatcher.dart';
import '../../core/tdlib/td_error.dart';
import '../chats/chat_summary.dart';
import 'chat_message.dart';

class MessagesRepository {
  MessagesRepository(this._td, this.chatId) {
    _sub = _td.updates.listen(_onUpdate);
  }

  final TdApi _td;
  final int chatId;
  final _byId = <int, ChatMessage>{};
  final _replies = <int, ChatMessage>{};
  final _requestedReplies = <int>{};
  int _lastReadOutbox = 0;
  final _out = StreamController<List<ChatMessage>>.broadcast();
  late final StreamSubscription<TdObject> _sub;
  List<ChatMessage> _current = const [];
  bool _loading = false;
  bool _reachedStart = false;

  /// Newest first.
  List<ChatMessage> get current => _current;
  Stream<List<ChatMessage>> get messages => _out.stream;
  bool get reachedStart => _reachedStart;

  bool isRead(ChatMessage m) =>
      m.isOutgoing && m.sendState == SendState.sent && m.id <= _lastReadOutbox;

  /// Message a reply points to, loaded lazily when it is outside the history.
  ChatMessage? repliedTo(ChatMessage m) {
    final id = m.replyToId;
    if (id == null) return null;
    final found = _byId[id] ?? _replies[id];
    if (found == null && _requestedReplies.add(id)) unawaited(_fetchReply(id));
    return found;
  }

  Future<void> _fetchReply(int id) async {
    try {
      final res = await _td.send({
        '@type': 'getMessage',
        'chat_id': chatId,
        'message_id': id,
      });
      _replies[id] = ChatMessage.fromJson(res);
      _emit();
    } on TdError {
      // deleted or inaccessible, nothing to show
    }
  }

  Future<void> open() async {
    await _td.send({'@type': 'openChat', 'chat_id': chatId});
    try {
      final chat = await _td.send({'@type': 'getChat', 'chat_id': chatId});
      _lastReadOutbox = chat['last_read_outbox_message_id'] as int? ?? 0;
    } on TdError {
      // ticks just stay single
    }
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

  static TdObject _textContent(String text) => {
    '@type': 'inputMessageText',
    'text': {'@type': 'formattedText', 'text': text},
  };

  Future<void> sendText(String text, {int? replyTo}) async {
    final res = await _td.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'reply_to': ?(replyTo == null
          ? null
          : {'@type': 'inputMessageReplyToMessage', 'message_id': replyTo}),
      'input_message_content': _textContent(text),
    });
    _put(ChatMessage.fromJson(res));
  }

  Future<void> editText(int messageId, String text) async {
    final res = await _td.send({
      '@type': 'editMessageText',
      'chat_id': chatId,
      'message_id': messageId,
      'input_message_content': _textContent(text),
    });
    _put(ChatMessage.fromJson(res));
  }

  Future<void> delete(List<int> ids, {required bool revoke}) => _td.send({
    '@type': 'deleteMessages',
    'chat_id': chatId,
    'message_ids': ids,
    'revoke': revoke,
  });

  Future<MessageActions> actions(int messageId) async {
    try {
      return MessageActions.fromJson(
        await _td.send({
          '@type': 'getMessageProperties',
          'chat_id': chatId,
          'message_id': messageId,
        }),
      );
    } on TdError {
      return const MessageActions(canCopy: true);
    }
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
      case 'updateChatReadOutbox':
        _lastReadOutbox = u['last_read_outbox_message_id'] as int? ?? 0;
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
