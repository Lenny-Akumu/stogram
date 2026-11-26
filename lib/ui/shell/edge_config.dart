import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ayu/ayu_settings.dart';
import '../../core/l10n/l10n.dart';

enum EdgePanel { search, chats, profile, ayu, settings, emoji, stickers, gifs }

extension EdgePanelLabel on EdgePanel {
  IconData get icon => switch (this) {
    EdgePanel.search => Icons.search,
    EdgePanel.chats => Icons.chat_bubble_outline,
    EdgePanel.profile => Icons.person_outline,
    EdgePanel.ayu => Icons.auto_awesome_outlined,
    EdgePanel.settings => Icons.settings_outlined,
    EdgePanel.emoji => Icons.emoji_emotions_outlined,
    EdgePanel.stickers => Icons.sticky_note_2_outlined,
    EdgePanel.gifs => Icons.gif_box_outlined,
  };

  String label(AppLocalizations l10n) => switch (this) {
    EdgePanel.search => l10n.searchHint,
    EdgePanel.chats => l10n.chatsTitle,
    EdgePanel.profile => l10n.panelProfile,
    EdgePanel.ayu => l10n.menuAyu,
    EdgePanel.settings => l10n.menuSettings,
    EdgePanel.emoji => l10n.panelEmoji,
    EdgePanel.stickers => l10n.panelStickers,
    EdgePanel.gifs => l10n.panelGifs,
  };
}

class EdgeConfig {
  const EdgeConfig({
    this.left = const [
      EdgePanel.search,
      EdgePanel.chats,
      EdgePanel.ayu,
      EdgePanel.settings,
    ],
    this.right = const [
      EdgePanel.profile,
      EdgePanel.emoji,
      EdgePanel.stickers,
      EdgePanel.gifs,
    ],
    this.showIcons = false,
    this.pinnedLeft,
    this.pinnedRight,
    this.widthLeft = 340,
    this.widthRight = 340,
  });

  static const maxTabs = 6;
  static const minWidth = 240.0;
  static const maxWidth = 640.0;

  final List<EdgePanel> left;
  final List<EdgePanel> right;
  final bool showIcons;
  final EdgePanel? pinnedLeft;
  final EdgePanel? pinnedRight;
  final double widthLeft;
  final double widthRight;

  EdgePanel? pinned({required bool left}) => left ? pinnedLeft : pinnedRight;
  double width({required bool left}) => left ? widthLeft : widthRight;

  EdgeConfig copyWith({
    List<EdgePanel>? left,
    List<EdgePanel>? right,
    bool? showIcons,
    EdgePanel? Function()? pinnedLeft,
    EdgePanel? Function()? pinnedRight,
    double? widthLeft,
    double? widthRight,
  }) => EdgeConfig(
    left: left ?? this.left,
    right: right ?? this.right,
    showIcons: showIcons ?? this.showIcons,
    pinnedLeft: pinnedLeft == null ? this.pinnedLeft : pinnedLeft(),
    pinnedRight: pinnedRight == null ? this.pinnedRight : pinnedRight(),
    widthLeft: widthLeft ?? this.widthLeft,
    widthRight: widthRight ?? this.widthRight,
  );
}

final edgeConfigProvider = NotifierProvider<EdgeConfigSetting, EdgeConfig>(
  EdgeConfigSetting.new,
);

class EdgeConfigSetting extends Notifier<EdgeConfig> {
  static const _left = 'edge.left';
  static const _right = 'edge.right';
  static const _icons = 'edge.icons';
  static const _pinL = 'edge.pinLeft';
  static const _pinR = 'edge.pinRight';
  static const _wL = 'edge.widthLeft';
  static const _wR = 'edge.widthRight';

  @override
  EdgeConfig build() {
    final p = ref.watch(sharedPrefsProvider);
    const d = EdgeConfig();
    if (p == null) return d;
    return EdgeConfig(
      left: _decode(p.getString(_left)) ?? d.left,
      right: _decode(p.getString(_right)) ?? d.right,
      showIcons: p.getBool(_icons) ?? d.showIcons,
      pinnedLeft: _one(p.getString(_pinL)),
      pinnedRight: _one(p.getString(_pinR)),
      widthLeft: p.getDouble(_wL) ?? d.widthLeft,
      widthRight: p.getDouble(_wR) ?? d.widthRight,
    );
  }

  static EdgePanel? _one(String? raw) =>
      EdgePanel.values.where((e) => e.name == raw).firstOrNull;

  static List<EdgePanel>? _decode(String? raw) {
    if (raw == null) return null;
    final list = [
      for (final n in raw.split(','))
        ?EdgePanel.values.where((e) => e.name == n).firstOrNull,
    ];
    return list.isEmpty ? null : list;
  }

  Future<void> _save() async {
    final p = ref.read(sharedPrefsProvider);
    await p?.setString(_left, state.left.map((e) => e.name).join(','));
    await p?.setString(_right, state.right.map((e) => e.name).join(','));
    await p?.setBool(_icons, state.showIcons);
    for (final (key, v) in [
      (_pinL, state.pinnedLeft),
      (_pinR, state.pinnedRight),
    ]) {
      if (v == null) {
        await p?.remove(key);
      } else {
        await p?.setString(key, v.name);
      }
    }
    await p?.setDouble(_wL, state.widthLeft);
    await p?.setDouble(_wR, state.widthRight);
  }

  /// Pins [panel] on a side, or unpins it if it already is.
  Future<void> togglePin({required bool left, required EdgePanel panel}) {
    final current = state.pinned(left: left);
    final next = current == panel ? null : panel;
    state = left
        ? state.copyWith(pinnedLeft: () => next)
        : state.copyWith(pinnedRight: () => next);
    return _save();
  }

  /// Live update while dragging; call [saveWidth] when the drag ends.
  void setWidth({required bool left, required double width}) {
    final w = width.clamp(EdgeConfig.minWidth, EdgeConfig.maxWidth);
    state = left ? state.copyWith(widthLeft: w) : state.copyWith(widthRight: w);
  }

  Future<void> saveWidth() => _save();

  Future<void> setSide({required bool left, required List<EdgePanel> tabs}) {
    state = left ? state.copyWith(left: tabs) : state.copyWith(right: tabs);
    return _save();
  }

  Future<void> setShowIcons(bool v) {
    state = state.copyWith(showIcons: v);
    return _save();
  }
}
