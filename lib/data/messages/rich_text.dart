import '../../core/tdlib/td_dispatcher.dart';
import 'message_media.dart';

enum SpanKind {
  url,
  textUrl,
  email,
  mention,
  bold,
  italic,
  code,
  strike,
  underline,
}

class TextSpanInfo {
  const TextSpanInfo(this.offset, this.length, this.kind, {this.url = ''});

  final int offset;
  final int length;
  final SpanKind kind;

  /// Target for links; for plain urls and mentions it is derived from text.
  final String url;
}

List<TextSpanInfo> parseEntities(TdObject? formatted) {
  final list = (formatted?['entities'] as List?) ?? const [];
  final out = <TextSpanInfo>[];
  for (final e in list) {
    if (e is! TdObject) continue;
    final type = e['type'] as TdObject?;
    final offset = e['offset'] as int? ?? 0;
    final length = e['length'] as int? ?? 0;
    final kind = switch (type?['@type']) {
      'textEntityTypeUrl' => SpanKind.url,
      'textEntityTypeTextUrl' => SpanKind.textUrl,
      'textEntityTypeEmailAddress' => SpanKind.email,
      'textEntityTypeMention' => SpanKind.mention,
      'textEntityTypeBold' => SpanKind.bold,
      'textEntityTypeItalic' => SpanKind.italic,
      'textEntityTypeCode' ||
      'textEntityTypePre' ||
      'textEntityTypePreCode' => SpanKind.code,
      'textEntityTypeStrikethrough' => SpanKind.strike,
      'textEntityTypeUnderline' => SpanKind.underline,
      _ => null,
    };
    if (kind == null || length <= 0) continue;
    out.add(
      TextSpanInfo(
        offset,
        length,
        kind,
        url: kind == SpanKind.textUrl ? (type?['url'] as String? ?? '') : '',
      ),
    );
  }
  return out;
}

/// Resolves where a link span points to.
String spanTarget(String text, TextSpanInfo s) {
  final raw = text.substring(s.offset, s.offset + s.length);
  return switch (s.kind) {
    SpanKind.textUrl => s.url,
    SpanKind.email => 'mailto:$raw',
    SpanKind.mention => 'https://t.me/${raw.replaceFirst('@', '')}',
    _ => raw.contains('://') ? raw : 'https://$raw',
  };
}

class LinkPreviewData {
  const LinkPreviewData({
    required this.url,
    this.siteName = '',
    this.title = '',
    this.description = '',
    this.photo,
  });

  static LinkPreviewData? fromJson(TdObject? json) {
    if (json == null) return null;
    final type = json['type'] as TdObject?;
    final photo =
        (type?['photo'] ?? type?['cover'] ?? type?['thumbnail']) as TdObject?;
    MediaImage? image;
    if (photo != null) {
      final m = MessageMedia.fromContent({
        '@type': 'messagePhoto',
        'photo': photo,
      });
      if (m is PhotoMedia) image = m.image;
    }
    return LinkPreviewData(
      url: json['url'] as String? ?? '',
      siteName: json['site_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: (json['description'] as TdObject?)?['text'] as String? ?? '',
      photo: image,
    );
  }

  final String url;
  final String siteName;
  final String title;
  final String description;
  final MediaImage? photo;

  bool get isEmpty => siteName.isEmpty && title.isEmpty && description.isEmpty;
}
