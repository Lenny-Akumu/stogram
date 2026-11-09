import '../../core/tdlib/td_dispatcher.dart';
import '../chats/chat_summary.dart';
import 'message_media.dart';

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

  bool get isEdited => editDate != null;

  ChatMessage copyWith({
    MessagePreview? content,
    MessageMedia? media,
    DateTime? editDate,
    DateTime? deletedAt,
    SendState? sendState,
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
  });

  factory MessageActions.fromJson(TdObject json) => MessageActions(
    canReply: json['can_be_replied'] == true,
    canEdit: json['can_be_edited'] == true,
    canCopy: json['can_be_copied'] != false,
    canDeleteForSelf: json['can_be_deleted_only_for_self'] == true,
    canDeleteForAll: json['can_be_deleted_for_all_users'] == true,
  );

  final bool canReply;
  final bool canEdit;
  final bool canCopy;
  final bool canDeleteForSelf;
  final bool canDeleteForAll;

  bool get canDelete => canDeleteForSelf || canDeleteForAll;
}
