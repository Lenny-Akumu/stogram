import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../data/chats/chat_summary.dart';
import '../../features/chat/chat_screen.dart';
import '../../core/l10n/l10n.dart';
import '../theme/chat_colors.dart';
import 'edge_config.dart';
import 'edge_panels.dart';

/// The whole screen is the open chat; tabs on both edges slide panels in.
class EdgeShell extends ConsumerStatefulWidget {
  const EdgeShell({super.key, this.chatId});

  final int? chatId;

  static const swipeZone = 28.0;
  static const stripWidth = 30.0;

  @override
  ConsumerState<EdgeShell> createState() => _EdgeShellState();
}

class _EdgeShellState extends ConsumerState<EdgeShell> {
  EdgePanel? _open;
  bool _openLeft = true;
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

  void _show(EdgePanel? panel, {bool left = true}) {
    if (_open == panel && _openLeft == left) return;
    setState(() {
      _open = panel;
      _openLeft = left;
    });
    if (panel == EdgePanel.profile) {
      final chats = ref.read(chatsProvider).value ?? const <ChatSummary>[];
      final userId = chats
          .where((c) => c.id == widget.chatId)
          .firstOrNull
          ?.peer
          .userId;
      if (userId != null) {
        unawaited(ref.read(usersRepositoryProvider).loadFullInfo(userId));
      }
    }
  }

  void _close() => _show(null);

  /// Pointer left a tab strip; close unless it went into the open panel.
  void _leftStrip(Offset pos, {required bool left}) {
    if (!_hover || _open == null || _openLeft != left) return;
    final width = MediaQuery.sizeOf(context).width;
    final w = ref.read(edgeConfigProvider).width(left: left);
    const strip = EdgeShell.stripWidth;
    final intoPanel = left
        ? pos.dx >= strip && pos.dx <= strip + w
        : pos.dx <= width - strip && pos.dx >= width - strip - w;
    final stillOnStrip = left ? pos.dx < strip : pos.dx > width - strip;
    if (!intoPanel && !stillOnStrip) _close();
  }

  void _openChat(int id) {
    _close();
    context.go(Routes.chat(id));
  }

