import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/l10n/l10n.dart';
import '../../core/notify/notifier.dart';
import '../../core/settings/app_prefs.dart';
import '../../core/tdlib/td_error.dart';
import '../../data/chats/chat_summary.dart';
import '../../data/messages/chat_message.dart';
import '../../data/messages/message_media.dart';
import '../../data/messages/messages_repository.dart';
import '../../data/messages/reply_markup.dart';
import '../../data/messages/rich_text.dart';
import '../../ui/components/avatar.dart';
import '../../ui/components/audio_bar.dart';
import '../../ui/components/presence_text.dart';
import '../../ui/components/preview_text.dart';
import '../../ui/components/rich_message_text.dart';
import '../../ui/theme/chat_colors.dart';
import '../../ui/theme/skin_provider.dart';
import 'chat_extras.dart';
import 'media_view.dart';
import 'poll_view.dart';

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
  bool _keyboardOpen = true;
  bool _commandsOpen = false;

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
      unawaited(ref.read(messageNotifierProvider).clear(widget.chatId));
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
      unawaited(
        _repo.markdownOf(target).then((md) {
          if (!mounted || _target != target) return;
          _input.text = md;
          _input.selection = TextSelection.collapsed(offset: md.length);
        }),
      );
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
    final reactions = await _repo.availableReactions(m.id);
    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reactions.isNotEmpty)
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final e in reactions)
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.pop(context, 'react:$e'),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(e, style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                  ],
                ),
              ),
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
            if (actions.canForward)
              ListTile(
                leading: const Icon(Icons.forward),
                title: Text(l10n.actionForward),
                onTap: () => Navigator.pop(context, 'forward'),
              ),
            if (actions.canPin)
              ListTile(
                leading: Icon(
                  m.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                ),
                title: Text(m.isPinned ? l10n.actionUnpin : l10n.actionPin),
                onTap: () => Navigator.pop(context, 'pin'),
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
      case 'pin':
        await _guard(() => _repo.pin(m.id, unpin: m.isPinned));
      case 'forward':
        await _forward(m);
      case final String r when r.startsWith('react:'):
        await _guard(() => _repo.toggleReaction(m, r.substring(6)));
    }
  }

  Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } on TdError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _forward(ChatMessage m) async {
    final chats = ref.read(chatsProvider).value ?? const <ChatSummary>[];
    final to = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scroll) => ListView(
          controller: scroll,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                context.l10n.forwardTo,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final c in chats)
              ListTile(
                leading: Avatar(
                  id: c.id,
                  title: c.title,
                  photo: c.photo,
                  size: 40,
                ),
                title: Text(c.title, maxLines: 1),
                onTap: () => Navigator.pop(context, c.id),
              ),
          ],
        ),
      ),
    );
    if (to == null) return;
    await _guard(() => _repo.forward(to, [m.id]));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.forwarded)));
    }
  }

  Future<void> _attach() async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(l10n.attachFile),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.poll_outlined),
              title: Text(l10n.pollNew),
              onTap: () => Navigator.pop(context, 'poll'),
            ),
            ListTile(
              leading: const Icon(Icons.casino_outlined),
              title: Text(l10n.attachDice),
              onTap: () => Navigator.pop(context, 'dice'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'file':
        final files = await openFiles();
        final caption = _input.text.trim();
        if (files.isNotEmpty) _input.clear();
        for (final (i, f) in files.indexed) {
          await _guard(
            () => _repo.sendFile(f.path, caption: i == 0 ? caption : ''),
          );
        }
      case 'poll':
        final p = await showNewPollDialog(context);
        if (p == null) return;
        await _guard(
          () => _repo.sendPoll(
            question: p.question,
            options: p.options,
            anonymous: p.anonymous,
            multiple: p.multiple,
            quiz: p.quiz,
            correct: p.correct,
          ),
        );
      case 'dice':
        final emoji = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final e in const ['🎲', '🎯', '🏀', '⚽', '🎳', '🎰'])
                  InkWell(
                    onTap: () => Navigator.pop(context, e),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(e, style: const TextStyle(fontSize: 36)),
                    ),
                  ),
              ],
            ),
          ),
        );
        if (emoji != null) await _guard(() => _repo.sendDice(emoji));
    }
  }

  bool _onEntity(TextSpanInfo s, String raw) {
    switch (s.kind) {
      case SpanKind.botCommand:
        unawaited(_guard(() => _repo.sendText(raw)));
        return true;
      case SpanKind.mentionName:
        if (s.userId != null) unawaited(openUserChat(context, ref, s.userId!));
        return true;
      case SpanKind.mention:
        unawaited(
          openSmartLink(context, ref, 'https://t.me/${raw.substring(1)}'),
        );
        return true;
      case SpanKind.url || SpanKind.textUrl:
        unawaited(
          openSmartLink(context, ref, s.kind == SpanKind.textUrl ? s.url : raw),
        );
        return true;
      default:
        return false;
    }
  }

  void _pressReply(MarkupButton b) {
    final k = _repo.replyKeyboard;
    unawaited(_guard(() => _repo.sendText(b.text)));
    if (k != null && k.oneTime) setState(() => _keyboardOpen = false);
  }

  Future<void> _showEdits(ChatMessage m) async {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final edits = await _repo.edits(m.id);
    if (!mounted) return;
    final fmt = DateFormat('dd.MM HH:mm', locale);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.editHistoryTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (edits.isEmpty) ListTile(title: Text(l10n.editHistoryEmpty)),
            for (final e in edits)
              ListTile(
                title: Text(e.text),
                subtitle: Text(
                  fmt.format(e.at),
                  style: TextStyle(color: colors.secondary),
                ),
              ),
            ListTile(
              title: Text(m.content.text),
              subtitle: Text(
                '${l10n.editHistoryCurrent} · '
                '${fmt.format(m.editDate ?? m.date)}',
                style: TextStyle(color: colors.accent),
              ),
            ),
          ],
        ),
      ),
    );
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

  void _insertText(String text) {
    final sel = _input.selection;
    final value = _input.text;
    final start = sel.isValid ? sel.start : value.length;
    final end = sel.isValid ? sel.end : value.length;
    _input.text = value.replaceRange(start, end, text);
    _input.selection = TextSelection.collapsed(offset: start + text.length);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(composerInsertProvider, (_, next) {
      if (next.$1 > 0) _insertText(next.$2);
    });
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
          const AudioBar(),
          if (_repo.pinned case final pin?)
            _PinnedBar(
              message: pin,
              onClose: () => _guard(() => _repo.pin(pin.id, unpin: true)),
            ),
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
                        repo: _repo,
                        onEntity: _onEntity,
                        onSwitchInline: (q) {
                          _input.text = q;
                          _inputFocus.requestFocus();
                        },
                        onActions: () => _showActions(m),
                        onEdits: () => _showEdits(m),
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
          if (_commandsOpen && _repo.commands.isNotEmpty)
            CommandsList(
              commands: _repo.commands,
              onPick: (c) {
                setState(() => _commandsOpen = false);
                unawaited(_guard(() => _repo.sendText('/${c.command}')));
              },
            ),
          _Composer(
            controller: _input,
            focusNode: _inputFocus,
            onSend: _submit,
            onTyping: () => unawaited(_repo.sendTyping()),
            editing: _mode == _Mode.edit,
            onAttach: _attach,
            hasCommands: _repo.commands.isNotEmpty,
            onCommands: () => setState(() => _commandsOpen = !_commandsOpen),
            hasKeyboard: _repo.replyKeyboard != null,
            keyboardOpen: _keyboardOpen,
            onKeyboard: () => setState(() => _keyboardOpen = !_keyboardOpen),
            hint: _repo.replyKeyboard?.placeholder,
            sendWithEnter: ref.watch(appPrefsProvider).sendWithEnter,
          ),
          if (_repo.replyKeyboard case final k? when _keyboardOpen)
            ReplyKeyboardView(keyboard: k, onPress: _pressReply),
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
    required this.onEdits,
    required this.repo,
    required this.onEntity,
    required this.onSwitchInline,
    this.replied,
    this.isRead = false,
  });

  final MessagesRepository repo;
  final EntityTap onEntity;
  final ValueChanged<String> onSwitchInline;
  final ChatMessage message;
  final bool showSender;
  final bool showAvatar;
  final bool tail;
  final VoidCallback onEdits;
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
    if (media is ServiceMedia && media.isPill) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: GestureDetector(
            onSecondaryTap: onActions,
            onLongPress: onActions,
            child: _Pill(text: serviceText(context, ref, message, media)),
          ),
        ),
      );
    }
    final sticker = media is StickerMedia;
    final roundVideo = media is VideoMedia && media.isRound;
    final bare = sticker || roundVideo;
    final text = media == null
        ? previewText(context, message.content)
        : media is ServiceMedia
        ? serviceText(context, ref, message, media)
        : media is PollMedia ||
              media is LocationMedia ||
              media is ContactMedia ||
              media is DiceMedia
        ? ''
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
        if (message.isDeleted) ...[
          Icon(Icons.delete_outline, size: 13, color: colors.deleted),
          Text(
            ' ${context.l10n.messageDeleted}  ',
            style: meta.copyWith(color: colors.deleted),
          ),
        ],
        if (message.isEdited)
          GestureDetector(
            onTap: onEdits,
            child: Text(
              '${context.l10n.messageEdited} ',
              style: meta.copyWith(decoration: TextDecoration.underline),
            ),
          ),
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
            SendState.sent => MessageTicks(
              read: isRead,
              color: isRead ? _readColor(colors) : metaColor,
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
        if (message.forward case final f?)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              context.l10n.forwardedFrom(_forwardName(ref, f)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: out ? fg : colors.accent,
                fontSize: 13,
                fontStyle: FontStyle.italic,
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
                child: MediaView(
                  media: media,
                  maxWidth: maxWidth - 16,
                  outgoing: out,
                  chatId: message.chatId,
                  messageId: message.id,
                ),
              ),
            ),
          ),
        if (text.isNotEmpty)
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              RichMessageText(
                text: text,
                spans: message.spans,
                style: TextStyle(color: fg, fontSize: 15, height: 1.3),
                linkColor: out ? fg : colors.accent,
                onEntity: onEntity,
              ),
              if (message.linkPreview != null)
                LinkPreviewCard(
                  preview: message.linkPreview!,
                  accent: out ? fg : colors.accent,
                  textColor: fg,
                  maxWidth: maxWidth - 20,
                ),
              footer,
            ],
          )
        else
          Align(alignment: Alignment.bottomRight, child: footer),
        if (message.reactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final r in message.reactions)
                  GestureDetector(
                    onTap: () => unawaited(
                      repo
                          .toggleReaction(message, r.emoji)
                          .catchError((Object _) {}),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: r.chosen
                            ? (out ? fg : colors.accent)
                            : (out ? fg : colors.accent).withValues(
                                alpha: 0.15,
                              ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${r.emoji} ${r.count}',
                        style: TextStyle(
                          fontSize: 13,
                          color: r.chosen
                              ? (out ? colors.bubbleOut : colors.bubbleIn)
                              : fg,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    final skin = ref.watch(skinProvider);
    if (skin.typographic &&
        media == null &&
        reply == null &&
        message.markup == null &&
        message.spans.isEmpty) {
      final wide = MediaQuery.sizeOf(context).width >= 760;
      return GestureDetector(
        onLongPress: onActions,
        onSecondaryTap: onActions,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tail ? 14 : 4),
          child: Column(
            crossAxisAlignment: out
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (showSender && sender != null)
                Text(
                  sender.name.toUpperCase(),
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              Text(
                text,
                textAlign: out ? TextAlign.right : TextAlign.left,
                style: TextStyle(
                  fontSize: wide ? 30 : 21,
                  height: 1.15,
                  fontWeight: out ? FontWeight.w300 : FontWeight.w500,
                  color: message.isDeleted
                      ? colors.secondary
                      : out
                      ? colors.textOut
                      : colors.textIn,
                  decoration: message.isDeleted
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: colors.deleted,
                  decorationThickness: 2,
                ),
              ),
              const SizedBox(height: 4),
              if (message.isDeleted)
                Text(
                  context.l10n.monolithDeleted,
                  style: TextStyle(
                    color: colors.deleted,
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                footer,
            ],
          ),
        ),
      );
    }

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
                border: message.isDeleted
                    ? Border.all(color: colors.deleted.withValues(alpha: 0.6))
                    : null,
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
          child: message.markup is InlineKeyboard
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    bubble,
                    Padding(
                      padding: EdgeInsets.only(bottom: tail ? 6 : 2),
                      child: InlineKeyboardView(
                        keyboard: message.markup! as InlineKeyboard,
                        message: message,
                        repo: repo,
                        maxWidth: maxWidth,
                        onSwitchInline: onSwitchInline,
                      ),
                    ),
                  ],
                )
              : bubble,
        ),
      ],
    );
  }

  static Color _readColor(ChatColors c) {
    final diff = (c.accent.computeLuminance() - c.bubbleOut.computeLuminance())
        .abs();
    return diff > 0.2 ? c.accent : c.metaOut;
  }

  static String _forwardName(WidgetRef ref, ForwardOrigin f) {
    if (f.userId != null) {
      return ref.read(usersRepositoryProvider).nameOf(f.userId!) ?? f.name;
    }
    if (f.chatId != null) {
      final chats = ref.read(chatsProvider).value ?? const <ChatSummary>[];
      final c = chats.where((c) => c.id == f.chatId).firstOrNull;
      if (c != null) return c.title;
    }
    return f.name;
  }
}

