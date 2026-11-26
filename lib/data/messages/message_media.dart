import 'dart:convert';
import 'dart:typed_data';

import '../../core/tdlib/td_dispatcher.dart';

sealed class MessageMedia {
  const MessageMedia();

  static MessageMedia? fromContent(TdObject content) {
    return switch (content['@type']) {
      'messagePhoto' => _photo(content['photo'] as TdObject?),
      'messageSticker' => _sticker(content['sticker'] as TdObject?),
      'messageVideo' => _video(content['video'] as TdObject?, gif: false),
      'messageAnimation' => _video(
        content['animation'] as TdObject?,
        gif: true,
      ),
      'messageVideoNote' => _video(
        content['video_note'] as TdObject?,
        gif: false,
        round: true,
      ),
      'messageDocument' => _document(content['document'] as TdObject?),
      'messageAudio' => _audio(content['audio'] as TdObject?),
      'messageVoiceNote' => _voice(content['voice_note'] as TdObject?),
      'messagePoll' => PollMedia.fromJson(content['poll'] as TdObject?),
      'messageLocation' || 'messageVenue' => _location(content),
      'messageContact' => _contact(content['contact'] as TdObject?),
      'messageDice' => DiceMedia(
        content['emoji'] as String? ?? '🎲',
        content['value'] as int? ?? 0,
      ),
      _ => ServiceMedia.fromContent(content),
    };
  }

  /// Every file object the media references, so the files cache knows them.
  List<TdObject> get files;
}

class MediaImage {
  const MediaImage({
    required this.fileId,
    this.width = 0,
    this.height = 0,
    this.mini,
    this.file,
  });

  final int? fileId;
  final int width;
  final int height;
  final Uint8List? mini;
  final TdObject? file;

  double get aspect => width > 0 && height > 0 ? width / height : 1;
}

class PhotoMedia extends MessageMedia {
  const PhotoMedia(this.image);
  final MediaImage image;

  @override
  List<TdObject> get files => [?image.file];
}

class StickerMedia extends MessageMedia {
  const StickerMedia(this.image, {required this.emoji, required this.isStatic});
  final MediaImage image;
  final String emoji;
  final bool isStatic;

  @override
  List<TdObject> get files => [?image.file];
}

class VideoMedia extends MessageMedia {
  const VideoMedia(
    this.cover, {
    required this.duration,
    this.isGif = false,
    this.isRound = false,
    this.fileId,
    this.file,
  });
  final MediaImage cover;
  final int duration;
  final bool isGif;
  final bool isRound;
  final int? fileId;
  final TdObject? file;

  @override
  List<TdObject> get files => [?cover.file, ?file];
}

class DocumentMedia extends MessageMedia {
  const DocumentMedia({
    required this.fileId,
    required this.name,
    required this.size,
    this.file,
  });
  final int fileId;
  final String name;
  final int size;
  final TdObject? file;

  @override
  List<TdObject> get files => [?file];
}

class VoiceMedia extends MessageMedia {
  const VoiceMedia({
    required this.duration,
    this.fileId,
    this.file,
    this.waveform = const [],
  });
  final int duration;
  final int? fileId;
  final TdObject? file;

  /// 0..31 per sample, as Telegram packs it.
  final List<int> waveform;

  @override
  List<TdObject> get files => [?file];
}

class AudioMedia extends MessageMedia {
  const AudioMedia({
    required this.fileId,
    required this.title,
    required this.duration,
    this.file,
  });
  final int fileId;
  final String title;
  final int duration;
  final TdObject? file;

  @override
  List<TdObject> get files => [?file];
}

/// Unpacks Telegram's 5-bit waveform into values 0..31.
List<int> decodeWaveform(Object? data) {
  if (data is! String || data.isEmpty) return const [];
  final Uint8List bytes;
  try {
    bytes = base64Decode(data);
  } on FormatException {
    return const [];
  }
  final count = bytes.length * 8 ~/ 5;
  return [
    for (var i = 0; i < count; i++)
      () {
        final bit = i * 5;
        final byte = bit >> 3;
        final shift = bit & 7;
        final lo = bytes[byte];
        final hi = byte + 1 < bytes.length ? bytes[byte + 1] : 0;
        return ((lo | (hi << 8)) >> shift) & 31;
      }(),
  ];
}

Uint8List? decodeMini(TdObject? mini) {
  final data = mini?['data'];
  if (data is! String || data.isEmpty) return null;
  try {
    return base64Decode(data);
  } on FormatException {
    return null;
  }
}

MediaImage _image(TdObject? file, int w, int h, TdObject? mini) => MediaImage(
  fileId: file?['id'] as int?,
  width: w,
  height: h,
  mini: decodeMini(mini),
  file: file,
);

