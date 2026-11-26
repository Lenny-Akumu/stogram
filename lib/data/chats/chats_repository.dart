import 'dart:async';

import '../../core/tdlib/td_api.dart';
import '../../core/tdlib/td_dispatcher.dart';
import '../../core/tdlib/td_error.dart';
import '../messages/message_media.dart';
import 'chat_summary.dart';

class _Chat {
  _Chat(this.id, this.title);

  final int id;
  String title;
  final positions = <String, (int, bool)>{};
  int unreadCount = 0;
  int unreadMentions = 0;
  bool isMuted = false;
  bool markedUnread = false;
  int lastReadInbox = 0;

  int get order => positions['main']?.$1 ?? 0;
  bool get isPinned => positions['main']?.$2 ?? false;
  bool isGroup = false;
  MediaImage? photo;
  ChatPeer peer = const ChatPeer();
  TdObject? lastMessage;
}

class FoundMessage {
  const FoundMessage(this.chatId, this.messageId, this.text);
  final int chatId;
  final int messageId;
  final String text;
}

class ChatFolder {
  const ChatFolder(this.id, this.name);
  final int id;
  final String name;

  String get key => 'f$id';
}

String chatListKey(TdObject? list) => switch (list?['@type']) {
  'chatListArchive' => 'archive',
  'chatListFolder' => 'f${list!['chat_folder_id']}',
  _ => 'main',
};

