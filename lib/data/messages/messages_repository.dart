import 'dart:async';

import '../../core/ayu/ayu_archive.dart';
import '../../core/ayu/ayu_settings.dart';
import '../../core/tdlib/td_api.dart';
import '../../core/tdlib/td_dispatcher.dart';
import '../../core/tdlib/td_error.dart';
import '../chats/chat_summary.dart';
import '../stickers/stickers_repository.dart';
import 'chat_message.dart';
import 'message_media.dart';
import 'reply_markup.dart';

class MessagesRepository {
  MessagesRepository(
    this._td,
    this.chatId, {
    AyuArchive? archive,
    AyuSettings Function()? settings,
  }) : _archive = archive,
       _settings = settings ?? (() => const AyuSettings()) {
    _sub = _td.updates.listen(_onUpdate);
  }

  final TdApi _td;
  final int chatId;
  final AyuArchive? _archive;
  final AyuSettings Function() _settings;
  DateTime _lastTyping = DateTime.fromMillisecondsSinceEpoch(0);
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
      replyMarkupMessageId = chat['reply_markup_message_id'] as int? ?? 0;
      unawaited(_loadCommands(chat['type'] as TdObject?));
      unawaited(loadPinned());
    } on TdError {
      // ticks just stay single
    }
    await loadOlder();
    if (replyMarkupMessageId != 0 && !_byId.containsKey(replyMarkupMessageId)) {
      await _fetchReply(replyMarkupMessageId);
      final m = _replies[replyMarkupMessageId];
      if (m != null) _put(m);
    }
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
        final raw = [for (final m in list) m as TdObject];
        for (final m in raw) {
          final msg = ChatMessage.fromJson(m);
          _byId[msg.id] = msg;
        }
        unawaited(_archive?.storeAll(raw));
        fetched += list.length;
        _emit();
      }
      await _mergeDeleted();
    } finally {
      _loading = false;
    }
  }

  /// True after a jump into history until the newest messages are loaded again.
  bool detached = false;

  Future<List<TdObject>> _history(int from, int offset, int limit) async {
    final res = await _td.send({
      '@type': 'getChatHistory',
      'chat_id': chatId,
      'from_message_id': from,
      'offset': offset,
      'limit': limit,
      'only_local': false,
    });
    return [
      for (final m in (res['messages'] as List? ?? const [])) m as TdObject,
    ];
  }

  /// Loads history around [id] unless it is already in memory.
  Future<void> jumpTo(int id) async {
    if (_byId.containsKey(id)) return;
    final raw = await _history(id, -20, 40);
    if (raw.isEmpty) return;
    _byId.clear();
    _reachedStart = false;
    detached = true;
    for (final m in raw) {
      final msg = ChatMessage.fromJson(m);
      _byId[msg.id] = msg;
    }
    _emit();
  }

  Future<void> loadNewer() async {
    if (!detached || _loading || _current.isEmpty) return;
    _loading = true;
    try {
      final newest = _current.first.id;
      final raw = await _history(newest, -40, 41);
      var added = 0;
      for (final m in raw) {
        final msg = ChatMessage.fromJson(m);
        if (!_byId.containsKey(msg.id)) added++;
        _byId[msg.id] = msg;
      }
      if (added == 0) detached = false;
      _emit();
    } finally {
      _loading = false;
    }
  }

  Future<void> returnToLatest() async {
    if (!detached) return;
    _byId.clear();
    _reachedStart = false;
    detached = false;
    _emit();
    await loadOlder();
  }

  Future<List<ChatMessage>> search(String query) async {
    try {
      final res = await _td.send({
        '@type': 'searchChatMessages',
        'chat_id': chatId,
        'query': query,
        'from_message_id': 0,
        'offset': 0,
        'limit': 50,
      });
      return [
        for (final m in (res['messages'] as List? ?? const []))
          ChatMessage.fromJson(m as TdObject),
      ];
    } on TdError {
      return const [];
    }
  }

  Future<void> _mergeDeleted() async {
    final archive = _archive;
    if (archive == null || !_settings().saveDeleted) return;
    final from = _reachedStart || _byId.isEmpty
        ? 0
        : _byId.keys.reduce((a, b) => a < b ? a : b);
    var added = false;
    for (final (json, at) in await archive.deletedSince(chatId, from)) {
      final msg = ChatMessage.fromJson(json).copyWith(deletedAt: at);
      final existing = _byId[msg.id];
      if (existing != null && existing.isDeleted) continue;
      if (existing != null) continue;
      _byId[msg.id] = msg;
      added = true;
    }
    if (added) _emit();
  }

  Future<List<EditRecord>> edits(int messageId) async =>
      await _archive?.edits(chatId, messageId) ?? const [];

  /// Tells the other side we are typing, unless ghost mode hides it.
  Future<void> sendTyping() async {
    if (_settings().ghostMode) return;
    final now = DateTime.now();
    if (now.difference(_lastTyping) < const Duration(seconds: 4)) return;
    _lastTyping = now;
    try {
      await _td.send({
        '@type': 'sendChatAction',
        'chat_id': chatId,
        'action': {'@type': 'chatActionTyping'},
      });
    } on TdError {
      // typing is best effort
    }
  }

  /// Markdown from the composer to a formattedText with entities.
  Future<TdObject> formatted(String text) async {
    final plain = {'@type': 'formattedText', 'text': text, 'entities': []};
    try {
      final res = await _td.send({'@type': 'parseMarkdown', 'text': plain});
      return res['@type'] == 'formattedText' ? res : plain;
    } on TdError {
      return plain;
    }
  }

  /// Turns a message back into composer markdown.
  Future<String> markdownOf(ChatMessage m) async {
    final f = m.formatted;
    if (f == null) return m.content.text;
    try {
      final res = await _td.send({'@type': 'getMarkdownText', 'text': f});
      return res['@type'] == 'formattedText'
          ? res['text'] as String? ?? m.content.text
          : m.content.text;
    } on TdError {
      return m.content.text;
    }
  }

  Future<TdObject> _textContent(String text) async => {
    '@type': 'inputMessageText',
    'text': await formatted(text),
  };

  TdObject? _replyTo(int? id) => id == null
      ? null
      : {'@type': 'inputMessageReplyToMessage', 'message_id': id};

  Future<void> sendText(String text, {int? replyTo}) async {
    final res = await _td.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'reply_to': ?_replyTo(replyTo),
      'input_message_content': await _textContent(text),
    });
    _put(ChatMessage.fromJson(res));
    final ayu = _settings();
    if (ayu.ghostMode && !ayu.readSilentlyOnReply) {
      await markRead(force: true);
    }
  }

  Future<void> sendSticker(StickerItem s) async {
    final res = await _td.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageSticker',
        'sticker': {
          '@type': 'inputSticker',
          'sticker': {'@type': 'inputFileId', 'id': s.fileId},
          'width': s.width,
          'height': s.height,
        },
        'emoji': s.emoji,
      },
    });
    _put(ChatMessage.fromJson(res));
  }

  Future<void> sendGif(GifItem g) async {
    final res = await _td.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageAnimation',
        'animation': {
          '@type': 'inputAnimation',
          'animation': {'@type': 'inputFileId', 'id': g.fileId},
          'duration': g.duration,
          'width': g.width,
          'height': g.height,
        },
      },
    });
    _put(ChatMessage.fromJson(res));
  }

  Future<void> editText(int messageId, String text) async {
    final res = await _td.send({
      '@type': 'editMessageText',
      'chat_id': chatId,
      'message_id': messageId,
      'input_message_content': await _textContent(text),
    });
    _put(ChatMessage.fromJson(res));
  }

  Future<void> sendPoll({
    required String question,
    required List<String> options,
    bool anonymous = true,
    bool multiple = false,
    bool quiz = false,
    int correct = 0,
  }) async {
    TdObject ft(String t) => {'@type': 'formattedText', 'text': t};
    final res = await _td.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessagePoll',
        'question': ft(question),
        'options': [
          for (final o in options) {'@type': 'inputPollOption', 'text': ft(o)},
        ],
        'is_anonymous': anonymous,
        'allows_multiple_answers': multiple,
        'allows_revoting': !quiz,
        'type': quiz
            ? {
                '@type': 'inputPollTypeQuiz',
                'correct_option_ids': [correct],
              }
            : {'@type': 'inputPollTypeRegular'},
      },
    });
    _put(ChatMessage.fromJson(res));
  }

  Future<void> sendFile(String path, {String caption = ''}) async {
    final ext = path.split('.').last.toLowerCase();
    final file = {'@type': 'inputFileLocal', 'path': path};
    final cap = await formatted(caption);
    final content = switch (ext) {
      'jpg' ||
      'jpeg' ||
      'png' ||
      'webp' ||
      'heic' => {'@type': 'inputMessagePhoto', 'photo': file, 'caption': cap},
      'mp4' || 'mov' || 'mkv' || 'webm' => {
        '@type': 'inputMessageVideo',
        'video': file,
        'caption': cap,
        'supports_streaming': true,
      },
      'mp3' ||
      'm4a' ||
      'flac' ||
      'wav' => {'@type': 'inputMessageAudio', 'audio': file, 'caption': cap},
      _ => {'@type': 'inputMessageDocument', 'document': file, 'caption': cap},
    };
    final res = await _td.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': content,
    });
    _put(ChatMessage.fromJson(res));
  }

  ChatMessage? pinned;

  Future<void> loadPinned() async {
    try {
      final res = await _td.send({
        '@type': 'getChatPinnedMessage',
        'chat_id': chatId,
      });
      pinned = res['@type'] == 'message' ? ChatMessage.fromJson(res) : null;
    } on TdError {
      pinned = null;
    }
    _emit();
  }

  Future<void> toggleReaction(ChatMessage m, String emoji) => _td.send({
    '@type': m.reactions.any((r) => r.emoji == emoji && r.chosen)
        ? 'removeMessageReaction'
        : 'addMessageReaction',
    'chat_id': chatId,
    'message_id': m.id,
    'reaction_type': {'@type': 'reactionTypeEmoji', 'emoji': emoji},
    'is_big': false,
    'update_recent_reactions': true,
  });

  Future<List<String>> availableReactions(int messageId) async {
    try {
      final res = await _td.send({
        '@type': 'getMessageAvailableReactions',
        'chat_id': chatId,
        'message_id': messageId,
        'row_size': 8,
      });
      return <String>{
        for (final key in [
          'top_reactions',
          'recent_reactions',
          'popular_reactions',
        ])
          for (final r in (res[key] as List? ?? const []))
            if (((r as TdObject)['type'] as TdObject?)?['emoji']
                case final String e)
              e,
      }.toList();
    } on TdError {
      return const [];
    }
  }

  Future<void> votePoll(int messageId, List<int> options) => _td.send({
    '@type': 'setPollAnswer',
    'chat_id': chatId,
    'message_id': messageId,
    'option_ids': options,
  });

  Future<void> sendDice(String emoji) async {
    final res = await _td.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {'@type': 'inputMessageDice', 'emoji': emoji},
    });
    _put(ChatMessage.fromJson(res));
  }

  /// Presses an inline callback button; returns the bot's answer.
  Future<({String text, bool alert, String url})> pressCallback(
    int messageId,
    MarkupButton b,
  ) async {
    final res = await _td.send({
      '@type': 'getCallbackQueryAnswer',
      'chat_id': chatId,
      'message_id': messageId,
      'payload': {'@type': 'callbackQueryPayloadData', 'data': b.data},
    });
    return (
      text: res['text'] as String? ?? '',
      alert: res['show_alert'] == true,
      url: res['url'] as String? ?? '',
    );
  }

  /// Message whose reply keyboard is shown under the composer.
  int replyMarkupMessageId = 0;
  List<BotCommand> commands = const [];

  ReplyKeyboard? get replyKeyboard {
    final m = _byId[replyMarkupMessageId];
    final k = m?.markup;
    return k is ReplyKeyboard ? k : null;
  }

  Future<void> loadBotInfo({
    int? botUserId,
    int? supergroupId,
    int? groupId,
  }) async {
    try {
      final TdObject res;
      if (botUserId != null) {
        res = await _td.send({
          '@type': 'getUserFullInfo',
          'user_id': botUserId,
        });
        final info = res['bot_info'] as TdObject?;
        commands = _cmds(info?['commands']);
      } else if (supergroupId != null || groupId != null) {
        res = await _td.send(
          supergroupId != null
              ? {
                  '@type': 'getSupergroupFullInfo',
                  'supergroup_id': supergroupId,
                }
              : {'@type': 'getBasicGroupFullInfo', 'basic_group_id': groupId},
        );
        commands = [
          for (final b in (res['bot_commands'] as List? ?? const []))
            ..._cmds((b as TdObject)['commands']),
        ];
      }
    } on TdError {
      commands = const [];
    }
    _emit();
  }

  Future<void> _loadCommands(TdObject? type) async {
    switch (type?['@type']) {
      case 'chatTypePrivate':
        final uid = type!['user_id'] as int;
        try {
          final u = await _td.send({'@type': 'getUser', 'user_id': uid});
          if ((u['type'] as TdObject?)?['@type'] == 'userTypeBot') {
            await loadBotInfo(botUserId: uid);
          }
        } on TdError {
          return;
        }
      case 'chatTypeSupergroup':
        if (type!['is_channel'] == true) return;
        await loadBotInfo(supergroupId: type['supergroup_id'] as int);
      case 'chatTypeBasicGroup':
        await loadBotInfo(groupId: type!['basic_group_id'] as int);
    }
  }

  static List<BotCommand> _cmds(Object? list) => [
    for (final c in (list as List? ?? const []))
      if (c is TdObject)
        BotCommand(
          c['command'] as String? ?? '',
          c['description'] as String? ?? '',
        ),
  ];

  Future<void> pin(int messageId, {bool unpin = false}) => _td.send(
    unpin
        ? {
            '@type': 'unpinChatMessage',
            'chat_id': chatId,
            'message_id': messageId,
          }
        : {
            '@type': 'pinChatMessage',
            'chat_id': chatId,
            'message_id': messageId,
            'disable_notification': false,
            'only_for_self': false,
          },
  );

  Future<void> forward(int toChatId, List<int> ids) => _td.send({
    '@type': 'forwardMessages',
    'chat_id': toChatId,
    'from_chat_id': chatId,
    'message_ids': ids,
    'send_copy': false,
    'remove_caption': false,
  });

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

  Future<void> markRead({bool force = false}) async {
    if (!force && _settings().ghostMode) return;
    final incoming = _current
        .where((m) => !m.isOutgoing && !m.isDeleted)
        .take(100);
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
        (u['message'] as TdObject?)?['chat_id'] != chatId &&
        u['@type'] != 'updatePoll') {
      return;
    }
    switch (u['@type']) {
      case 'updateNewMessage':
        if (detached) return;
        _put(ChatMessage.fromJson(u['message'] as TdObject));
      case 'updateMessageSendSucceeded' || 'updateMessageSendFailed':
        _byId.remove(u['old_message_id']);
        _put(ChatMessage.fromJson(u['message'] as TdObject));
      case 'updateMessageContent':
        final id = u['message_id'] as int;
        final old = _byId[id];
        if (old == null) return;
        final content = u['new_content'] as TdObject;
        _byId[id] = old.copyWith(
          content: MessagePreview.fromContent(content),
          media: MessageMedia.fromContent(content),
          spans: ChatMessage.spansOf(content),
          linkPreview: ChatMessage.linkPreviewOf(content),
          formatted: ChatMessage.formattedOf(content),
        );
        _emit();
      case 'updatePoll':
        final poll = PollMedia.fromJson(u['poll'] as TdObject?);
        if (poll == null) return;
        for (final m in _byId.values.toList()) {
          final media = m.media;
          if (media is PollMedia && media.id == poll.id) {
            _byId[m.id] = m.copyWith(content: m.content, media: poll);
          }
        }
        _emit();
      case 'updateChatReplyMarkup':
        replyMarkupMessageId = u['reply_markup_message_id'] as int? ?? 0;
        if (replyMarkupMessageId != 0 &&
            !_byId.containsKey(replyMarkupMessageId)) {
          unawaited(
            _fetchReply(replyMarkupMessageId).then((_) {
              final m = _replies[replyMarkupMessageId];
              if (m != null) _put(m);
            }),
          );
        }
        _emit();
      case 'updateMessageInteractionInfo':
        final m = _byId[u['message_id']];
        if (m == null) return;
        _byId[m.id] = m.copyWith(
          reactions: Reaction.listOf(u['interaction_info'] as TdObject?),
        );
        _emit();
      case 'updateMessageIsPinned':
        unawaited(loadPinned());
        final m = _byId[u['message_id']];
        if (m == null) return;
        _byId[m.id] = m.copyWith(isPinned: u['is_pinned'] == true);
      case 'updateMessageEdited':
        final id = u['message_id'] as int;
        final old = _byId[id];
        final edit = u['edit_date'] as int? ?? 0;
        if (old == null) return;
        _byId[id] = old.copyWith(
          editDate: edit == 0
              ? null
              : DateTime.fromMillisecondsSinceEpoch(edit * 1000),
          markup: ReplyMarkup.fromJson(u['reply_markup'] as TdObject?),
        );
        _emit();
      case 'updateChatReadOutbox':
        _lastReadOutbox = u['last_read_outbox_message_id'] as int? ?? 0;
        _emit();
      case 'updateDeleteMessages':
        if (u['is_permanent'] != true) return;
        final keep = _settings().saveDeleted && u['from_cache'] != true;
        final now = DateTime.now();
        for (final id in (u['message_ids'] as List? ?? const [])) {
          final m = _byId[id];
          if (m == null) continue;
          if (keep) {
            _byId[id as int] = m.copyWith(deletedAt: now);
          } else {
            _byId.remove(id);
          }
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
