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
      _ => null,
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
  });
  final MediaImage cover;
  final int duration;
  final bool isGif;
  final bool isRound;

  @override
  List<TdObject> get files => [?cover.file];
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
  const VoiceMedia({required this.duration});
  final int duration;

  @override
  List<TdObject> get files => const [];
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

DocumentMedia? _audio(TdObject? a) {
  final file = a?['audio'] as TdObject?;
  if (file == null) return null;
  final title = [
    a?['performer'] as String? ?? '',
    a?['title'] as String? ?? '',
  ].where((s) => s.isNotEmpty).join(' — ');
  return DocumentMedia(
    fileId: file['id'] as int,
    name: title.isEmpty ? (a?['file_name'] as String? ?? '') : title,
    size: file['size'] as int? ?? 0,
    file: file,
  );
}

VoiceMedia? _voice(TdObject? v) =>
    v == null ? null : VoiceMedia(duration: v['duration'] as int? ?? 0);
