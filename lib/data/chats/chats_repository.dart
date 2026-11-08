import 'dart:async';

import '../../core/tdlib/td_api.dart';
import '../../core/tdlib/td_dispatcher.dart';
import '../../core/tdlib/td_error.dart';
import 'chat_summary.dart';

class _Chat {
  _Chat(this.id, this.title);

  final int id;
  String title;
  int order = 0;
  bool isPinned = false;
  int unreadCount = 0;
  TdObject? lastMessage;
}

class ChatsRepository {
  ChatsRepository(this._td) {
    _sub = _td.updates.listen(_onUpdate);
  }

  static const _mainList = {'@type': 'chatListMain'};

  final TdApi _td;
  final _chats = <int, _Chat>{};
  final _out = StreamController<List<ChatSummary>>.broadcast();
  late final StreamSubscription<TdObject> _sub;
  List<ChatSummary> _current = const [];
  bool _emitScheduled = false;
  bool _loading = false;
  bool _allLoaded = false;

  List<ChatSummary> get current => _current;
  Stream<List<ChatSummary>> get chats => _out.stream;
  bool get allLoaded => _allLoaded;

  Future<void> loadMore({int limit = 50}) async {
    if (_loading || _allLoaded) return;
    _loading = true;
    try {
      await _td.send({
        '@type': 'loadChats',
        'chat_list': _mainList,
        'limit': limit,
      });
    } on TdError catch (e) {
      if (e.code == 404) {
        _allLoaded = true;
      } else {
        rethrow;
      }
    } finally {
      _loading = false;
    }
  }

  void _onUpdate(TdObject u) {
    final chatId = u['chat_id'] as int?;
    final chat = chatId == null ? null : _chats[chatId];
    switch (u['@type']) {
      case 'updateNewChat':
        final c = u['chat'] as TdObject;
        final id = c['id'] as int;
        final entry = _chats[id] = _Chat(id, c['title'] as String? ?? '')
          ..unreadCount = c['unread_count'] as int? ?? 0
          ..lastMessage = c['last_message'] as TdObject?;
        _applyPositions(entry, c['positions']);
      case 'updateChatTitle' when chat != null:
        chat.title = u['title'] as String? ?? '';
      case 'updateChatPosition' when chat != null:
        _applyPosition(chat, u['position'] as TdObject);
      case 'updateChatLastMessage' when chat != null:
        chat.lastMessage = u['last_message'] as TdObject?;
        _applyPositions(chat, u['positions']);
      case 'updateChatDraftMessage' when chat != null:
        _applyPositions(chat, u['positions']);
      case 'updateChatReadInbox' when chat != null:
        chat.unreadCount = u['unread_count'] as int? ?? 0;
      case 'updateAuthorizationState':
        final state = (u['authorization_state'] as TdObject)['@type'];
        if (state != 'authorizationStateClosed') return;
        _chats.clear();
        _allLoaded = false;
      default:
        return;
    }
    _scheduleEmit();
  }

  void _applyPositions(_Chat chat, Object? positions) {
    if (positions is! List) return;
    for (final p in positions) {
      _applyPosition(chat, p as TdObject);
    }
  }

  void _applyPosition(_Chat chat, TdObject position) {
    final list = position['list'] as TdObject?;
    if (list?['@type'] != 'chatListMain') return;
    chat.order = int.tryParse('${position['order']}') ?? 0;
    chat.isPinned = position['is_pinned'] as bool? ?? false;
  }

  void _scheduleEmit() {
    if (_emitScheduled) return;
    _emitScheduled = true;
    scheduleMicrotask(() {
      _emitScheduled = false;
      if (_out.isClosed) return;
      _current = _snapshot();
      _out.add(_current);
    });
  }

  List<ChatSummary> _snapshot() {
    final list = _chats.values.where((c) => c.order != 0).toList()
      ..sort((a, b) => b.order.compareTo(a.order));
    return [
      for (final c in list)
        ChatSummary(
          id: c.id,
          title: c.title,
          order: c.order,
          isPinned: c.isPinned,
          unreadCount: c.unreadCount,
          preview: switch (c.lastMessage?['content']) {
            final TdObject content => MessagePreview.fromContent(content),
            _ => null,
          },
          date: switch (c.lastMessage?['date']) {
            final int s => DateTime.fromMillisecondsSinceEpoch(s * 1000),
            _ => null,
          },
        ),
    ];
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await _out.close();
  }
}
