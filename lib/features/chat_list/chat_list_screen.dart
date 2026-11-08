import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/l10n.dart';
import '../../core/util/chat_date.dart';
import '../../data/chats/chat_summary.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    final pos = _scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 600) _loadMore();
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(chatsRepositoryProvider).loadMore();
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
    final chats = ref.watch(chatsProvider).value ?? const [];
    final allLoaded = ref.watch(chatsRepositoryProvider).allLoaded;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatsTitle),
        actions: [
          IconButton(
            tooltip: l10n.actionLogOut,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).logOut(),
          ),
        ],
      ),
      body: chats.isEmpty
          ? Center(
              child: allLoaded
                  ? Text(l10n.chatsEmpty)
                  : const CircularProgressIndicator(),
            )
          : ListView.builder(
              controller: _scroll,
              itemCount: chats.length,
              itemBuilder: (context, i) => _ChatTile(chat: chats[i]),
            ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat});

  final ChatSummary chat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = chat.date;

    return ListTile(
      title: Row(
        children: [
          if (chat.isPinned)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.push_pin, size: 14),
            ),
          Expanded(
            child: Text(
              chat.title.isEmpty ? context.l10n.chatUntitled : chat.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (date != null)
            Text(formatChatDate(date, DateTime.now(), locale), style: muted),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              previewText(context, chat.preview),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          ),
          if (chat.unreadCount > 0) _UnreadBadge(count: chat.unreadCount),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 999 ? '999+' : '$count',
        style: TextStyle(
          color: scheme.onError,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

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
