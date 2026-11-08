import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/l10n/l10n.dart';
import '../../core/tdlib/td_error.dart';
import '../../data/messages/chat_message.dart';
import '../../data/messages/messages_repository.dart';
import '../../ui/components/preview_text.dart';

enum _Mode { send, reply, edit }

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final int chatId;

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

  @override
  void initState() {
    super.initState();
    _keep = ref.listenManual(
      messagesRepositoryProvider(widget.chatId),
      (_, _) {},
    );
    _repo = _keep.read();
    _scroll.addListener(_maybeLoadOlder);
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

  void _maybeLoadOlder() {
    final pos = _scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 800) {
      unawaited(
        _repo.loadOlder().then((_) {
          if (mounted) setState(() {});
        }),
      );
    }
  }

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
    final l10n = context.l10n;
    final chat = ref
        .watch(chatsProvider)
        .value
        ?.where((c) => c.id == widget.chatId);
    final title = chat == null || chat.isEmpty ? '' : chat.first.title;
    final isGroup = chat != null && chat.isNotEmpty && chat.first.isGroup;
    final messages = ref.watch(messagesProvider(widget.chatId)).value ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(title.isEmpty ? l10n.chatUntitled : title)),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: _repo.reachedStart
                        ? Text(l10n.chatHistoryEmpty)
                        : const CircularProgressIndicator(),
                  )
                : ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final older = i + 1 < messages.length
                          ? messages[i + 1]
                          : null;
                      final showSender =
                          isGroup &&
                          !m.isOutgoing &&
                          (older == null ||
                              older.senderUserId != m.senderUserId);
                      return _Bubble(
                        message: m,
                        showSender: showSender,
                        replied: _repo.repliedTo(m),
                        isRead: _repo.isRead(m),
                        onActions: () => _showActions(m),
                      );
                    },
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
}

class _Bubble extends ConsumerWidget {
  const _Bubble({
    required this.message,
    required this.showSender,
    required this.onActions,
    this.replied,
    this.isRead = false,
  });

  final ChatMessage message;
  final bool showSender;
  final ChatMessage? replied;
  final bool isRead;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final out = message.isOutgoing;
    final fg = out ? scheme.onPrimary : scheme.onSurface;
    final meta = TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.6));
    final locale = Localizations.localeOf(context).toLanguageTag();
    final users = ref.read(usersRepositoryProvider);
    final sender = message.senderUserId == null
        ? null
        : users.nameOf(message.senderUserId!);
    final reply = replied;

    return Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: GestureDetector(
          onLongPress: onActions,
          onSecondaryTap: onActions,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(
              color: out ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSender && sender != null && sender.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      sender,
                      style: TextStyle(
                        color: scheme.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (reply != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: scheme.error, width: 2),
                      ),
                    ),
                    child: Text(
                      previewText(context, reply.content),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ),
                Text(
                  previewText(context, message.content),
                  style: TextStyle(color: fg, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isEdited)
                      Text('${context.l10n.messageEdited} ', style: meta),
                    Text(
                      DateFormat.Hm(locale).format(message.date),
                      style: meta,
                    ),
                    if (out) ...[
                      const SizedBox(width: 4),
                      switch (message.sendState) {
                        SendState.pending => Icon(
                          Icons.schedule,
                          size: 12,
                          color: meta.color,
                        ),
                        SendState.failed => Tooltip(
                          message: context.l10n.messageSendFailed,
                          child: Icon(
                            Icons.error_outline,
                            size: 12,
                            color: scheme.error,
                          ),
                        ),
                        SendState.sent => Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 13,
                          color: meta.color,
                        ),
                      },
                    ],
                  ],
                ),
              ],
            ),
          ),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
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
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outline)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
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
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: context.l10n.composerHint,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            IconButton.filled(
              tooltip: editing
                  ? context.l10n.actionSave
                  : context.l10n.actionSend,
              onPressed: onSend,
              icon: Icon(editing ? Icons.check : Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }
}
