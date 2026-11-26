import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/l10n.dart';
import '../../core/tdlib/td_error.dart';
import '../../data/chats/chat_summary.dart';
import '../../data/chats/chats_repository.dart';
import '../../ui/theme/chat_colors.dart';

/// Chats of the given list, refreshed on every repository change.
final chatListProvider = Provider.autoDispose.family<List<ChatSummary>, String>(
  (ref, key) {
    ref.watch(chatsProvider);
    return ref.read(chatsRepositoryProvider).listFor(key);
  },
);

Future<void> showChatActions(
  BuildContext context,
  WidgetRef ref,
  ChatSummary chat,
  String list,
) async {
  final l10n = context.l10n;
  final repo = ref.read(chatsRepositoryProvider);
  final unread = chat.unreadCount > 0 || chat.markedUnread;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (id, icon, label) in [
            (
              'pin',
              chat.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              chat.isPinned ? l10n.actionUnpin : l10n.actionPin,
            ),
            (
              'mute',
              chat.isMuted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              chat.isMuted ? l10n.chatUnmute : l10n.chatMute,
            ),
            (
              'read',
              unread ? Icons.mark_chat_read_outlined : Icons.mark_chat_unread,
              unread ? l10n.chatMarkRead : l10n.chatMarkUnread,
            ),
            (
              'archive',
              chat.isArchived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              chat.isArchived ? l10n.chatUnarchive : l10n.chatArchive,
            ),
            (
              'delete',
              Icons.delete_outline,
              chat.isGroup || chat.peer.isChannel
                  ? l10n.chatLeave
                  : l10n.chatDelete,
            ),
          ])
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () => Navigator.pop(context, id),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'delete') {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(l10n.chatDeleteAsk(chat.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
  }
  try {
    await switch (choice) {
      'pin' => repo.togglePin(chat.id, list),
      'mute' => repo.setMuted(chat.id, !chat.isMuted),
      'read' => unread ? repo.markRead(chat.id) : repo.markUnread(chat.id),
      'archive' => repo.setArchived(chat.id, !chat.isArchived),
      _ => repo.deleteChat(chat.id, leave: chat.isGroup || chat.peer.isChannel),
    };
  } on TdError catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// "All" plus the user's folders; hidden when there are no folders.
class FolderTabs extends ConsumerWidget {
  const FolderTabs({super.key, required this.current, required this.onPick});

  final String current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(chatsProvider);
    final repo = ref.read(chatsRepositoryProvider);
    final folders = repo.folders;
    if (folders.isEmpty) return const SizedBox.shrink();
    final colors = ChatColors.of(context);
    final tabs = [
      ('main', context.l10n.folderAll),
      for (final f in folders) (f.key, f.name),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        children: [
          for (final (key, name) in tabs)
            InkWell(
              onTap: () => onPick(key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: key == current
                          ? colors.accent
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: key == current
                            ? colors.accent
                            : colors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (repo.unreadIn(key) case final n when n > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: key == current
                              ? colors.accent
                              : colors.secondary,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '$n',
                          style: TextStyle(
                            color: colors.panel,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ArchiveRow extends ConsumerWidget {
  const ArchiveRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = ref.watch(chatListProvider('archive'));
    if (archived.isEmpty) return const SizedBox.shrink();
    final colors = ChatColors.of(context);
    final unread = ref.read(chatsRepositoryProvider).unreadIn('archive');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: colors.secondary.withValues(alpha: 0.35),
              child: Icon(Icons.archive_outlined, color: colors.textIn),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.archiveTitle,
                    style: TextStyle(
                      color: colors.textIn,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    archived.map((c) => c.title).take(5).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.secondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.secondary,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '$unread',
                  style: TextStyle(
                    color: colors.panel,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String listTitle(BuildContext context, ChatsRepository repo, String key) =>
    key == 'archive'
    ? context.l10n.archiveTitle
    : repo.folders.where((f) => f.key == key).firstOrNull?.name ??
          context.l10n.folderAll;