TdObject chatListOf(String key) => switch (key) {
  'archive' => {'@type': 'chatListArchive'},
  'main' => {'@type': 'chatListMain'},
  _ => {
    '@type': 'chatListFolder',
    'chat_folder_id': int.parse(key.substring(1)),
  },
};

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
  final _loading = <String>{};
  final _allLoaded = <String>{};
  List<ChatFolder> folders = const [];

  List<ChatSummary> get current => _current;
  Stream<List<ChatSummary>> get chats => _out.stream;
  bool get allLoaded => _allLoaded.contains('main');
  bool loadedAll(String key) => _allLoaded.contains(key);

  Future<void> loadMore({int limit = 50, String list = 'main'}) async {
    if (_loading.contains(list) || _allLoaded.contains(list)) return;
    _loading.add(list);
    try {
      await _td.send({
        '@type': 'loadChats',
        'chat_list': list == 'main' ? _mainList : chatListOf(list),
        'limit': limit,
      });
    } on TdError catch (e) {
      if (e.code == 404) {
        _allLoaded.add(list);
        _scheduleEmit();
      } else {
        rethrow;
      }
    } finally {
      _loading.remove(list);
    }
  }

  /// Chats of one list, sorted the way Telegram orders it.
  List<ChatSummary> listFor(String key) {
    final list =
        _chats.values.where((c) => (c.positions[key]?.$1 ?? 0) != 0).toList()
          ..sort(
            (a, b) => b.positions[key]!.$1.compareTo(a.positions[key]!.$1),
          );
    return [for (final c in list) _summary(c, key)];
  }

  int unreadIn(String key) => _chats.values
      .where((c) => (c.positions[key]?.$1 ?? 0) != 0 && !c.isMuted)
      .fold(0, (n, c) => n + (c.unreadCount > 0 || c.markedUnread ? 1 : 0));

  Future<void> togglePin(int chatId, String list) => _td.send({
    '@type': 'toggleChatIsPinned',
    'chat_list': chatListOf(list),
    'chat_id': chatId,
    'is_pinned': !(_chats[chatId]?.positions[list]?.$2 ?? false),
  });

  Future<void> setMuted(int chatId, bool muted) => _td.send({
    '@type': 'setChatNotificationSettings',
    'chat_id': chatId,
    'notification_settings': {
      '@type': 'chatNotificationSettings',
      'use_default_mute_for': false,
      'mute_for': muted ? 0x7fffffff : 0,
      'use_default_sound': true,
      'use_default_show_preview': true,
      'use_default_mute_stories': true,
      'use_default_story_sound': true,
      'use_default_show_story_poster': true,
      'use_default_disable_pinned_message_notifications': true,
      'use_default_disable_mention_notifications': true,
    },
  });

  Future<void> setArchived(int chatId, bool archived) => _td.send({
    '@type': 'addChatToList',
    'chat_id': chatId,
    'chat_list': archived ? {'@type': 'chatListArchive'} : _mainList,
  });

  Future<void> markRead(int chatId) async {
    final c = _chats[chatId];
    final last = c?.lastMessage?['id'];
    if (c != null && c.markedUnread) {
      await _td.send({
        '@type': 'toggleChatIsMarkedAsUnread',
        'chat_id': chatId,
        'is_marked_as_unread': false,
      });
    }
    if (last is int) {
      await _td.send({
        '@type': 'viewMessages',
        'chat_id': chatId,
        'message_ids': [last],
        'source': {'@type': 'messageSourceChatList'},
        'force_read': true,
      });
    }
  }

  Future<void> markUnread(int chatId) => _td.send({
    '@type': 'toggleChatIsMarkedAsUnread',
    'chat_id': chatId,
    'is_marked_as_unread': true,
  });

  Future<void> deleteChat(int chatId, {bool leave = false}) async {
    if (leave) {
      await _td.send({'@type': 'leaveChat', 'chat_id': chatId});
    }
    await _td.send({
      '@type': 'deleteChatHistory',
      'chat_id': chatId,
      'remove_from_chat_list': true,
      'revoke': false,
    });
  }

  Future<List<FoundMessage>> searchMessages(String query) async {
    try {
      final res = await _td.send({
        '@type': 'searchMessages',
        'chat_list': null,
        'query': query,
        'offset': '',
        'limit': 30,
        'filter': null,
        'chat_type_filter': null,
        'min_date': 0,
        'max_date': 0,
      });
      return [
        for (final m in (res['messages'] as List? ?? const []).cast<TdObject>())
          FoundMessage(
            m['chat_id'] as int,
            m['id'] as int,
            MessagePreview.fromContent(m['content'] as TdObject).text,
          ),
      ];
    } on TdError {
      return const [];
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
          ..unreadMentions = c['unread_mention_count'] as int? ?? 0
          ..markedUnread = c['is_marked_as_unread'] == true
          ..isMuted = _muted(c['notification_settings'] as TdObject?)
          ..isGroup = _isGroup(c['type'] as TdObject?)
          ..photo = chatPhoto(c['photo'] as TdObject?)
          ..peer = ChatPeer.fromType(c['type'] as TdObject?)
          ..lastMessage = c['last_message'] as TdObject?;
        _applyPositions(entry, c['positions']);
      case 'updateChatPhoto' when chat != null:
        chat.photo = chatPhoto(u['photo'] as TdObject?);
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
      case 'updateChatUnreadMentionCount' when chat != null:
        chat.unreadMentions = u['unread_mention_count'] as int? ?? 0;
      case 'updateChatIsMarkedAsUnread' when chat != null:
        chat.markedUnread = u['is_marked_as_unread'] == true;
      case 'updateChatNotificationSettings' when chat != null:
        chat.isMuted = _muted(u['notification_settings'] as TdObject?);
      case 'updateChatFolders':
        folders = [
          for (final f in (u['chat_folders'] as List? ?? const []))
            if (f is TdObject)
              ChatFolder(
                f['id'] as int,
                ((f['name'] as TdObject?)?['text'] as TdObject?)?['text']
                        as String? ??
                    '',
              ),
        ];
      case 'updateAuthorizationState':
        final state = (u['authorization_state'] as TdObject)['@type'];
        if (state != 'authorizationStateClosed') return;
        _chats.clear();
        _allLoaded.clear();
        folders = const [];
      default:
        return;
    }
    _scheduleEmit();
  }

  static bool _muted(TdObject? n) => (n?['mute_for'] as int? ?? 0) > 0;

  static bool _isGroup(TdObject? type) => switch (type?['@type']) {
    'chatTypeBasicGroup' => true,
    'chatTypeSupergroup' => type?['is_channel'] != true,
    _ => false,
  };

  ChatSummary? byId(int id) {
    for (final c in _current) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _applyPositions(_Chat chat, Object? positions) {
    if (positions is! List) return;
    for (final p in positions) {
      _applyPosition(chat, p as TdObject);
    }
  }

  void _applyPosition(_Chat chat, TdObject position) {
    final key = chatListKey(position['list'] as TdObject?);
    chat.positions[key] = (
      int.tryParse('${position['order']}') ?? 0,
      position['is_pinned'] as bool? ?? false,
    );
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
    final list =
        _chats.values
            .where((c) => c.positions.values.any((p) => p.$1 != 0))
            .toList()
          ..sort((a, b) => b.order.compareTo(a.order));
    return [for (final c in list) _summary(c, 'main')];
  }

  ChatSummary _summary(_Chat c, String key) => ChatSummary(
    id: c.id,
    title: c.title,
    order: c.positions[key]?.$1 ?? 0,
    isPinned: c.positions[key]?.$2 ?? false,
    unreadCount: c.unreadCount,
    isGroup: c.isGroup,
    photo: c.photo,
    peer: c.peer,
    isMuted: c.isMuted,
    isArchived: (c.positions['archive']?.$1 ?? 0) != 0,
    markedUnread: c.markedUnread,
    unreadMentions: c.unreadMentions,
    preview: switch (c.lastMessage?['content']) {
      final TdObject content => MessagePreview.fromContent(content),
      _ => null,
    },
    date: switch (c.lastMessage?['date']) {
      final int s => DateTime.fromMillisecondsSinceEpoch(s * 1000),
      _ => null,
    },
  );

  Future<void> dispose() async {
    await _sub.cancel();
    await _out.close();
  }
}