  void _navigate(String route) {
    _close();
    unawaited(context.push(route));
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 760;
    final reduce = MediaQuery.of(context).disableAnimations;
    final dur = reduce ? Duration.zero : const Duration(milliseconds: 220);
    final config = ref.watch(edgeConfigProvider);
    final cfgN = ref.read(edgeConfigProvider.notifier);
    final chats = ref.watch(chatsProvider).value ?? const <ChatSummary>[];
    final id = widget.chatId;
    final unread = chats.any((c) => c.unreadCount > 0);
    const strip = EdgeShell.stripWidth;

    double panelW(bool left) {
      final w = config.width(left: left);
      return wide ? w : (width - 2 * strip - 48).clamp(220.0, w);
    }

    // Pins only dock on wide screens; phones keep panels as overlays.
    EdgePanel? docked(bool left) => wide ? config.pinned(left: left) : null;
    EdgePanel? temp(bool left) =>
        _open != null && _openLeft == left ? _open : null;
    final overlayOpen = [
      true,
      false,
    ].any((l) => temp(l) != null && docked(l) == null);

    Widget panelFor(EdgePanel p, bool left) => EdgePanelView(
      panel: p,
      chatId: id,
      pinned: config.pinned(left: left) == p,
      onTogglePin: () => unawaited(cfgN.togglePin(left: left, panel: p)),
      onOpenChat: _openChat,
      onNavigate: _navigate,
      onDone: _close,
    );

    Widget resizeHandle(bool left) => MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => cfgN.setWidth(
          left: left,
          width: config.width(left: left) + (left ? d.delta.dx : -d.delta.dx),
        ),
        onHorizontalDragEnd: (_) => unawaited(cfgN.saveWidth()),
        child: const SizedBox(width: 6),
      ),
    );

    Widget side(bool left) {
      final dock = docked(left);
      final shown = temp(left) ?? dock;
      final w = panelW(left);
      final visible = shown != null;
      return AnimatedPositioned(
        duration: dock != null ? Duration.zero : dur,
        curve: Curves.easeOutCubic,
        left: left ? (visible ? strip : strip - w - 12) : null,
        right: left ? null : (visible ? strip : strip - w - 12),
        top: 0,
        bottom: 0,
        width: w,
        child: MouseRegion(
          onExit: (e) {
            if (!_hover || temp(left) == null) return;
            final x = e.position.dx;
            final overStrip = left ? x < strip : x > width - strip;
            if (!overStrip) _close();
          },
          child: Row(
            children: [
              if (!left && wide) resizeHandle(false),
              Expanded(
                child: shown == null
                    ? const SizedBox.shrink()
                    : KeyedSubtree(
                        key: ValueKey(shown),
                        child: panelFor(shown, left),
                      ),
              ),
              if (left && wide) resizeHandle(true),
            ],
          ),
        ),
      );
    }

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
          final toRight = v > 200 || _dragDx > 60;
          final toLeft = v < -200 || _dragDx < -60;
          if (_open == null) {
            if (_dragStart < EdgeShell.swipeZone + 24 && toRight) {
              _show(config.left.firstOrNull);
            } else if (_dragStart > width - EdgeShell.swipeZone - 24 &&
                toLeft) {
              _show(config.right.firstOrNull, left: false);
            }
          } else if ((_openLeft && toLeft) || (!_openLeft && toRight)) {
            _close();
          }
        },
        child: Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              left: strip + (docked(true) != null ? panelW(true) : 0),
              right: strip + (docked(false) != null ? panelW(false) : 0),
              child: Listener(
                onPointerDown: (_) {
                  if (_open != null) _close();
                },
                child: id == null
                    ? _Hint(desktop: _hover)
                    : ChatScreen(key: ValueKey(id), chatId: id, embedded: true),
              ),
            ),
            IgnorePointer(
              ignoring: !overlayOpen,
              child: GestureDetector(
                onTap: _close,
                child: AnimatedOpacity(
                  opacity: overlayOpen ? 1 : 0,
                  duration: dur,
                  curve: Curves.easeOutCubic,
                  child: const ColoredBox(
                    color: Color(0x99000000),
                    child: SizedBox.expand(),
                  ),
                ),
              ),
            ),
            side(true),
            side(false),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: strip,
              child: ColoredBox(
                color: colors.chatBackground,
                child: _TabStrip(
                  tabs: config.left,
                  icons: config.showIcons,
                  active: temp(true) ?? docked(true),
                  pinned: docked(true),
                  badge: unread ? EdgePanel.chats : null,
                  alignRight: false,
                  hover: _hover,
                  onSelect: (p) => _show(
                    p == docked(true) || (p == _open && _openLeft) ? null : p,
                  ),
                  onLeave: (pos) => _leftStrip(pos, left: true),
                  onHover: (p) => _show(p == docked(true) ? null : p),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: strip,
              child: ColoredBox(
                color: colors.chatBackground,
                child: _TabStrip(
                  tabs: config.right,
                  icons: config.showIcons,
                  active: temp(false) ?? docked(false),
                  pinned: docked(false),
                  badge: unread ? EdgePanel.chats : null,
                  alignRight: true,
                  hover: _hover,
                  onSelect: (p) => _show(
                    p == docked(false) || (p == _open && !_openLeft) ? null : p,
                    left: false,
                  ),
                  onLeave: (pos) => _leftStrip(pos, left: false),
                  onHover: (p) =>
                      _show(p == docked(false) ? null : p, left: false),
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

/// Vertical tabs on one edge; each opens its own panel.
class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.icons,
    required this.active,
    required this.pinned,
    required this.badge,
    required this.alignRight,
    required this.hover,
    required this.onSelect,
    required this.onHover,
    required this.onLeave,
  });

  final List<EdgePanel> tabs;
  final bool icons;
  final EdgePanel? active;
  final EdgePanel? pinned;
  final EdgePanel? badge;
  final bool alignRight;
  final bool hover;
  final void Function(EdgePanel) onSelect;
  final void Function(Offset) onLeave;
  final void Function(EdgePanel) onHover;

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    final l10n = context.l10n;
    final plateW = icons ? 26.0 : 6.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final t in tabs)
          Tooltip(
            message: t.label(l10n),
            preferBelow: false,
            child: MouseRegion(
              onEnter: hover ? (_) => onHover(t) : null,
              onExit: hover ? (e) => onLeave(e.position) : null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(t),
                child: SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: Align(
                    alignment: alignRight
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: active == t ? plateW + 4 : plateW,
                      height: 52,
                      margin: EdgeInsets.only(
                        left: alignRight ? 0 : 2,
                        right: alignRight ? 2 : 0,
                      ),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: active == t ? colors.textIn : colors.divider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Stack(
                        children: [
                          if (badge == t)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              height: 10,
                              child: ColoredBox(color: colors.deleted),
                            ),
                          if (pinned == t)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 6,
                              child: ColoredBox(color: colors.accent),
                            ),
                          if (icons)
                            Center(
                              child: Icon(
                                t.icon,
                                size: 16,
                                color: active == t
                                    ? colors.chatBackground
                                    : colors.secondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
