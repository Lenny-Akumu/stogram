import '../../core/tdlib/td_api.dart';
import '../../core/tdlib/td_dispatcher.dart';
import '../../core/tdlib/td_error.dart';
import '../messages/message_media.dart';

class StickerItem {
  const StickerItem({
    required this.fileId,
    required this.preview,
    this.width = 512,
    this.height = 512,
    this.emoji = '',
  });

  static StickerItem? fromJson(TdObject s) {
    final file = s['sticker'] as TdObject?;
    final id = file?['id'] as int?;
    if (id == null) return null;
    final isStatic =
        (s['format'] as TdObject?)?['@type'] == 'stickerFormatWebp';
    final thumb = (s['thumbnail'] as TdObject?)?['file'] as TdObject?;
    final show = isStatic ? file : thumb;
    return StickerItem(
      fileId: id,
      preview: MediaImage(fileId: show?['id'] as int?, file: show),
      width: s['width'] as int? ?? 512,
      height: s['height'] as int? ?? 512,
      emoji: s['emoji'] as String? ?? '',
    );
  }

  final int fileId;
  final MediaImage preview;
  final int width;
  final int height;
  final String emoji;
}

class StickerSetInfo {
  const StickerSetInfo({required this.id, required this.title, this.cover});

  final int id;
  final String title;
  final MediaImage? cover;
}

class GifItem {
  const GifItem({
    required this.fileId,
    required this.cover,
    this.width = 0,
    this.height = 0,
    this.duration = 0,
  });

  static GifItem? fromJson(TdObject a) {
    final file = a['animation'] as TdObject?;
    final id = file?['id'] as int?;
    if (id == null) return null;
    final thumb = (a['thumbnail'] as TdObject?)?['file'] as TdObject?;
    return GifItem(
      fileId: id,
      cover: MediaImage(
        fileId: thumb?['id'] as int?,
        file: thumb,
        width: a['width'] as int? ?? 0,
        height: a['height'] as int? ?? 0,
        mini: decodeMini(a['minithumbnail'] as TdObject?),
      ),
      width: a['width'] as int? ?? 0,
      height: a['height'] as int? ?? 0,
      duration: a['duration'] as int? ?? 0,
    );
  }

  final int fileId;
  final MediaImage cover;
  final int width;
  final int height;
  final int duration;
}

class StickersRepository {
  StickersRepository(this._td);

  final TdApi _td;
  List<StickerSetInfo>? _sets;
  final _stickers = <int, List<StickerItem>>{};

  Future<List<StickerSetInfo>> installedSets() async {
    final cached = _sets;
    if (cached != null) return cached;
    try {
      final res = await _td.send({
        '@type': 'getInstalledStickerSets',
        'sticker_type': {'@type': 'stickerTypeRegular'},
      });
      return _sets = [
        for (final s in (res['sets'] as List? ?? const []).cast<TdObject>())
          StickerSetInfo(
            id: int.parse('${s['id']}'),
            title: s['title'] as String? ?? '',
            cover: () {
              final t = (s['thumbnail'] as TdObject?)?['file'] as TdObject?;
              final first = (s['covers'] as List?)
                  ?.cast<TdObject>()
                  .firstOrNull;
              final f =
                  t ?? (first?['thumbnail'] as TdObject?)?['file'] as TdObject?;
              return f == null
                  ? null
                  : MediaImage(fileId: f['id'] as int?, file: f);
            }(),
          ),
      ];
    } on TdError {
      return const [];
    }
  }

  Future<List<StickerItem>> stickers(int setId) async {
    final cached = _stickers[setId];
    if (cached != null) return cached;
    try {
      final res = await _td.send({'@type': 'getStickerSet', 'set_id': setId});
      return _stickers[setId] = [
        for (final s in (res['stickers'] as List? ?? const []).cast<TdObject>())
          ?StickerItem.fromJson(s),
      ];
    } on TdError {
      return const [];
    }
  }

  Future<List<GifItem>> savedGifs() async {
    try {
      final res = await _td.send({'@type': 'getSavedAnimations'});
      return [
        for (final a
            in (res['animations'] as List? ?? const []).cast<TdObject>())
          ?GifItem.fromJson(a),
      ];
    } on TdError {
      return const [];
    }
  }
}
