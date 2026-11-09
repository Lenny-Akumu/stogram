import '../../core/tdlib/td_dispatcher.dart';
import '../messages/message_media.dart';

enum PreviewKind {
  text,
  photo,
  video,
  voice,
  videoNote,
  sticker,
  gif,
  audio,
  document,
  location,
  contact,
  poll,
  other,
}

class MessagePreview {
  const MessagePreview(this.kind, this.text);

  factory MessagePreview.fromContent(TdObject content) {
    String caption() =>
        (content['caption'] as TdObject?)?['text'] as String? ?? '';
    return switch (content['@type']) {
      'messageText' => MessagePreview(
        PreviewKind.text,
        (content['text'] as TdObject?)?['text'] as String? ?? '',
      ),
      'messagePhoto' => MessagePreview(PreviewKind.photo, caption()),
      'messageVideo' => MessagePreview(PreviewKind.video, caption()),
      'messageVoiceNote' => MessagePreview(PreviewKind.voice, caption()),
      'messageVideoNote' => const MessagePreview(PreviewKind.videoNote, ''),
      'messageSticker' => MessagePreview(
        PreviewKind.sticker,
        (content['sticker'] as TdObject?)?['emoji'] as String? ?? '',
      ),
      'messageAnimation' => MessagePreview(PreviewKind.gif, caption()),
      'messageAudio' => MessagePreview(PreviewKind.audio, caption()),
      'messageDocument' => MessagePreview(PreviewKind.document, caption()),
      'messageLocation' ||
      'messageVenue' => const MessagePreview(PreviewKind.location, ''),
      'messageContact' => const MessagePreview(PreviewKind.contact, ''),
      'messagePoll' => MessagePreview(
        PreviewKind.poll,
        ((content['poll'] as TdObject?)?['question'] as TdObject?)?['text']
                as String? ??
            '',
      ),
      _ => const MessagePreview(PreviewKind.other, ''),
    };
  }

  final PreviewKind kind;
  final String text;
}

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.title,
    required this.order,
    required this.isPinned,
    required this.unreadCount,
    required this.preview,
    required this.date,
    this.isGroup = false,
    this.photo,
    this.peer = const ChatPeer(),
  });

  final int id;
  final String title;
  final int order;
  final bool isPinned;
  final int unreadCount;
  final MessagePreview? preview;
  final DateTime? date;
  final bool isGroup;
  final MediaImage? photo;
  final ChatPeer peer;
}

class ChatPeer {
  const ChatPeer({
    this.userId,
    this.basicGroupId,
    this.supergroupId,
    this.isChannel = false,
  });

  factory ChatPeer.fromType(TdObject? type) => switch (type?['@type']) {
    'chatTypePrivate' ||
    'chatTypeSecret' => ChatPeer(userId: type?['user_id'] as int?),
    'chatTypeBasicGroup' => ChatPeer(
      basicGroupId: type?['basic_group_id'] as int?,
    ),
    'chatTypeSupergroup' => ChatPeer(
      supergroupId: type?['supergroup_id'] as int?,
      isChannel: type?['is_channel'] == true,
    ),
    _ => const ChatPeer(),
  };

  final int? userId;
  final int? basicGroupId;
  final int? supergroupId;
  final bool isChannel;
}

MediaImage? chatPhoto(TdObject? info) {
  if (info == null) return null;
  final small = info['small'] as TdObject?;
  return MediaImage(
    fileId: small?['id'] as int?,
    mini: decodeMini(info['minithumbnail'] as TdObject?),
    file: small,
  );
}