PhotoMedia? _photo(TdObject? photo) {
  final sizes = (photo?['sizes'] as List?)?.cast<TdObject>() ?? const [];
  if (sizes.isEmpty) return null;
  var pick = sizes.last;
  for (final s in sizes) {
    final w = s['width'] as int? ?? 0;
    final h = s['height'] as int? ?? 0;
    if (w <= 1280 && h <= 1280) pick = s;
  }
  return PhotoMedia(
    _image(
      pick['photo'] as TdObject?,
      pick['width'] as int? ?? 0,
      pick['height'] as int? ?? 0,
      photo?['minithumbnail'] as TdObject?,
    ),
  );
}

StickerMedia? _sticker(TdObject? s) {
  if (s == null) return null;
  final format = (s['format'] as TdObject?)?['@type'];
  final isStatic = format == 'stickerFormatWebp';
  final thumb = s['thumbnail'] as TdObject?;
  final file = isStatic
      ? s['sticker'] as TdObject?
      : thumb?['file'] as TdObject?;
  return StickerMedia(
    _image(file, s['width'] as int? ?? 512, s['height'] as int? ?? 512, null),
    emoji: s['emoji'] as String? ?? '',
    isStatic: isStatic,
  );
}

VideoMedia? _video(TdObject? v, {required bool gif, bool round = false}) {
  if (v == null) return null;
  final thumb = v['thumbnail'] as TdObject?;
  final length = v['length'] as int?;
  final file = (v['video'] ?? v['animation']) as TdObject?;
  return VideoMedia(
    _image(
      thumb?['file'] as TdObject?,
      v['width'] as int? ?? length ?? thumb?['width'] as int? ?? 0,
      v['height'] as int? ?? length ?? thumb?['height'] as int? ?? 0,
      v['minithumbnail'] as TdObject?,
    ),
    duration: v['duration'] as int? ?? 0,
    isGif: gif,
    isRound: round,
    fileId: file?['id'] as int?,
    file: file,
  );
}

DocumentMedia? _document(TdObject? d) {
  final file = d?['document'] as TdObject?;
  if (file == null) return null;
  return DocumentMedia(
    fileId: file['id'] as int,
    name: d?['file_name'] as String? ?? '',
    size: file['size'] as int? ?? 0,
    file: file,
  );
}

AudioMedia? _audio(TdObject? a) {
  final file = a?['audio'] as TdObject?;
  if (file == null) return null;
  final title = [
    a?['performer'] as String? ?? '',
    a?['title'] as String? ?? '',
  ].where((s) => s.isNotEmpty).join(' — ');
  return AudioMedia(
    fileId: file['id'] as int,
    title: title.isEmpty ? (a?['file_name'] as String? ?? '') : title,
    duration: a?['duration'] as int? ?? 0,
    file: file,
  );
}

VoiceMedia? _voice(TdObject? v) {
  if (v == null) return null;
  final file = v['voice'] as TdObject?;
  return VoiceMedia(
    duration: v['duration'] as int? ?? 0,
    fileId: file?['id'] as int?,
    file: file,
    waveform: decodeWaveform(v['waveform']),
  );
}

class PollOption {
  const PollOption({
    required this.text,
    required this.voters,
    required this.percent,
    required this.chosen,
  });
  final String text;
  final int voters;
  final int percent;
  final bool chosen;
}

class PollMedia extends MessageMedia {
  const PollMedia({
    required this.id,
    required this.question,
    required this.options,
    required this.total,
    this.isQuiz = false,
    this.correct = const [],
    this.explanation = '',
    this.multiple = false,
    this.anonymous = true,
    this.closed = false,
  });

  static PollMedia? fromJson(TdObject? p) {
    if (p == null) return null;
    final type = p['type'] as TdObject? ?? const {};
    return PollMedia(
      id: p['id'] as int? ?? 0,
      question: (p['question'] as TdObject?)?['text'] as String? ?? '',
      options: [
        for (final o in (p['options'] as List? ?? const []))
          if (o is TdObject)
            PollOption(
              text: (o['text'] as TdObject?)?['text'] as String? ?? '',
              voters: o['voter_count'] as int? ?? 0,
              percent: o['vote_percentage'] as int? ?? 0,
              chosen: o['is_chosen'] == true,
            ),
      ],
      total: p['total_voter_count'] as int? ?? 0,
      isQuiz: type['@type'] == 'pollTypeQuiz',
      correct: [
        for (final i in (type['correct_option_ids'] as List? ?? const []))
          i as int,
      ],
      explanation: (type['explanation'] as TdObject?)?['text'] as String? ?? '',
      multiple: p['allows_multiple_answers'] == true,
      anonymous: p['is_anonymous'] != false,
      closed: p['is_closed'] == true,
    );
  }

  final int id;
  final String question;
  final List<PollOption> options;
  final int total;
  final bool isQuiz;
  final List<int> correct;
  final String explanation;
  final bool multiple;
  final bool anonymous;
  final bool closed;

