import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/ayu/ayu_settings.dart';
import '../../core/l10n/l10n.dart';
import '../../data/chats/chat_summary.dart';
import '../../data/chats/chats_repository.dart';
import '../../data/stickers/stickers_repository.dart';
import '../../features/chat_list/chat_list_screen.dart';
import '../components/avatar.dart';
import '../components/presence_text.dart';
import '../components/td_image.dart';
import '../theme/chat_colors.dart';
import 'edge_config.dart';

class EdgePanelView extends ConsumerWidget {
  const EdgePanelView({
    super.key,
    required this.panel,
    required this.chatId,
    required this.pinned,
    required this.onTogglePin,
    required this.onOpenChat,
    required this.onNavigate,
    required this.onDone,
  });

  final EdgePanel panel;
  final int? chatId;
  final bool pinned;
  final VoidCallback onTogglePin;
  final void Function(int) onOpenChat;
  final void Function(String) onNavigate;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ChatColors.of(context);
    return Material(
      color: colors.panel,
      elevation: 8,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
              child: Row(
                children: [
                  Icon(panel.icon, size: 18, color: colors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      panel.label(context.l10n),
                      style: TextStyle(
                        color: colors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: pinned
                        ? context.l10n.panelUnpin
                        : context.l10n.panelPin,
                    isSelected: pinned,
                    color: pinned ? colors.accent : colors.secondary,
                    onPressed: onTogglePin,
                    icon: Icon(
                      pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (panel) {
                EdgePanel.search => _SearchPanel(onOpen: onOpenChat),
                EdgePanel.chats => _ChatsPanel(
                  selected: chatId,
                  onOpen: onOpenChat,
                ),
                EdgePanel.profile => _ProfilePanel(chatId: chatId),
                EdgePanel.ayu => const _AyuPanel(),
                EdgePanel.settings => _SettingsPanel(onNavigate: onNavigate),
                EdgePanel.emoji => const _EmojiPanel(),
                EdgePanel.stickers => _StickersPanel(chatId: chatId),
                EdgePanel.gifs => _GifsPanel(chatId: chatId),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  );
}

class _ChatsPanel extends ConsumerStatefulWidget {
  const _ChatsPanel({required this.selected, required this.onOpen});

  final int? selected;
  final void Function(int) onOpen;

  @override
  ConsumerState<_ChatsPanel> createState() => _ChatsPanelState();
}

class _ChatsPanelState extends ConsumerState<_ChatsPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    ref.watch(usersChangedProvider);
    final all = ref.watch(chatsProvider).value ?? const <ChatSummary>[];
    final q = _query.trim().toLowerCase();
    final chats = q.isEmpty
        ? all
        : all.where((c) => c.title.toLowerCase().contains(q)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: SizedBox(
            height: 38,
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: context.l10n.searchHint,
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
        ),
        Expanded(
          child: ListView.builder(
            itemCount: chats.length,
            itemExtent: 72,
            itemBuilder: (context, i) => ChatTile(
              chat: chats[i],
              selected: chats[i].id == widget.selected,
              onTap: () => widget.onOpen(chats[i].id),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchPanel extends ConsumerStatefulWidget {
  const _SearchPanel({required this.onOpen});

  final void Function(int) onOpen;

  @override
  ConsumerState<_SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<_SearchPanel> {
  String _query = '';
  List<FoundMessage> _found = const [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = v.trim();
      final found = q.length < 2
          ? const <FoundMessage>[]
          : await ref.read(chatsRepositoryProvider).searchMessages(q);
      if (mounted && _query == v) setState(() => _found = found);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    ref.watch(usersChangedProvider);
    final all = ref.watch(chatsProvider).value ?? const <ChatSummary>[];
    final q = _query.trim().toLowerCase();
    final chats = q.isEmpty
        ? const <ChatSummary>[]
        : all.where((c) => c.title.toLowerCase().contains(q)).toList();
    final byId = {for (final c in all) c.id: c};
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: TextField(
            autofocus: true,
            onChanged: _changed,
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: colors.chatBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final c in chats)
                SizedBox(
                  height: 72,
                  child: ChatTile(chat: c, onTap: () => widget.onOpen(c.id)),
                ),
              if (_found.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    l10n.searchMessages,
                    style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              for (final m in _found)
                ListTile(
                  leading: Avatar(
                    id: m.chatId,
                    title: byId[m.chatId]?.title ?? '',
                    photo: byId[m.chatId]?.photo,
                    size: 40,
                  ),
                  title: Text(
                    byId[m.chatId]?.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    m.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.secondary),
                  ),
                  onTap: () => widget.onOpen(m.chatId),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfilePanel extends ConsumerWidget {
  const _ProfilePanel({required this.chatId});

  final int? chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    ref.watch(usersChangedProvider);
    final chats = ref.watch(chatsProvider).value ?? const <ChatSummary>[];
    final c = chats.where((x) => x.id == chatId).firstOrNull;
    if (c == null) return Center(child: Text(l10n.openChatFirst));
    final users = ref.read(usersRepositoryProvider);
    final user = c.peer.userId == null ? null : users.user(c.peer.userId!);
    final sub = chatSubtitle(
      l10n,
      c,
      users,
      DateTime.now(),
      Localizations.localeOf(context).toLanguageTag(),
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Avatar(id: c.id, title: c.title, photo: c.photo, size: 110),
        ),
        const SizedBox(height: 14),
        Text(
          c.title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.secondary),
        ),
        const SizedBox(height: 16),
        if (user != null)
          for (final (icon, label, value) in [
            (
              Icons.alternate_email,
              l10n.profileUsername,
              user.username.isEmpty ? '' : '@${user.username}',
            ),
            (
              Icons.phone_outlined,
              l10n.authPhoneLabel,
              user.phone.isEmpty ? '' : '+${user.phone}',
            ),
            (Icons.info_outline, l10n.profileBio, user.bio),
          ])
            if (value.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon, color: colors.accent),
                title: SelectableText(value),
                subtitle: Text(
                  label,
                  style: TextStyle(color: colors.secondary),
                ),
              ),
      ],
    );
  }
}

class _AyuPanel extends ConsumerWidget {
  const _AyuPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(ayuSettingsProvider);
    final n = ref.read(ayuSettingsProvider.notifier);
    Widget tile(String t, bool v, Future<void> Function(bool) set) =>
        SwitchListTile(
          title: Text(t),
          value: v,
          onChanged: (x) => unawaited(set(x)),
        );
    return ListView(
      children: [
        _Header(l10n.ayuTitle),
        tile(l10n.ayuGhost, s.ghostMode, n.setGhostMode),
        tile(
          l10n.ayuReadSilently,
          s.readSilentlyOnReply,
          n.setReadSilentlyOnReply,
        ),
        tile(l10n.ayuSaveDeleted, s.saveDeleted, n.setSaveDeleted),
        tile(l10n.ayuEditHistory, s.editHistory, n.setEditHistory),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.onNavigate});

  final void Function(String) onNavigate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      children: [
        _Header(l10n.settingsTitle),
        for (final (icon, label, route) in [
          (Icons.person_outline, l10n.menuProfile, Routes.profile),
          (Icons.palette_outlined, l10n.menuAppearance, Routes.appearance),
          (Icons.auto_awesome_outlined, l10n.menuAyu, Routes.ayu),
          (Icons.settings_outlined, l10n.menuSettings, Routes.settings),
        ])
          ListTile(
            leading: Icon(icon),
            title: Text(label),
            onTap: () => onNavigate(route),
          ),
      ],
    );
  }
}

const _emoji = [
  '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '😉', '😊', //
  '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙', '😋', '😛', '😜', '🤪', //
  '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🤐', '🤨', '😐', '😑', '😶', '😏', //
  '😒', '🙄', '😬', '😮‍💨', '🤥', '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', //
  '🤕', '🤢', '🤮', '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '😎', '🤓', //
  '🧐', '😕', '😟', '🙁', '😮', '😯', '😲', '😳', '🥺', '😦', '😧', '😨', //
  '😰', '😥', '😢', '😭', '😱', '😖', '😣', '😞', '😓', '😩', '😫', '🥱', //
  '😤', '😡', '😠', '🤬', '😈', '👿', '💀', '☠️', '💩', '🤡', '👻', '👽', //
  '🤖', '😺', '😸', '😹', '😻', '😼', '😽', '🙀', '😿', '😾', '🙈', '🙉', //
  '🙊', '💋', '💌', '💘', '💝', '💖', '💗', '💓', '💞', '💕', '❣️', '💔', //
  '❤️', '🧡', '💛', '💚', '💙', '💜', '🤎', '🖤', '🤍', '💯', '💢', '💥', //
  '💫', '💦', '💨', '🕳️', '💬', '💭', '💤', '👋', '🤚', '✋', '🖖', '👌', //
  '🤌', '🤏', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '👇', '☝️', //
  '👍', '👎', '✊', '👊', '🤛', '🤜', '👏', '🙌', '👐', '🤲', '🤝', '🙏', //
  '💪', '🧠', '👀', '👁️', '👅', '👄', '🔥', '⭐', '🌟', '✨', '⚡', '☀️', //
  '🌈', '❄️', '☔', '🌊', '🍀', '🌹', '🌻', '🍕', '🍔', '🍟', '🍿', '🍩', //
  '🍪', '🎂', '🍰', '🍫', '🍺', '🍻', '🥂', '🍷', '☕', '🥒', '🎉', '🎊', //
  '🎁', '🏆', '⚽', '🎮', '🎧', '🎵', '📱', '💻', '📷', '💡', '💰', '📌', //
  '✅', '❌', '❓', '❗', '⚠️', '🚀', '🇺🇦', '💙', '💛', '🙂‍↕️', '🫡', '🫶',
];

class _EmojiPanel extends ConsumerWidget {
  const _EmojiPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _Header(context.l10n.panelEmoji),
        Expanded(
          child: GridView.extent(
            maxCrossAxisExtent: 48,
            padding: const EdgeInsets.all(8),
            children: [
              for (final e in _emoji)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () =>
                      ref.read(composerInsertProvider.notifier).insert(e),
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 26)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StickersPanel extends ConsumerStatefulWidget {
  const _StickersPanel({required this.chatId});

  final int? chatId;

  @override
  ConsumerState<_StickersPanel> createState() => _StickersPanelState();
}

class _StickersPanelState extends ConsumerState<_StickersPanel> {
  List<StickerSetInfo>? _sets;
  int? _setId;
  List<StickerItem>? _stickers;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final sets = await ref.read(stickersRepositoryProvider).installedSets();
    if (!mounted) return;
    setState(() => _sets = sets);
    if (sets.isNotEmpty) await _pick(sets.first.id);
  }

  Future<void> _pick(int id) async {
    setState(() {
      _setId = id;
      _stickers = null;
    });
    final list = await ref.read(stickersRepositoryProvider).stickers(id);
    if (mounted && _setId == id) setState(() => _stickers = list);
  }

  Future<void> _send(StickerItem s) async {
    final id = widget.chatId;
    if (id == null) return;
    await ref.read(messagesRepositoryProvider(id)).sendSticker(s);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    final sets = _sets;
    if (widget.chatId == null) return Center(child: Text(l10n.openChatFirst));
    if (sets == null) return const Center(child: CircularProgressIndicator());
    if (sets.isEmpty) return Center(child: Text(l10n.stickersEmpty));
    final stickers = _stickers;
    return Column(
      children: [
        _Header(l10n.panelStickers),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final s in sets)
                InkWell(
                  onTap: () => unawaited(_pick(s.id)),
                  child: Container(
                    width: 44,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: s.id == _setId
                          ? colors.selected.withValues(alpha: 0.3)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: s.cover == null
                        ? Center(
                            child: Text(
                              s.title.isEmpty ? '?' : s.title.characters.first,
                            ),
                          )
                        : TdImage(s.cover!, fit: BoxFit.contain),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: stickers == null
              ? const Center(child: CircularProgressIndicator())
              : GridView.extent(
                  maxCrossAxisExtent: 84,
                  padding: const EdgeInsets.all(8),
                  children: [
                    for (final s in stickers)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => unawaited(_send(s)),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: s.preview.fileId == null
                              ? Center(
                                  child: Text(
                                    s.emoji,
                                    style: const TextStyle(fontSize: 36),
                                  ),
                                )
                              : TdImage(s.preview, fit: BoxFit.contain),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _GifsPanel extends ConsumerStatefulWidget {
  const _GifsPanel({required this.chatId});

  final int? chatId;

  @override
  ConsumerState<_GifsPanel> createState() => _GifsPanelState();
}

class _GifsPanelState extends ConsumerState<_GifsPanel> {
  List<GifItem>? _gifs;

  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(stickersRepositoryProvider).savedGifs().then((g) {
        if (mounted) setState(() => _gifs = g);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gifs = _gifs;
    final id = widget.chatId;
    if (id == null) return Center(child: Text(l10n.openChatFirst));
    if (gifs == null) return const Center(child: CircularProgressIndicator());
    if (gifs.isEmpty) return Center(child: Text(l10n.gifsEmpty));
    return Column(
      children: [
        _Header(l10n.panelGifs),
        Expanded(
          child: GridView.extent(
            maxCrossAxisExtent: 140,
            padding: const EdgeInsets.all(8),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (final g in gifs)
                InkWell(
                  onTap: () => unawaited(
                    ref.read(messagesRepositoryProvider(id)).sendGif(g),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TdImage(g.cover),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
