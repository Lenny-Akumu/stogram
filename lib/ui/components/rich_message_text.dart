import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/messages/rich_text.dart';
import 'td_image.dart';

Future<void> openLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

typedef EntityTap = bool Function(TextSpanInfo span, String raw);

/// Message text with tappable links, blocks and Telegram's inline styles.
class RichMessageText extends StatefulWidget {
  const RichMessageText({
    super.key,
    required this.text,
    required this.spans,
    required this.style,
    required this.linkColor,
    this.onEntity,
  });

  final String text;
  final List<TextSpanInfo> spans;
  final TextStyle style;
  final Color linkColor;

  /// Returns true when the tap was handled in-app.
  final EntityTap? onEntity;

  @override
  State<RichMessageText> createState() => _RichMessageTextState();
}

class _RichMessageTextState extends State<RichMessageText> {
  final _recognizers = <TapGestureRecognizer>[];
  final _revealed = <int>{};
  final _expanded = <int>{};

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  void _clear() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _tap(TextSpanInfo s) {
    final raw = widget.text.substring(s.offset, s.end);
    if (widget.onEntity?.call(s, raw) ?? false) return;
    switch (s.kind) {
      case SpanKind.bankCard || SpanKind.cashtag || SpanKind.hashtag:
        unawaited(Clipboard.setData(ClipboardData(text: raw)));
      case SpanKind.botCommand || SpanKind.mentionName:
        break;
      default:
        unawaited(openLink(spanTarget(widget.text, s)));
    }
  }

  List<InlineSpan> _inline(int from, int to, List<TextSpanInfo> spans) {
    final text = widget.text;
    final cuts = <int>{from, to};
    for (final s in spans) {
      if (s.end <= from || s.offset >= to) continue;
      cuts
        ..add(s.offset.clamp(from, to))
        ..add(s.end.clamp(from, to));
    }
    final points = cuts.toList()..sort();
    final children = <InlineSpan>[];
    final spoilerBg = widget.style.color ?? Colors.grey;
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (a == b) continue;
      final active = spans.where((s) => s.offset <= a && s.end >= b);
      var style = const TextStyle();
      TapGestureRecognizer? tap;
      TextSpanInfo? hidden;
      for (final s in active) {
        if (s.kind == SpanKind.spoiler && !_revealed.contains(s.offset)) {
          hidden = s;
        }
        style = style.merge(switch (s.kind) {
          SpanKind.bold => const TextStyle(fontWeight: FontWeight.w700),
          SpanKind.italic => const TextStyle(fontStyle: FontStyle.italic),
          SpanKind.code => TextStyle(
            fontFamily: 'monospace',
            color: widget.linkColor,
          ),
          SpanKind.strike => const TextStyle(
            decoration: TextDecoration.lineThrough,
          ),
          SpanKind.underline => const TextStyle(
            decoration: TextDecoration.underline,
          ),
          SpanKind.spoiler ||
          SpanKind.pre ||
          SpanKind.quote => const TextStyle(),
          _ => TextStyle(color: widget.linkColor),
        });
        if (s.kind.isLink && tap == null) {
          tap = TapGestureRecognizer()..onTap = () => _tap(s);
          _recognizers.add(tap);
        }
      }
      if (hidden != null) {
        final h = hidden;
        final reveal = TapGestureRecognizer()
          ..onTap = () => setState(() => _revealed.add(h.offset));
        _recognizers.add(reveal);
        style = style.copyWith(
          color: Colors.transparent,
          background: Paint()..color = spoilerBg.withValues(alpha: 0.35),
        );
        tap = reveal;
      }
      children.add(
        TextSpan(text: text.substring(a, b), style: style, recognizer: tap),
      );
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final text = widget.text;
    final spans = widget.spans
        .where((s) => s.offset >= 0 && s.end <= text.length)
        .toList();
    if (spans.isEmpty) return Text(text, style: widget.style);

    final blocks = spans.where((s) => s.kind.isBlock).toList()
      ..sort((a, b) => a.offset.compareTo(b.offset));
    if (blocks.isEmpty) {
      return Text.rich(
        TextSpan(style: widget.style, children: _inline(0, text.length, spans)),
      );
    }

    final parts = <Widget>[];
    var pos = 0;
    void plain(int a, int b) {
      var from = a;
      var to = b;
      while (from < to && text[from] == '\n') {
        from++;
      }
      while (to > from && text[to - 1] == '\n') {
        to--;
      }
      if (from >= to) return;
      parts.add(
        Text.rich(
          TextSpan(style: widget.style, children: _inline(from, to, spans)),
        ),
      );
    }

    for (final b in blocks) {
      if (b.offset < pos) continue;
      plain(pos, b.offset);
      parts.add(_block(b, spans));
      pos = b.end;
    }
    plain(pos, text.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: parts,
    );
  }

  Widget _block(TextSpanInfo b, List<TextSpanInfo> spans) {
    final accent = widget.linkColor;
    final body = Text.rich(
      TextSpan(
        style: b.kind == SpanKind.pre
            ? widget.style.copyWith(fontFamily: 'monospace', fontSize: 13.5)
            : widget.style,
        children: _inline(b.offset, b.end, spans),
      ),
      maxLines: b.kind == SpanKind.quote && !_expanded.contains(b.offset)
          ? 12
          : null,
      overflow: TextOverflow.fade,
    );
    if (b.kind == SpanKind.pre) {
      return GestureDetector(
        onLongPress: () => unawaited(
          Clipboard.setData(
            ClipboardData(text: widget.text.substring(b.offset, b.end)),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (b.language.isNotEmpty)
                Text(
                  b.language,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: body,
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => setState(() {
        if (!_expanded.remove(b.offset)) _expanded.add(b.offset);
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(8, 3, 22, 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Stack(
          children: [
            body,
            Positioned(
              right: -18,
              top: 0,
              child: Icon(Icons.format_quote, size: 14, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({
    super.key,
    required this.preview,
    required this.accent,
    required this.textColor,
    required this.maxWidth,
  });

  final LinkPreviewData preview;
  final Color accent;
  final Color textColor;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final photo = preview.photo;
    return GestureDetector(
      onTap: () => unawaited(openLink(preview.url)),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (preview.siteName.isNotEmpty)
              Text(
                preview.siteName,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            if (preview.title.isNotEmpty)
              Text(
                preview.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            if (preview.description.isNotEmpty)
              Text(
                preview.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontSize: 13),
              ),
            if (photo != null && photo.fileId != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AspectRatio(
                  aspectRatio: photo.aspect.clamp(0.8, 2.2),
                  child: TdImage(photo),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
