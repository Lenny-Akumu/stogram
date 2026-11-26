import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/messages/rich_text.dart';
import 'td_image.dart';

Future<void> openLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Message text with tappable links and Telegram's inline styles.
class RichMessageText extends StatefulWidget {
  const RichMessageText({
    super.key,
    required this.text,
    required this.spans,
    required this.style,
    required this.linkColor,
  });

  final String text;
  final List<TextSpanInfo> spans;
  final TextStyle style;
  final Color linkColor;

  @override
  State<RichMessageText> createState() => _RichMessageTextState();
}

class _RichMessageTextState extends State<RichMessageText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  bool _isLink(SpanKind k) => switch (k) {
    SpanKind.url ||
    SpanKind.textUrl ||
    SpanKind.email ||
    SpanKind.mention => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final text = widget.text;
    final spans = widget.spans
        .where((s) => s.offset >= 0 && s.offset + s.length <= text.length)
        .toList();
    if (spans.isEmpty) return Text(text, style: widget.style);

    final cuts = <int>{0, text.length};
    for (final s in spans) {
      cuts
        ..add(s.offset)
        ..add(s.offset + s.length);
    }
    final points = cuts.toList()..sort();
    final children = <InlineSpan>[];
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (a == b) continue;
      final active = spans.where(
        (s) => s.offset <= a && s.offset + s.length >= b,
      );
      var style = const TextStyle();
      TapGestureRecognizer? tap;
      for (final s in active) {
        style = style.merge(switch (s.kind) {
          SpanKind.bold => const TextStyle(fontWeight: FontWeight.w700),
          SpanKind.italic => const TextStyle(fontStyle: FontStyle.italic),
          SpanKind.code => const TextStyle(fontFamily: 'monospace'),
          SpanKind.strike => const TextStyle(
            decoration: TextDecoration.lineThrough,
          ),
          SpanKind.underline => const TextStyle(
            decoration: TextDecoration.underline,
          ),
          _ => TextStyle(color: widget.linkColor),
        });
        if (_isLink(s.kind) && tap == null) {
          final target = spanTarget(text, s);
          tap = TapGestureRecognizer()
            ..onTap = () => unawaited(openLink(target));
          _recognizers.add(tap);
        }
      }
      children.add(
        TextSpan(text: text.substring(a, b), style: style, recognizer: tap),
      );
    }
    return Text.rich(TextSpan(style: widget.style, children: children));
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
