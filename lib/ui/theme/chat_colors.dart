import 'package:flutter/material.dart';

@immutable
class ChatColors extends ThemeExtension<ChatColors> {
  const ChatColors({
    required this.chatBackground,
    required this.panel,
    required this.bubbleIn,
    required this.bubbleOut,
    required this.textIn,
    required this.textOut,
    required this.metaIn,
    required this.metaOut,
    required this.accent,
    required this.secondary,
    required this.selected,
    required this.unread,
    required this.unreadMuted,
    required this.divider,
    required this.deleted,
  });

  final Color chatBackground;
  final Color panel;
  final Color bubbleIn;
  final Color bubbleOut;
  final Color textIn;
  final Color textOut;
  final Color metaIn;
  final Color metaOut;
  final Color accent;
  final Color secondary;
  final Color selected;
  final Color unread;
  final Color unreadMuted;
  final Color divider;
  final Color deleted;

  static ChatColors of(BuildContext context) =>
      Theme.of(context).extension<ChatColors>() ?? night;

  static const night = ChatColors(
    chatBackground: Color(0xFF0E1621),
    panel: Color(0xFF17212B),
    bubbleIn: Color(0xFF182533),
    bubbleOut: Color(0xFF2B5278),
    textIn: Color(0xFFF5F5F5),
    textOut: Color(0xFFF5F5F5),
    metaIn: Color(0xFF6D7F8F),
    metaOut: Color(0xFF7DA8D3),
    accent: Color(0xFF5288C1),
    secondary: Color(0xFF6D7F8F),
    selected: Color(0xFF2B5278),
    unread: Color(0xFF5288C1),
    unreadMuted: Color(0xFF3E546A),
    divider: Color(0xFF0B1118),
    deleted: Color(0xFFE25B5B),
  );

  static const day = ChatColors(
    chatBackground: Color(0xFFDCE6EE),
    panel: Color(0xFFFFFFFF),
    bubbleIn: Color(0xFFFFFFFF),
    bubbleOut: Color(0xFFEFFDDE),
    textIn: Color(0xFF000000),
    textOut: Color(0xFF000000),
    metaIn: Color(0xFFA0ACB6),
    metaOut: Color(0xFF6CB36A),
    accent: Color(0xFF3390EC),
    secondary: Color(0xFF707579),
    selected: Color(0xFF3390EC),
    unread: Color(0xFF3390EC),
    unreadMuted: Color(0xFFC4C9CC),
    divider: Color(0xFFE7E7E7),
    deleted: Color(0xFFE53935),
  );

  @override
  ChatColors copyWith() => this;

  @override
  ChatColors lerp(ChatColors? other, double t) =>
      t < 0.5 ? this : other ?? this;
}
