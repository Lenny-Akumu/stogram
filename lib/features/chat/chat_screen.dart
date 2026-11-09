import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/l10n/l10n.dart';
import '../../core/tdlib/td_error.dart';
import '../../data/chats/chat_summary.dart';
import '../../data/messages/chat_message.dart';
import '../../data/messages/message_media.dart';
import '../../data/messages/messages_repository.dart';
import '../../ui/components/avatar.dart';
import '../../ui/components/presence_text.dart';
import '../../ui/components/preview_text.dart';
import '../../ui/theme/chat_colors.dart';
import 'media_view.dart';

enum _Mode { send, reply, edit }

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId, this.embedded = false});

  final int chatId;
  final bool embedded;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  late final ProviderSubscription<MessagesRepository> _keep;
  late final MessagesRepository _repo;
  int? _lastSeenId;
  _Mode _mode = _Mode.send;
  ChatMessage? _target;
  bool _showDown = false;

  @override
  void initState() {
    super.initState();
    _keep = ref.listenManual(
      messagesRepositoryProvider(widget.chatId),
      (_, _) {},
    );
    _repo = _keep.read();
    _scroll.addListener(_onScroll);
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      await _repo.open();
      await _repo.markRead();
    } on TdError {
      // history stays empty, header still usable
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(_repo.close().catchError((Object _) {}));
    _keep.close();
    _scroll.dispose();
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 800) {
      unawaited(
        _repo.loadOlder().then((_) {
          if (mounted) setState(() {});
        }),
      );
    }
    final down = pos.pixels > 400;
    if (down != _showDown) setState(() => _showDown = down);
  }

  void _scrollDown() => unawaited(
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    ),
  );

  void _onMessages(List<ChatMessage> list) {
    final newest = list.isEmpty ? null : list.first;
    if (newest == null || newest.id == _lastSeenId) return;
    _lastSeenId = newest.id;
    if (!newest.isOutgoing) unawaited(_repo.markRead());
  }

  void _setMode(_Mode mode, [ChatMessage? target]) {
    setState(() {
      _mode = mode;
      _target = target;
    });
    if (mode == _Mode.edit && target != null) {
      _input.text = target.content.text;
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    } else if (mode == _Mode.send) {
      _input.clear();
    }
    if (mode != _Mode.send) _inputFocus.requestFocus();
  }

  Future<void> _submit() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final mode = _mode;
    final target = _target;
    _setMode(_Mode.send);
    try {
      switch (mode) {
        case _Mode.send:
          await _repo.sendText(text);
        case _Mode.reply:
          await _repo.sendText(text, replyTo: target?.id);
        case _Mode.edit:
          if (target != null) await _repo.editText(target.id, text);
      }
      if (_scroll.hasClients && _scroll.offset > 0) _scrollDown();
    } on TdError catch (e) {
      if (!mounted) return;
      _input.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatSendError(e.message))),
      );
    }
  }

  Future<void> _showActions(ChatMessage m) async {
    final l10n = context.l10n;
    final actions = await _repo.actions(m.id);
    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (actions.canReply)
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text(l10n.actionReply),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
            if (actions.canCopy && m.content.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text(l10n.actionCopy),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            if (actions.canEdit)
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(l10n.actionEdit),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            if (actions.canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.actionDelete),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'reply':
        _setMode(_Mode.reply, m);
      case 'edit':
        _setMode(_Mode.edit, m);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.content.text));
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.copied)));
      case 'delete':
        await _confirmDelete(m, actions);
    }
  }

  Future<void> _confirmDelete(ChatMessage m, MessageActions actions) async {
    final l10n = context.l10n;
    var revoke = actions.canDeleteForAll;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(l10n.deleteTitle),
          content: actions.canDeleteForAll && actions.canDeleteForSelf
              ? CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: revoke,
                  onChanged: (v) => setLocal(() => revoke = v ?? false),
                  title: Text(l10n.deleteForEveryone),
                )
              : null,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.actionDelete),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete([m.id], revoke: revoke);
    } on TdError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(messagesProvider(widget.chatId), (_, next) {
      final v = next.value;
      if (v != null) _onMessages(v);
    });
    ref.watch(usersChangedProvider);
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    final chats = ref.watch(chatsProvider).value ?? const <ChatSummary>[];
    final chat = chats.where((c) => c.id == widget.chatId).firstOrNull;
    final messages = ref.watch(messagesProvider(widget.chatId)).value ?? [];
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final isGroup = chat?.isGroup ?? false;

    return Scaffold(
      backgroundColor: colors.chatBackground,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        titleSpacing: widget.embedded ? 16 : 0,
        title: _Header(chat: chat),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (messages.isEmpty)
                  Center(
                    child: _repo.reachedStart
                        ? _Pill(text: l10n.chatHistoryEmpty)
                        : const CircularProgressIndicator(),
                  )
                else
                  ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final older = i + 1 < messages.length
                          ? messages[i + 1]
                          : null;
                      final newer = i > 0 ? messages[i - 1] : null;
                      final newDay =
                          older == null || !_sameDay(older.date, m.date);
                      final firstInGroup =
                          newDay ||
                          older.isOutgoing != m.isOutgoing ||
                          older.senderUserId != m.senderUserId;
                      final lastInGroup =
                          newer == null ||
                          !_sameDay(newer.date, m.date) ||
                          newer.isOutgoing != m.isOutgoing ||
                          newer.senderUserId != m.senderUserId;
                      final bubble = _Bubble(
                        message: m,
                        showSender: isGroup && !m.isOutgoing && firstInGroup,
                        showAvatar: isGroup && !m.isOutgoing,
                        tail: lastInGroup,
                        replied: _repo.repliedTo(m),
                        isRead: _repo.isRead(m),
                        onActions: () => _showActions(m),
                      );
                      if (!newDay) return bubble;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: _Pill(
                              text: dayLabel(l10n, m.date, now, locale),
                            ),
                          ),
                          bubble,
                        ],
                      );
                    },
                  ),
                Positioned(
                  right: 16,
                  bottom: 12,
                  child: AnimatedScale(
                    scale: _showDown ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: FloatingActionButton.small(
                      heroTag: null,
                      tooltip: l10n.scrollDown,
                      backgroundColor: colors.panel,
                      foregroundColor: colors.secondary,
                      onPressed: _scrollDown,
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_mode != _Mode.send && _target != null)
            _ModeBanner(
              icon: _mode == _Mode.reply ? Icons.reply : Icons.edit,
              title: _mode == _Mode.reply ? l10n.actionReply : l10n.editing,
              text: previewText(context, _target!.content),
              onClose: () => _setMode(_Mode.send),
            ),
          _Composer(
            controller: _input,
            focusNode: _inputFocus,
            onSend: _submit,
            editing: _mode == _Mode.edit,
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Header extends ConsumerWidget {
  const _Header({required this.chat});

  final ChatSummary? chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = chat;
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    if (c == null) return const SizedBox.shrink();
    final users = ref.read(usersRepositoryProvider);
    final sub = chatSubtitle(
      l10n,
      c,
      users,
      DateTime.now(),
      Localizations.localeOf(context).toLanguageTag(),
    );
    final active =
        users.typingIn(c.id).isNotEmpty ||
        (c.peer.userId != null &&
            users.user(c.peer.userId!)?.presence is Online);
    return Row(
      children: [
        Avatar(id: c.id, title: c.title, photo: c.photo, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.title.isEmpty ? l10n.chatUntitled : c.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (sub.isNotEmpty)
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: active ? colors.accent : colors.secondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({
    required this.message,
    required this.showSender,
    required this.showAvatar,
    required this.tail,
    required this.onActions,
    this.replied,
    this.isRead = false,
  });

  final ChatMessage message;
  final bool showSender;
  final bool showAvatar;
  final bool tail;
  final ChatMessage? replied;
  final bool isRead;
  final VoidCallback onActions;

  static const _senderColors = [
    Color(0xFFE17076),
    Color(0xFF7BC862),
    Color(0xFFE5CA77),
    Color(0xFF65AADD),
    Color(0xFFA695E7),
    Color(0xFFEE7AAE),
    Color(0xFF6EC9CB),
    Color(0xFFFAA774),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ChatColors.of(context);
    final out = message.isOutgoing;
    final fg = out ? colors.textOut : colors.textIn;
    final metaColor = out ? colors.metaOut : colors.metaIn;
    final meta = TextStyle(fontSize: 12, color: metaColor);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final users = ref.read(usersRepositoryProvider);
    final senderId = message.senderUserId;
    final sender = senderId == null ? null : users.user(senderId);
    final senderColor =
        _senderColors[(senderId ?? 0).abs() % _senderColors.length];
    final reply = replied;
    final media = message.media;
    final sticker = media is StickerMedia;
    final roundVideo = media is VideoMedia && media.isRound;
    final bare = sticker || roundVideo;
    final text = media == null
        ? previewText(context, message.content)
        : message.content.text;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;

    const r = Radius.circular(16);
    const small = Radius.circular(4);
    final radius = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: !out && tail ? small : r,
      bottomRight: out && tail ? small : r,
    );

    final footer = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isEdited)
          Text('${context.l10n.messageEdited} ', style: meta),
        Text(DateFormat.Hm(locale).format(message.date), style: meta),
        if (out) ...[
          const SizedBox(width: 3),
          switch (message.sendState) {
            SendState.pending => Icon(
              Icons.schedule,
              size: 13,
              color: metaColor,
            ),
            SendState.failed => Tooltip(
              message: context.l10n.messageSendFailed,
              child: Icon(Icons.error_outline, size: 13, color: colors.deleted),
            ),
            SendState.sent => Icon(
              isRead ? Icons.done_all : Icons.done,
              size: 15,
              color: metaColor,
            ),
          },
        ],
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSender && sender != null && sender.name.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              sender.name,
              style: TextStyle(
                color: senderColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        if (reply != null)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
            decoration: BoxDecoration(
              color: (out ? Colors.white : colors.accent).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(4),
              border: Border(
                left: BorderSide(color: out ? fg : colors.accent, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reply.senderUserId != null)
                  Text(
                    users.nameOf(reply.senderUserId!) ?? '',
                    maxLines: 1,
                    style: TextStyle(
                      color: out ? fg : colors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                Text(
                  previewText(context, reply.content),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 13),
                ),
              ],
            ),
          ),
        if (media != null)
          Padding(
            padding: EdgeInsets.only(bottom: text.isEmpty ? 0 : 4),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: fg),
              child: IconTheme.merge(
                data: IconThemeData(color: fg),
                child: MediaView(media: media, maxWidth: maxWidth - 16),
              ),
            ),
          ),
        if (text.isNotEmpty)
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(
                text,
                style: TextStyle(color: fg, fontSize: 15, height: 1.3),
              ),
              footer,
            ],
          )
        else
          Align(alignment: Alignment.bottomRight, child: footer),
      ],
    );

    final bubble = GestureDetector(
      onLongPress: onActions,
      onSecondaryTap: onActions,
      child: Container(
        margin: EdgeInsets.only(top: 1, bottom: tail ? 6 : 1),
        padding: bare
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: bare
            ? null
            : BoxDecoration(
                color: out ? colors.bubbleOut : colors.bubbleIn,
                borderRadius: radius,
              ),
        child: content,
      ),
    );

    return Row(
      mainAxisAlignment: out ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showAvatar)
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: tail && sender != null
                ? Avatar(
                    id: sender.id,
                    title: sender.name,
                    photo: sender.photo,
                    size: 34,
                  )
                : const SizedBox(width: 34),
          ),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: bubble,
        ),
      ],
    );
  }
}

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({
    required this.icon,
    required this.title,
    required this.text,
    required this.onClose,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    return Container(
      color: colors.panel,
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colors.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: colors.accent, width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.actionCancel,
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

bool get _isDesktop => switch (defaultTargetPlatform) {
  TargetPlatform.linux ||
  TargetPlatform.windows ||
  TargetPlatform.macOS => true,
  _ => false,
};

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.editing = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function() onSend;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    return Material(
      color: colors.panel,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CallbackShortcuts(
                  bindings: {
                    if (_isDesktop)
                      const SingleActivator(LogicalKeyboardKey.enter): onSend,
                  },
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 8,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: context.l10n.composerHint,
                      hintStyle: TextStyle(color: colors.secondary),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: editing
                    ? context.l10n.actionSave
                    : context.l10n.actionSend,
                color: colors.accent,
                onPressed: onSend,
                icon: Icon(editing ? Icons.check_circle : Icons.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
