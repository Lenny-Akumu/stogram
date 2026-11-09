import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/l10n/l10n.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat_list/chat_list_screen.dart';
import '../theme/chat_colors.dart';

/// List + chat side by side on wide screens, one at a time on phones.
class ClassicShell extends StatelessWidget {
  const ClassicShell({super.key, this.chatId});

  final int? chatId;

  static const breakpoint = 760.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= breakpoint;
        final id = chatId;
        if (!wide) {
          return id == null
              ? ChatListPane(onOpen: (c) => context.push(Routes.chat(c)))
              : ChatScreen(key: ValueKey(id), chatId: id);
        }
        final listWidth = (box.maxWidth * 0.32).clamp(300.0, 420.0);
        return Row(
          children: [
            SizedBox(
              width: listWidth,
              child: ChatListPane(
                selectedId: id,
                onOpen: (c) => context.go(Routes.chat(c)),
              ),
            ),
            VerticalDivider(width: 1, color: ChatColors.of(context).divider),
            Expanded(
              child: id == null
                  ? const _EmptyChat()
                  : ChatScreen(key: ValueKey(id), chatId: id, embedded: true),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    return ColoredBox(
      color: colors.chatBackground,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            context.l10n.selectChat,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
