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

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final int chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();
  late final ProviderSubscription<MessagesRepository> _keep;
  late final MessagesRepository _repo;
  int? _lastSeenId;

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
                      return _Bubble(message: m, showSender: showSender);
                    },
                  ),
          ),
          _Composer(onSend: _repo.sendText),
        ],
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message, required this.showSender});

  final ChatMessage message;
  final bool showSender;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final out = message.isOutgoing;
    final fg = out ? scheme.onPrimary : scheme.onSurface;
    final meta = TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.6));
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sender = message.senderUserId == null
        ? null
        : ref.read(usersRepositoryProvider).nameOf(message.senderUserId!);

    return Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
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
              SelectableText(
                previewText(context, message.content),
                style: TextStyle(color: fg, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isEdited)
                    Text('${context.l10n.messageEdited} ', style: meta),
                  Text(DateFormat.Hm(locale).format(message.date), style: meta),
                  if (message.sendState == SendState.pending)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.schedule, size: 12, color: meta.color),
                    ),
                  if (message.sendState == SendState.failed)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Tooltip(
                        message: context.l10n.messageSendFailed,
                        child: Icon(
                          Icons.error_outline,
                          size: 12,
                          color: scheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.onSend});

  final Future<void> Function(String text) onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

bool get _isDesktop => switch (defaultTargetPlatform) {
  TargetPlatform.linux ||
  TargetPlatform.windows ||
  TargetPlatform.macOS => true,
  _ => false,
};

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await widget.onSend(text);
    } on TdError catch (e) {
      if (!mounted) return;
      _controller.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatSendError(e.message))),
      );
    }
  }

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
                    const SingleActivator(LogicalKeyboardKey.enter): _send,
                },
                child: TextField(
                  controller: _controller,
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
              tooltip: context.l10n.actionSend,
              onPressed: _send,
              icon: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }
}
