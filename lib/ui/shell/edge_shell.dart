import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/ayu/ayu_settings.dart';
import '../../core/l10n/l10n.dart';
import '../../data/chats/chat_summary.dart';
import '../../features/chat/chat_screen.dart';
import '../components/presence_text.dart';
import '../theme/chat_colors.dart';

enum _Side { none, left, right }

/// The whole screen is the open chat; chats and tools hide behind the edges.
class EdgeShell extends ConsumerStatefulWidget {
  const EdgeShell({super.key, this.chatId});

  final int? chatId;

  static const hoverZone = 78.0;
  static const swipeZone = 28.0;

  @override
  ConsumerState<EdgeShell> createState() => _EdgeShellState();
}

class _EdgeShellState extends ConsumerState<EdgeShell> {
  _Side _open = _Side.none;
  double _dragStart = 0;
  double _dragDx = 0;

  static bool get _hover => switch (defaultTargetPlatform) {
    TargetPlatform.linux ||
    TargetPlatform.windows ||
    TargetPlatform.macOS => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(chatsRepositoryProvider).loadMore().catchError((_) {}),
      );
    });
  }

  void _set(_Side s) {
    if (_open != s) setState(() => _open = s);
  }

  void _openChat(int id) {
    _set(_Side.none);
    context.go(Routes.chat(id));
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 760;
    final panelWidth = (width * (wide ? 0.34 : 0.82)).clamp(260.0, 420.0);
    final reduce = MediaQuery.of(context).disableAnimations;
    final dur = reduce ? Duration.zero : const Duration(milliseconds: 220);
    final chats = ref.watch(chatsProvider).value ?? const <ChatSummary>[];
    final id = widget.chatId;

    return Scaffold(
      backgroundColor: colors.chatBackground,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (d) {
          _dragStart = d.globalPosition.dx;
          _dragDx = 0;
        },
        onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          final right = v > 200 || _dragDx > 60;
          final left = v < -200 || _dragDx < -60;
          if (_open == _Side.none) {
            if (_dragStart < EdgeShell.swipeZone + 24 && right) {
              _set(_Side.left);
            } else if (_dragStart > width - EdgeShell.swipeZone - 24 && left) {
              _set(_Side.right);
            }
          } else if ((_open == _Side.left && left) ||
              (_open == _Side.right && right)) {
            _set(_Side.none);
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              left: 22,
              right: 22,
              child: id == null
                  ? _Hint(desktop: _hover)
                  : ChatScreen(key: ValueKey(id), chatId: id, embedded: true),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 22,
              child: _ChatStrip(chats: chats, selected: id, onTap: _openChat),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 22,
              child: _ToolStrip(onTap: () => _set(_Side.right)),
            ),
            if (_hover) ...[
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: EdgeShell.hoverZone,
                child: MouseRegion(
                  opaque: false,
                  hitTestBehavior: HitTestBehavior.translucent,
                  onEnter: (_) => _set(_Side.left),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: EdgeShell.hoverZone,
                child: MouseRegion(
                  opaque: false,
                  hitTestBehavior: HitTestBehavior.translucent,
                  onEnter: (_) => _set(_Side.right),
                ),
              ),
            ],
            IgnorePointer(
              ignoring: _open == _Side.none,
              child: GestureDetector(
                onTap: () => _set(_Side.none),
                child: AnimatedOpacity(
                  opacity: _open == _Side.none ? 0 : 1,
                  duration: dur,
                  curve: Curves.easeOutCubic,
                  child: const ColoredBox(
                    color: Color(0x99000000),
                    child: SizedBox.expand(),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: dur,
              curve: Curves.easeOutCubic,
              left: _open == _Side.left ? 0 : -panelWidth,
              top: 0,
              bottom: 0,
              width: panelWidth,
              child: MouseRegion(
                onExit: (_) {
                  if (_hover && _open == _Side.left) _set(_Side.none);
                },
                child: _ChatPanel(chats: chats, selected: id, onTap: _openChat),
              ),
            ),
            AnimatedPositioned(
              duration: dur,
              curve: Curves.easeOutCubic,
              right: _open == _Side.right ? 0 : -panelWidth,
              top: 0,
              bottom: 0,
              width: panelWidth,
              child: MouseRegion(
                onExit: (_) {
                  if (_hover && _open == _Side.right) _set(_Side.none);
                },
                child: _ToolPanel(
                  chat: chats.where((c) => c.id == id).firstOrNull,
                  onNavigate: (route) {
                    _set(_Side.none);
                    unawaited(context.push(route));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    return Center(
      child: Text(
        desktop ? context.l10n.edgeHintDesktop : context.l10n.edgeHintMobile,
        style: TextStyle(color: colors.secondary, fontSize: 16),
      ),
    );
  }
}

/// Thin plates, one per chat: white for the open one, red cap when unread.
class _ChatStrip extends StatelessWidget {
  const _ChatStrip({
    required this.chats,
    required this.selected,
    required this.onTap,
  });

  final List<ChatSummary> chats;
  final int? selected;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final plateW = wide ? 6.0 : 4.0;
    final plateH = wide ? 44.0 : 26.0;
    return LayoutBuilder(
      builder: (context, box) {
        final fit = ((box.maxHeight - 32) / (plateH + 8)).floor().clamp(0, 60);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final c in chats.take(fit))
                GestureDetector(
                  onTap: () => onTap(c.id),
                  child: Container(
                    width: plateW,
                    height: plateH,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: c.id == selected
                          ? colors.textIn
                          : colors.divider.withValues(alpha: 1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.topCenter,
                    child: c.unreadCount > 0
                        ? Container(height: 12, color: colors.deleted)
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolStrip extends StatelessWidget {
  const _ToolStrip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 6,
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: i == 0 ? colors.accent : colors.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.chats,
    required this.selected,
    required this.onTap,
  });

  final List<ChatSummary> chats;
  final int? selected;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.chatBackground,
              colors.chatBackground.withValues(alpha: 0.92),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            itemCount: chats.length,
            itemBuilder: (context, i) {
              final c = chats[i];
              final active = c.id == selected;
              return InkWell(
                onTap: () => onTap(c.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 28,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: active ? colors.textIn : colors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          c.title.isEmpty ? context.l10n.chatUntitled : c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? colors.textIn
                                : colors.textIn.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                      if (c.unreadCount > 0)
                        Text(
                          '${c.unreadCount}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: colors.deleted,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ToolPanel extends ConsumerWidget {
  const _ToolPanel({required this.chat, required this.onNavigate});

  final ChatSummary? chat;
  final void Function(String route) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    ref.watch(usersChangedProvider);
    final ayu = ref.watch(ayuSettingsProvider);
    final n = ref.read(ayuSettingsProvider.notifier);
    final c = chat;
    final sub = c == null
        ? ''
        : chatSubtitle(
            l10n,
            c,
            ref.read(usersRepositoryProvider),
            DateTime.now(),
            Localizations.localeOf(context).toLanguageTag(),
          );

    Widget toggle(String label, bool value, Future<void> Function(bool) set) =>
        InkWell(
          onTap: () => unawaited(set(!value)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: colors.textIn,
                      fontSize: 13,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  value ? l10n.ayuOn : l10n.ayuOff,
                  style: TextStyle(
                    color: value ? colors.textIn : colors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? colors.deleted : Colors.transparent,
                    border: Border.all(
                      color: value ? colors.deleted : colors.secondary,
                      width: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    return Material(
      color: colors.chatBackground,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 24, 24),
          children: [
            if (c != null) ...[
              Text(
                c.title.toUpperCase(),
                textAlign: TextAlign.right,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textIn,
                  fontSize: 40,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                sub,
                textAlign: TextAlign.right,
                style: TextStyle(color: colors.secondary),
              ),
              const SizedBox(height: 28),
            ],
            Text(
              l10n.ayuTitle.toUpperCase(),
              style: TextStyle(
                color: colors.secondary,
                fontSize: 12,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            toggle(l10n.ayuGhost, ayu.ghostMode, n.setGhostMode),
            toggle(l10n.ayuSaveDeleted, ayu.saveDeleted, n.setSaveDeleted),
            toggle(l10n.ayuEditHistory, ayu.editHistory, n.setEditHistory),
            toggle(
              l10n.ayuReadSilently,
              ayu.readSilentlyOnReply,
              n.setReadSilentlyOnReply,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.edgeTools.toUpperCase(),
              style: TextStyle(
                color: colors.secondary,
                fontSize: 12,
                letterSpacing: 1.4,
              ),
            ),
            for (final (icon, label, route) in [
              (Icons.person_outline, l10n.menuProfile, Routes.profile),
              (Icons.palette_outlined, l10n.menuAppearance, Routes.appearance),
              (Icons.settings_outlined, l10n.menuSettings, Routes.settings),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon, color: colors.textIn),
                title: Text(label, style: TextStyle(color: colors.textIn)),
                onTap: () => onNavigate(route),
              ),
          ],
        ),
      ),
    );
  }
}