  bool get voted => options.any((o) => o.chosen);
  bool get showResults => voted || closed;

  @override
  List<TdObject> get files => const [];
}

class LocationMedia extends MessageMedia {
  const LocationMedia(this.lat, this.lon, {this.title = '', this.address = ''});
  final double lat;
  final double lon;
  final String title;
  final String address;

  String get mapUrl =>
      'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=16/$lat/$lon';

  @override
  List<TdObject> get files => const [];
}

class ContactMedia extends MessageMedia {
  const ContactMedia({required this.name, required this.phone, this.userId});
  final String name;
  final String phone;
  final int? userId;

  @override
  List<TdObject> get files => const [];
}

class DiceMedia extends MessageMedia {
  const DiceMedia(this.emoji, this.value);
  final String emoji;
  final int value;

  @override
  List<TdObject> get files => const [];
}

enum ServiceKind {
  created,
  title,
  photo,
  photoRemoved,
  joined,
  joinedByLink,
  added,
  removed,
  pinned,
  screenshot,
  upgraded,
  autoDelete,
  contactJoined,
  call,
  custom,
}

/// Chat events shown as a centered pill instead of a bubble.
class ServiceMedia extends MessageMedia {
  const ServiceMedia(
    this.kind, {
    this.users = const [],
    this.text = '',
    this.messageId,
    this.seconds = 0,
  });

  static ServiceMedia? fromContent(TdObject c) {
    List<int> ids(String key) => [
      for (final i in (c[key] as List? ?? const [])) i as int,
    ];
    return switch (c['@type']) {
      'messageBasicGroupChatCreate' || 'messageSupergroupChatCreate' =>
        ServiceMedia(ServiceKind.created, text: c['title'] as String? ?? ''),
      'messageChatChangeTitle' => ServiceMedia(
        ServiceKind.title,
        text: c['title'] as String? ?? '',
      ),
      'messageChatChangePhoto' => const ServiceMedia(ServiceKind.photo),
      'messageChatDeletePhoto' => const ServiceMedia(ServiceKind.photoRemoved),
      'messageChatAddMembers' => ServiceMedia(
        ServiceKind.added,
        users: ids('member_user_ids'),
      ),
      'messageChatJoinByLink' || 'messageChatJoinByRequest' =>
        const ServiceMedia(ServiceKind.joinedByLink),
      'messageChatDeleteMember' => ServiceMedia(
        ServiceKind.removed,
        users: [c['user_id'] as int? ?? 0],
      ),
      'messagePinMessage' => ServiceMedia(
        ServiceKind.pinned,
        messageId: c['message_id'] as int?,
      ),
      'messageScreenshotTaken' => const ServiceMedia(ServiceKind.screenshot),
      'messageChatUpgradeTo' ||
      'messageChatUpgradeFrom' => const ServiceMedia(ServiceKind.upgraded),
      'messageChatSetMessageAutoDeleteTime' => ServiceMedia(
        ServiceKind.autoDelete,
        seconds: c['message_auto_delete_time'] as int? ?? 0,
      ),
      'messageContactRegistered' => const ServiceMedia(
        ServiceKind.contactJoined,
      ),
      'messageCall' => ServiceMedia(
        ServiceKind.call,
        seconds: c['duration'] as int? ?? 0,
        text: c['is_video'] == true ? 'video' : '',
      ),
      'messageCustomServiceAction' => ServiceMedia(
        ServiceKind.custom,
        text: c['text'] as String? ?? '',
      ),
      _ => null,
    };
  }

  final ServiceKind kind;
  final List<int> users;
  final String text;
  final int? messageId;
  final int seconds;

  /// Calls look like normal bubbles in Telegram, everything else is a pill.
  bool get isPill => kind != ServiceKind.call;

  @override
  List<TdObject> get files => const [];
}

LocationMedia? _location(TdObject c) {
  final venue = c['venue'] as TdObject?;
  final loc = (venue?['location'] ?? c['location']) as TdObject?;
  if (loc == null) return null;
  return LocationMedia(
    (loc['latitude'] as num?)?.toDouble() ?? 0,
    (loc['longitude'] as num?)?.toDouble() ?? 0,
    title: venue?['title'] as String? ?? '',
    address: venue?['address'] as String? ?? '',
  );
}

ContactMedia? _contact(TdObject? c) {
  if (c == null) return null;
  final name = [
    c['first_name'] as String? ?? '',
    c['last_name'] as String? ?? '',
  ].where((s) => s.isNotEmpty).join(' ');
  final uid = c['user_id'] as int? ?? 0;
  return ContactMedia(
    name: name,
    phone: c['phone_number'] as String? ?? '',
    userId: uid == 0 ? null : uid,
  );
}
