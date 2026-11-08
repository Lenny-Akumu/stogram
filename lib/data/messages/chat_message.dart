import '../../core/tdlib/td_dispatcher.dart';
import '../chats/chat_summary.dart';

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
  });

  factory ChatMessage.fromJson(TdObject json) {
    final sender = json['sender_id'] as TdObject?;
    final sending = (json['sending_state'] as TdObject?)?['@type'];
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

  bool get isEdited => editDate != null;

  ChatMessage copyWith({
    MessagePreview? content,
    DateTime? editDate,
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
  );

  static DateTime _time(Object? seconds) =>
      DateTime.fromMillisecondsSinceEpoch(((seconds as int?) ?? 0) * 1000);
}
