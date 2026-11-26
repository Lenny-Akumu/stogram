import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/l10n/l10n.dart';
import '../../core/tdlib/td_error.dart';
import '../../data/messages/chat_message.dart';
import '../../data/messages/message_media.dart';
import '../../data/messages/messages_repository.dart';
import '../../data/messages/reply_markup.dart';
import '../../ui/components/rich_message_text.dart';
import '../../ui/theme/chat_colors.dart';

/// Sent / read marks drawn as two sharp strokes.
class MessageTicks extends StatelessWidget {
  const MessageTicks({super.key, required this.read, required this.color});

  final bool read;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(19, 11),
    painter: _TicksPainter(read: read, color: color),
  );
}

class _TicksPainter extends CustomPainter {
  _TicksPainter({required this.read, required this.color});

  final bool read;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Path tick(double x) => Path()
      ..moveTo(x, h * 0.55)
      ..lineTo(x + 3.6, h - 1)
      ..lineTo(x + 11, 1.2);
    if (!read) {
      canvas.drawPath(tick(3), paint);
      return;
    }
    canvas.drawPath(tick(0.8), paint);
    final second = Path()
      ..moveTo(6.8, h - 2.2)
      ..lineTo(7.8, h - 1)
      ..lineTo(15.2, 1.2);
    canvas.drawPath(second, paint);
    canvas.drawCircle(
      Offset(size.width - 1.2, 1.4),
      1.1,
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_TicksPainter old) =>
      old.read != read || old.color != color;
}

Future<void> openChatById(BuildContext context, WidgetRef ref, int id) async {
  ref.read(selectedChatProvider.notifier).select(id);
  context.go(Routes.chat(id));
}

Future<void> openUserChat(BuildContext context, WidgetRef ref, int uid) async {
  try {
    final chat = await ref.read(tdApiProvider).send({
      '@type': 'createPrivateChat',
      'user_id': uid,
      'force': false,
    });
    if (context.mounted) await openChatById(context, ref, chat['id'] as int);
  } on TdError catch (e) {
    if (context.mounted) _snack(context, e.message);
  }
}

Future<bool> openUsername(
  BuildContext context,
  WidgetRef ref,
  String username,
) async {
  try {
    final chat = await ref.read(tdApiProvider).send({
      '@type': 'searchPublicChat',
      'username': username.replaceFirst('@', ''),
    });
    if (context.mounted) await openChatById(context, ref, chat['id'] as int);
    return true;
  } on TdError {
    return false;
  }
}