class _PinnedBar extends StatelessWidget {
  const _PinnedBar({required this.message, required this.onClose});

  final ChatMessage message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    return Material(
      color: colors.panel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
        child: Row(
          children: [
            Container(width: 2, height: 32, color: colors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.pinnedMessage,
                    style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    previewText(context, message.content),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.l10n.actionUnpin,
              icon: Icon(Icons.close, size: 18, color: colors.secondary),
              onPressed: onClose,
            ),
          ],
        ),
      ),
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
    required this.onTyping,
    required this.onAttach,
    required this.onCommands,
    required this.onKeyboard,
    this.editing = false,
    this.hasCommands = false,
    this.hasKeyboard = false,
    this.keyboardOpen = false,
    this.hint,
    this.sendWithEnter = true,
  });

  final bool sendWithEnter;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function() onSend;
  final VoidCallback onTyping;
  final VoidCallback onAttach;
  final VoidCallback onCommands;
  final VoidCallback onKeyboard;
  final bool editing;
  final bool hasCommands;
  final bool hasKeyboard;
  final bool keyboardOpen;
  final String? hint;

  Widget _menu(BuildContext context, EditableTextState state) {
    final l10n = context.l10n;
    final sel = controller.selection;
    final items = [...state.contextMenuButtonItems];
    if (sel.isValid && !sel.isCollapsed) {
      void fmt(String open, [String? close]) {
        wrapSelection(controller, open, close);
        state.hideToolbar();
      }

      items.addAll([
        ContextMenuButtonItem(label: l10n.fmtBold, onPressed: () => fmt('**')),
        ContextMenuButtonItem(
          label: l10n.fmtItalic,
          onPressed: () => fmt('__'),
        ),
        ContextMenuButtonItem(
          label: l10n.fmtStrike,
          onPressed: () => fmt('~~'),
        ),
        ContextMenuButtonItem(
          label: l10n.fmtSpoiler,
          onPressed: () => fmt('||'),
        ),
        ContextMenuButtonItem(label: l10n.fmtCode, onPressed: () => fmt('`')),
        ContextMenuButtonItem(
          label: l10n.fmtPre,
          onPressed: () => fmt('```\n', '\n```'),
        ),
        ContextMenuButtonItem(
          label: l10n.fmtLink,
          onPressed: () {
            state.hideToolbar();
            unawaited(insertLink(context, controller));
          },
        ),
      ]);
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    return Material(
      color: colors.panel,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 6, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: context.l10n.attach,
                color: colors.secondary,
                onPressed: onAttach,
                icon: const Icon(Icons.attach_file),
              ),
              if (hasCommands)
                IconButton(
                  tooltip: context.l10n.botCommands,
                  color: colors.accent,
                  onPressed: onCommands,
                  icon: const Icon(Icons.terminal),
                ),
              Expanded(
                child: CallbackShortcuts(
                  bindings: {
                    if (_isDesktop && sendWithEnter)
                      const SingleActivator(LogicalKeyboardKey.enter): onSend,
                    if (_isDesktop && !sendWithEnter)
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        control: true,
                      ): onSend,
                    const SingleActivator(
                      LogicalKeyboardKey.keyB,
                      control: true,
                    ): () =>
                        wrapSelection(controller, '**'),
                    const SingleActivator(
                      LogicalKeyboardKey.keyI,
                      control: true,
                    ): () =>
                        wrapSelection(controller, '__'),
                    const SingleActivator(
                      LogicalKeyboardKey.keyX,
                      control: true,
                      shift: true,
                    ): () =>
                        wrapSelection(controller, '~~'),
                    const SingleActivator(
                      LogicalKeyboardKey.keyP,
                      control: true,
                      shift: true,
                    ): () =>
                        wrapSelection(controller, '||'),
                    const SingleActivator(
                      LogicalKeyboardKey.keyM,
                      control: true,
                      shift: true,
                    ): () =>
                        wrapSelection(controller, '`'),
                    const SingleActivator(
                      LogicalKeyboardKey.keyK,
                      control: true,
                    ): () =>
                        unawaited(insertLink(context, controller)),
                  },
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 8,
                    textInputAction: TextInputAction.newline,
                    contextMenuBuilder: _menu,
                    onChanged: (v) {
                      if (v.isNotEmpty) onTyping();
                    },
                    decoration: InputDecoration(
                      hintText: (hint?.isNotEmpty ?? false)
                          ? hint
                          : context.l10n.composerHint,
                      hintStyle: TextStyle(color: colors.secondary),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
              if (hasKeyboard)
                IconButton(
                  tooltip: context.l10n.botKeyboard,
                  color: keyboardOpen ? colors.accent : colors.secondary,
                  onPressed: onKeyboard,
                  icon: Icon(
                    keyboardOpen ? Icons.keyboard_hide : Icons.keyboard,
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
