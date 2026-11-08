import 'package:flutter/widgets.dart';

import '../../core/l10n/l10n.dart';
import '../../data/chats/chat_summary.dart';

String previewText(BuildContext context, MessagePreview? preview) {
  if (preview == null) return '';
  final l10n = context.l10n;
  final label = switch (preview.kind) {
    PreviewKind.text => null,
    PreviewKind.photo => l10n.previewPhoto,
    PreviewKind.video => l10n.previewVideo,
    PreviewKind.voice => l10n.previewVoice,
    PreviewKind.videoNote => l10n.previewVideoNote,
    PreviewKind.sticker => l10n.previewSticker,
    PreviewKind.gif => l10n.previewGif,
    PreviewKind.audio => l10n.previewAudio,
    PreviewKind.document => l10n.previewDocument,
    PreviewKind.location => l10n.previewLocation,
    PreviewKind.contact => l10n.previewContact,
    PreviewKind.poll => l10n.previewPoll,
    PreviewKind.other => l10n.previewOther,
  };
  final text = preview.text.replaceAll('\n', ' ');
  if (label == null) return text;
  return text.isEmpty ? label : '$label: $text';
}