/// t.me/username links open in-app, everything else goes outside.
Future<void> openSmartLink(
  BuildContext context,
  WidgetRef ref,
  String url,
) async {
  final uri = Uri.tryParse(url.contains('://') ? url : 'https://$url');
  final seg = uri?.pathSegments ?? const [];
  if (uri != null &&
      (uri.host == 't.me' || uri.host == 'telegram.me') &&
      seg.length == 1 &&
      RegExp(r'^[A-Za-z]\w{3,}$').hasMatch(seg.first)) {
    if (await openUsername(context, ref, seg.first)) return;
  }
  await openLink(url);
}

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class InlineKeyboardView extends ConsumerWidget {
  const InlineKeyboardView({
    super.key,
    required this.keyboard,
    required this.message,
    required this.repo,
    required this.maxWidth,
    required this.onSwitchInline,
  });

  final InlineKeyboard keyboard;
  final ChatMessage message;
  final MessagesRepository repo;
  final double maxWidth;
  final ValueChanged<String> onSwitchInline;

  Future<void> _press(
    BuildContext context,
    WidgetRef ref,
    MarkupButton b,
  ) async {
    switch (b.kind) {
      case ButtonKind.url || ButtonKind.loginUrl || ButtonKind.webApp:
        await openSmartLink(context, ref, b.url);
      case ButtonKind.callback || ButtonKind.game:
        try {
          final a = await repo.pressCallback(message.id, b);
          if (!context.mounted) return;
          if (a.url.isNotEmpty) await openSmartLink(context, ref, a.url);
          if (!context.mounted || a.text.isEmpty) return;
          if (a.alert) {
            await showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                content: Text(a.text),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } else {
            _snack(context, a.text);
          }
        } on TdError catch (e) {
          if (context.mounted && e.code != 0) _snack(context, e.message);
        }
      case ButtonKind.switchInline:
        onSwitchInline(b.query);
      case ButtonKind.user:
        if (b.userId != null) await openUserChat(context, ref, b.userId!);
      case ButtonKind.copy:
        await Clipboard.setData(ClipboardData(text: b.query));
        if (context.mounted) _snack(context, context.l10n.copied);
      default:
        _snack(context, context.l10n.botButtonUnsupported);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ChatColors.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in keyboard.rows)
            Row(
              children: [
                for (final b in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(1.5),
                      child: Material(
                        color: colors.bubbleIn.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: b.kind == ButtonKind.disabled
                              ? null
                              : () => unawaited(_press(context, ref, b)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 9,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    b.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colors.textIn,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                if (_corner(b.kind) case final icon?)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Icon(
                                      icon,
                                      size: 12,
                                      color: colors.secondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static IconData? _corner(ButtonKind k) => switch (k) {
    ButtonKind.url || ButtonKind.loginUrl => Icons.north_east,
    ButtonKind.webApp => Icons.open_in_new,
    ButtonKind.switchInline => Icons.reply,
    ButtonKind.copy => Icons.copy,
    _ => null,
  };
}

class ReplyKeyboardView extends StatelessWidget {
  const ReplyKeyboardView({
    super.key,
    required this.keyboard,
    required this.onPress,
  });

  final ReplyKeyboard keyboard;
  final ValueChanged<MarkupButton> onPress;

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    final h = MediaQuery.sizeOf(context).height;
    return Container(
      color: colors.panel,
      constraints: BoxConstraints(maxHeight: math.min(280, h * 0.4)),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final row in keyboard.rows)
              Row(
                children: [
                  for (final b in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2.5),
                        child: Material(
                          color: colors.bubbleIn,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => onPress(b),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: keyboard.resize ? 10 : 14,
                              ),
                              child: Text(
                                b.text,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: colors.textIn),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class CommandsList extends StatelessWidget {
  const CommandsList({super.key, required this.commands, required this.onPick});

  final List<BotCommand> commands;
  final ValueChanged<BotCommand> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    return Material(
      color: colors.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            for (final c in commands)
              ListTile(
                dense: true,
                title: Text(
                  '/${c.command}',
                  style: TextStyle(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: c.description.isEmpty
                    ? null
                    : Text(
                        c.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.secondary),
                      ),
                onTap: () => onPick(c),
              ),
          ],
        ),
      ),
    );
  }
}

String serviceText(
  BuildContext context,
  WidgetRef ref,
  ChatMessage m,
  ServiceMedia s,
) {
  final l10n = context.l10n;
  final users = ref.read(usersRepositoryProvider);
  final who = m.senderUserId == null ? '' : users.nameOf(m.senderUserId!) ?? '';
  String names(List<int> ids) => ids
      .map((id) => users.nameOf(id) ?? '')
      .where((n) => n.isNotEmpty)
      .join(', ');
  return switch (s.kind) {
    ServiceKind.created => l10n.svcCreated(who, s.text),
    ServiceKind.title => l10n.svcTitle(who, s.text),
    ServiceKind.photo => l10n.svcPhoto(who),
    ServiceKind.photoRemoved => l10n.svcPhotoRemoved(who),
    ServiceKind.joined || ServiceKind.joinedByLink => l10n.svcJoined(who),
    ServiceKind.added =>
      s.users.length == 1 && s.users.first == m.senderUserId
          ? l10n.svcJoined(who)
          : l10n.svcAdded(who, names(s.users)),
    ServiceKind.removed =>
      s.users.first == m.senderUserId
          ? l10n.svcLeft(who)
          : l10n.svcRemoved(who, names(s.users)),
    ServiceKind.pinned => l10n.svcPinned(who),
    ServiceKind.screenshot => l10n.svcScreenshot(who),
    ServiceKind.upgraded => l10n.svcUpgraded,
    ServiceKind.autoDelete =>
      s.seconds == 0 ? l10n.svcAutoDeleteOff : l10n.svcAutoDelete(who),
    ServiceKind.contactJoined => l10n.svcContactJoined(who),
    ServiceKind.call =>
      s.seconds > 0 ? l10n.svcCall(formatCall(s.seconds)) : l10n.svcCallMissed,
    ServiceKind.custom => s.text,
  };
}

String formatCall(int s) {
  final m = s ~/ 60;
  final r = s % 60;
  return m > 0
      ? '$m:${r.toString().padLeft(2, '0')}'
      : '0:${r.toString().padLeft(2, '0')}';
}

/// Wraps the selection in markdown markers, or inserts an empty pair.
void wrapSelection(TextEditingController c, String open, [String? close]) {
  final end = close ?? open;
  final sel = c.selection;
  final text = c.text;
  final a = sel.isValid ? sel.start : text.length;
  final b = sel.isValid ? sel.end : text.length;
  final inner = text.substring(a, b);
  c.value = TextEditingValue(
    text: text.replaceRange(a, b, '$open$inner$end'),
    selection: inner.isEmpty
        ? TextSelection.collapsed(offset: a + open.length)
        : TextSelection(
            baseOffset: a + open.length,
            extentOffset: a + open.length + inner.length,
          ),
  );
}

Future<void> insertLink(BuildContext context, TextEditingController c) async {
  final sel = c.selection;
  final url = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(context.l10n.fmtLink),
      content: TextField(
        controller: url,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'https://'),
        onSubmitted: (_) => Navigator.pop(d, true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: Text(context.l10n.actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(d, true),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  final link = url.text.trim();
  url.dispose();
  if (ok != true || link.isEmpty) return;
  c.selection = sel;
  wrapSelection(c, '[', ']($link)');
}
