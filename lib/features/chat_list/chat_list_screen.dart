import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/l10n.dart';
import '../../core/util/chat_date.dart';
import '../../data/chats/chat_summary.dart';
import '../../ui/components/audio_bar.dart';
import '../../ui/components/avatar.dart';
import '../../ui/components/preview_text.dart';
import '../../ui/components/presence_text.dart';
import '../../ui/theme/chat_colors.dart';
import 'app_drawer.dart';
import 'chat_list_extras.dart';

class ChatListPane extends ConsumerStatefulWidget {
  const ChatListPane({super.key, required this.onOpen, this.selectedId});

  final void Function(int chatId) onOpen;
  final int? selectedId;

  @override
  ConsumerState<ChatListPane> createState() => _ChatListPaneState();
}

class _ChatListPaneState extends ConsumerState<ChatListPane> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  String _query = '';
  String _list = 'main';

  void _pick(String key) {
    setState(() => _list = key);
    unawaited(_loadMore());
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    final pos = _scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 600) unawaited(_loadMore());
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(chatsRepositoryProvider).loadMore(list: _list);
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.chatsLoadError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    final all = ref.watch(chatListProvider(_list));
    ref.watch(usersChangedProvider);
    final q = _query.trim().toLowerCase();
    final chats = q.isEmpty
        ? all
        : all.where((c) => c.title.toLowerCase().contains(q)).toList();
    final repo = ref.watch(chatsRepositoryProvider);
    final allLoaded = repo.loadedAll(_list);
    final showArchive = _list == 'main' && q.isEmpty;

    return Scaffold(
      backgroundColor: colors.panel,
      drawer: const AppDrawer(),
      appBar: AppBar(
        titleSpacing: 0,
        leading: _list == 'archive'
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _pick('main'),
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        title: SizedBox(
          height: 38,
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: colors.chatBackground,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        actions: const [SizedBox(width: 12)],
      ),
      body: Column(
        children: [
          const AudioBar(),
          if (_list != 'archive')
            FolderTabs(current: _list, onPick: _pick)
          else
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l10n.archiveTitle,
                style: TextStyle(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: chats.isEmpty && !showArchive
                ? Center(
                    child: allLoaded || q.isNotEmpty
                        ? Text(l10n.chatsEmpty)
                        : const CircularProgressIndicator(),
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemCount: chats.length + (showArchive ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (showArchive && i == 0) {
                        return ArchiveRow(onTap: () => _pick('archive'));
                      }
                      final c = chats[i - (showArchive ? 1 : 0)];
                      return SizedBox(
                        height: 72,
                        child: ChatTile(
                          chat: c,
                          selected: c.id == widget.selectedId,
                          onTap: () => widget.onOpen(c.id),
                          onMenu: () => unawaited(
                            showChatActions(context, ref, c, _list),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ChatTile extends ConsumerWidget {
  const ChatTile({
    super.key,
    required this.chat,
    required this.onTap,
    this.selected = false,
    this.onMenu,
  });

  final ChatSummary chat;
  final VoidCallback onTap;
  final bool selected;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    final users = ref.read(usersRepositoryProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = chat.date;
    final fg = selected ? Colors.white : colors.textIn;
    final sub = selected ? Colors.white70 : colors.secondary;
    final typing = typingText(
      l10n,
      users.typingIn(chat.id),
      users,
      group: chat.peer.userId == null,
    );
    final online =
        chat.peer.userId != null &&
        users.user(chat.peer.userId!)?.presence is Online;

    return Material(
      color: selected ? colors.selected : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onMenu,
        onSecondaryTap: onMenu,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Stack(
                children: [
                  Avatar(
                    id: chat.id,
                    title: chat.title,
                    photo: chat.photo,
                    size: 54,
                  ),
                  if (online)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4DCD5E),
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.panel, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (chat.peer.isChannel || chat.isGroup)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              chat.peer.isChannel
                                  ? Icons.campaign
                                  : Icons.group,
                              size: 16,
                              color: fg,
                            ),
                          ),
                        Flexible(
                          child: Text(
                            chat.title.isEmpty ? l10n.chatUntitled : chat.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (chat.isMuted)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.volume_off, size: 14, color: sub),
                          ),
                        const Spacer(),
                        if (date != null)
                          Text(
                            formatChatDate(date, DateTime.now(), locale),
                            style: TextStyle(color: sub, fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            typing.isNotEmpty
                                ? typing
                                : previewText(context, chat.preview),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: typing.isNotEmpty && !selected
                                  ? colors.accent
                                  : sub,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (chat.unreadMentions > 0)
                          _Badge(
                            count: -1,
                            color: selected ? Colors.white : colors.accent,
                            textColor: selected
                                ? colors.selected
                                : Colors.white,
                          ),
                        if (chat.unreadCount > 0 || chat.markedUnread)
                          _Badge(
                            count: chat.unreadCount,
                            color: selected
                                ? Colors.white
                                : chat.isMuted
                                ? colors.secondary
                                : colors.unread,
                            textColor: selected
                                ? colors.selected
                                : Colors.white,
                          )
                        else if (chat.isPinned)
                          Icon(Icons.push_pin, size: 16, color: sub),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.count,
    required this.color,
    required this.textColor,
  });

  final int count;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count < 0
            ? '@'
            : count == 0
            ? ''
            : count > 9999
            ? '9999+'
            : '$count',
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
