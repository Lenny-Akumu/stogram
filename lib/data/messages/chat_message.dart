import '../../core/tdlib/td_dispatcher.dart';
import '../chats/chat_summary.dart';
import 'message_media.dart';
import 'reply_markup.dart';
import 'rich_text.dart';

enum SendState { sent, pending, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.isOutgoing,
    required this.senderUserId,
    required this.date,
    required this.editDate,
    required this.content,
    required this.sendState,
    this.replyToId,
    this.media,
    this.deletedAt,
    this.spans = const [],
    this.linkPreview,
    this.formatted,
    this.markup,
    this.forward,
    this.viaBotId,
    this.isPinned = false,
    this.reactions = const [],
  });

  factory ChatMessage.fromJson(TdObject json) {
    final sender = json['sender_id'] as TdObject?;
    final sending = (json['sending_state'] as TdObject?)?['@type'];
    final reply = json['reply_to'] as TdObject?;
    final sameChatReply =
        reply?['@type'] == 'messageReplyToMessage' &&
        (reply?['chat_id'] == json['chat_id'] || reply?['chat_id'] == 0);
    return ChatMessage(
      id: json['id'] as int,
      chatId: json['chat_id'] as int,
      isOutgoing: json['is_outgoing'] as bool? ?? false,
      senderUserId: sender?['@type'] == 'messageSenderUser'
          ? sender!['user_id'] as int?
          : null,
      date: _time(json['date']),
      editDate: json['edit_date'] == 0 ? null : _time(json['edit_date']),
      content: MessagePreview.fromContent(json['content'] as TdObject),
      sendState: switch (sending) {
        'messageSendingStatePending' => SendState.pending,
        'messageSendingStateFailed' => SendState.failed,
        _ => SendState.sent,
      },
      replyToId: sameChatReply ? reply!['message_id'] as int? : null,
      media: MessageMedia.fromContent(json['content'] as TdObject),
      spans: spansOf(json['content'] as TdObject),
      linkPreview: linkPreviewOf(json['content'] as TdObject),
      formatted: formattedOf(json['content'] as TdObject),
      markup: ReplyMarkup.fromJson(json['reply_markup'] as TdObject?),
      forward: ForwardOrigin.fromJson(json['forward_info'] as TdObject?),
      viaBotId: json['via_bot_user_id'] == 0
          ? null
          : json['via_bot_user_id'] as int?,
      isPinned: json['is_pinned'] == true,
      reactions: Reaction.listOf(json['interaction_info'] as TdObject?),
    );
  }

  final int id;
  final int chatId;
  final bool isOutgoing;
  final int? senderUserId;
  final DateTime date;
  final DateTime? editDate;
  final MessagePreview content;
  final SendState sendState;
  final int? replyToId;
  final MessageMedia? media;

  /// Set when the message was deleted but kept by the archive.
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  final List<TextSpanInfo> spans;
  final LinkPreviewData? linkPreview;

  /// Raw formattedText of the text or caption, kept for editing.
  final TdObject? formatted;
  final ReplyMarkup? markup;
  final ForwardOrigin? forward;
  final int? viaBotId;
  final bool isPinned;
  final List<Reaction> reactions;

  static TdObject? formattedOf(TdObject content) =>
      (content['text'] ?? content['caption']) as TdObject?;

  static List<TextSpanInfo> spansOf(TdObject content) =>
      parseEntities((content['text'] ?? content['caption']) as TdObject?);

  static LinkPreviewData? linkPreviewOf(TdObject content) {
    final p = LinkPreviewData.fromJson(content['link_preview'] as TdObject?);
    return p == null || p.isEmpty ? null : p;
  }

  bool get isEdited => editDate != null;

  ChatMessage copyWith({
    MessagePreview? content,
    MessageMedia? media,
    DateTime? editDate,
    DateTime? deletedAt,
    SendState? sendState,
    List<TextSpanInfo>? spans,
    LinkPreviewData? linkPreview,
    TdObject? formatted,
    ReplyMarkup? markup,
    bool? isPinned,
    List<Reaction>? reactions,
  }) => ChatMessage(
    id: id,
    chatId: chatId,
    isOutgoing: isOutgoing,
    senderUserId: senderUserId,
    date: date,
    editDate: editDate ?? this.editDate,
    content: content ?? this.content,
    sendState: sendState ?? this.sendState,
    replyToId: replyToId,
    media: content == null ? this.media : media,
    deletedAt: deletedAt ?? this.deletedAt,
    spans: spans ?? this.spans,
    linkPreview: content == null ? this.linkPreview : linkPreview,
    formatted: formatted ?? this.formatted,
    markup: markup ?? this.markup,
    forward: forward,
    viaBotId: viaBotId,
    isPinned: isPinned ?? this.isPinned,
    reactions: reactions ?? this.reactions,
  );

  static DateTime _time(Object? seconds) =>
      DateTime.fromMillisecondsSinceEpoch(((seconds as int?) ?? 0) * 1000);
}

class MessageActions {
  const MessageActions({
    this.canReply = false,
    this.canEdit = false,
    this.canCopy = false,
    this.canDeleteForSelf = false,
    this.canDeleteForAll = false,
    this.canPin = false,
    this.canForward = true,
  });

  factory MessageActions.fromJson(TdObject json) => MessageActions(
    canReply: json['can_be_replied'] == true,
    canEdit: json['can_be_edited'] == true,
    canCopy: json['can_be_copied'] != false,
    canDeleteForSelf: json['can_be_deleted_only_for_self'] == true,
    canDeleteForAll: json['can_be_deleted_for_all_users'] == true,
    canPin: json['can_be_pinned'] == true,
    canForward: json['can_be_forwarded'] != false,
  );

  final bool canReply;
  final bool canEdit;
  final bool canCopy;
  final bool canDeleteForSelf;
  final bool canDeleteForAll;
  final bool canPin;
  final bool canForward;

  bool get canDelete => canDeleteForSelf || canDeleteForAll;
}

class ForwardOrigin {
  const ForwardOrigin({this.userId, this.chatId, this.name = ''});

  static ForwardOrigin? fromJson(TdObject? info) {
    final o = info?['origin'] as TdObject?;
    return switch (o?['@type']) {
      'messageOriginUser' => ForwardOrigin(
        userId: o!['sender_user_id'] as int?,
      ),
      'messageOriginHiddenUser' => ForwardOrigin(
        name: o!['sender_name'] as String? ?? '',
      ),
      'messageOriginChat' => ForwardOrigin(
        chatId: o!['sender_chat_id'] as int?,
        name: o['author_signature'] as String? ?? '',
      ),
      'messageOriginChannel' => ForwardOrigin(
        chatId: o!['chat_id'] as int?,
        name: o['author_signature'] as String? ?? '',
      ),
      _ => null,
    };
  }

  final int? userId;
  final int? chatId;
  final String name;
}

class Reaction {
  const Reaction(this.emoji, this.count, {this.chosen = false});

  static List<Reaction> listOf(TdObject? info) {
    final list =
        ((info?['reactions'] as TdObject?)?['reactions'] as List?) ?? const [];
    return [
      for (final r in list)
        if (r is TdObject &&
            (r['type'] as TdObject?)?['@type'] == 'reactionTypeEmoji')
          Reaction(
            (r['type'] as TdObject)['emoji'] as String? ?? '',
            r['total_count'] as int? ?? 0,
            chosen: r['is_chosen'] == true,
          ),
    ];
  }

  final String emoji;
  final int count;
  final bool chosen;
}
