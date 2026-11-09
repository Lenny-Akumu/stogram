import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'chat_colors.dart';

enum SkinGroup { classic, v4, v3, v2, v1 }

class Skin {
  const Skin({
    required this.id,
    required this.name,
    required this.group,
    required this.dark,
    required this.colors,
    this.font,
  });

  final String id;
  final String name;
  final SkinGroup group;
  final bool dark;
  final ChatColors colors;

  /// Google Fonts family, null keeps the platform font.
  final String? font;
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// Fills in panel and bubble shades from the few tokens each mockup defines.
ChatColors _derive({
  required Color bg,
  required Color text,
  required Color secondary,
  required Color accent,
  Color? panel,
  Color? bubbleIn,
  Color? bubbleOut,
  Color? textOut,
  Color? deleted,
  required bool dark,
}) {
  final p = panel ?? _mix(bg, text, dark ? 0.06 : 0.03);
  final out = bubbleOut ?? _mix(bg, accent, dark ? 0.35 : 0.22);
  return ChatColors(
    chatBackground: bg,
    panel: p,
    bubbleIn: bubbleIn ?? _mix(bg, text, dark ? 0.10 : 0.06),
    bubbleOut: out,
    textIn: text,
    textOut: textOut ?? text,
    metaIn: secondary,
    metaOut: _mix(textOut ?? text, out, 0.4),
    accent: accent,
    secondary: secondary,
    selected: accent,
    unread: accent,
    unreadMuted: secondary,
    divider: _mix(p, text, 0.08),
    deleted: deleted ?? const Color(0xFFE25B5B),
  );
}

final skins = <Skin>[
  const Skin(
    id: 'classic-night',
    name: 'Класичний нічний',
    group: SkinGroup.classic,
    dark: true,
    colors: ChatColors.night,
  ),
  const Skin(
    id: 'classic-day',
    name: 'Класичний денний',
    group: SkinGroup.classic,
    dark: false,
    colors: ChatColors.day,
  ),
  Skin(
    id: 'monolith',
    name: 'Monolith',
    group: SkinGroup.v4,
    dark: true,
    font: 'Hanken Grotesk',
    colors: _derive(
      bg: const Color(0xFF000000),
      text: const Color(0xFFFFFFFF),
      secondary: const Color(0xFF8E8E8E),
      accent: const Color(0xFFFF453A),
      panel: const Color(0xFF000000),
      bubbleIn: const Color(0xFF262626),
      bubbleOut: const Color(0xFF2E2E2E),
      textOut: const Color(0xFFA8A8A8),
      deleted: const Color(0xFFFF453A),
      dark: true,
    ),
  ),
  Skin(
    id: 'softkeys',
    name: 'Soft Keys',
    group: SkinGroup.v4,
    dark: false,
    font: 'Figtree',
    colors: _derive(
      bg: const Color(0xFFE9ECF1),
      text: const Color(0xFF1C1F26),
      secondary: const Color(0xFF545A68),
      accent: const Color(0xFFFFB800),
      panel: const Color(0xFFE9ECF1),
      bubbleIn: const Color(0xFFF4F6F9),
      bubbleOut: const Color(0xFF1C1F26),
      textOut: const Color(0xFFFFFFFF),
      dark: false,
    ),
  ),
  Skin(
    id: 'hud',
    name: 'HUD',
    group: SkinGroup.v4,
    dark: true,
    font: 'Chakra Petch',
    colors: _derive(
      bg: const Color(0xFF07070C),
      text: const Color(0xFFE8E8EE),
      secondary: const Color(0xFF9393A6),
      accent: const Color(0xFFFF3DAA),
      panel: const Color(0xFF11111C),
      bubbleIn: const Color(0xFF13131F),
      bubbleOut: const Color(0xFF3A0F2A),
      deleted: const Color(0xFFFFC24B),
      dark: true,
    ),
  ),
  Skin(
    id: 'glass',
    name: 'Liquid Glass',
    group: SkinGroup.v4,
    dark: false,
    font: 'Outfit',
    colors: _derive(
      bg: const Color(0xFFF1ECE6),
      text: const Color(0xFF17171A),
      secondary: const Color(0xFF45454C),
      accent: const Color(0xFF2BB3A3),
      bubbleIn: const Color(0x70FFFFFF),
      bubbleOut: const Color(0xCC17171A),
      textOut: const Color(0xFFFFFFFF),
      dark: false,
    ),
  ),
  Skin(
    id: 'riso',
    name: 'Riso Tickets',
    group: SkinGroup.v4,
    dark: false,
    font: 'Work Sans',
    colors: _derive(
      bg: const Color(0xFFF3F3EE),
      text: const Color(0xFF1D2340),
      secondary: const Color(0xFF0078BF),
      accent: const Color(0xFFFF48B0),
      bubbleIn: const Color(0xFFFFFFFF),
      bubbleOut: const Color(0xFFFF48B0),
      textOut: const Color(0xFFFFFFFF),
      deleted: const Color(0xFFFF48B0),
      dark: false,
    ),
  ),
  Skin(
    id: 'edge',
    name: 'Edge',
    group: SkinGroup.v3,
    dark: true,
    font: 'Inter',
    colors: _derive(
      bg: const Color(0xFF0B0C0F),
      text: const Color(0xFFEDEEF0),
      secondary: const Color(0xFF8A8F98),
      accent: const Color(0xFF8AF0C8),
      textOut: const Color(0xFFEDEEF0),
      dark: true,
    ),
  ),
  Skin(
    id: 'spines',
    name: 'Spines',
    group: SkinGroup.v3,
    dark: false,
    font: 'Familjen Grotesk',
    colors: _derive(
      bg: const Color(0xFFF4F3EF),
      text: const Color(0xFF17171A),
      secondary: const Color(0xFF6B6B70),
      accent: const Color(0xFFF6C445),
      bubbleOut: const Color(0xFF9AD1F5),
      dark: false,
    ),
  ),
  Skin(
    id: 'rail',
    name: 'Rail',
    group: SkinGroup.v3,
    dark: true,
    font: 'DM Sans',
    colors: _derive(
      bg: const Color(0xFF0A0F1A),
      text: const Color(0xFFE6ECF5),
      secondary: const Color(0xFF8FB3FF),
      accent: const Color(0xFF3DDBD9),
      deleted: const Color(0xFFF2B84B),
      dark: true,
    ),
  ),
  Skin(
    id: 'halo',
    name: 'Halo',
    group: SkinGroup.v3,
    dark: false,
    font: 'Inter',
    colors: _derive(
      bg: const Color(0xFFFAFAF8),
      text: const Color(0xFF141414),
      secondary: const Color(0xFF6B6B6B),
      accent: const Color(0xFF4A8BFF),
      bubbleIn: const Color(0xFFFAFAF8),
      dark: false,
    ),
  ),
  Skin(
    id: 'dock',
    name: 'Dock',
    group: SkinGroup.v3,
    dark: true,
    font: 'Onest',
    colors: _derive(
      bg: const Color(0xFF121212),
      text: const Color(0xFFEDEDED),
      secondary: const Color(0xFF8C8C8C),
      accent: const Color(0xFF3D7BFF),
      dark: true,
    ),
  ),
  Skin(
    id: 'stage',
    name: 'Stage',
    group: SkinGroup.v2,
    dark: true,
    font: 'Bricolage Grotesque',
    colors: _derive(
      bg: const Color(0xFF0E0E12),
      text: const Color(0xFFF0EEEA),
      secondary: const Color(0xFF8E8C94),
      accent: const Color(0xFFFF7A45),
      dark: true,
    ),
  ),
  Skin(
    id: 'deck',
    name: 'Deck',
    group: SkinGroup.v2,
    dark: false,
    font: 'Inter',
    colors: _derive(
      bg: const Color(0xFFE7E6E1),
      text: const Color(0xFF17171A),
      secondary: const Color(0xFF66655F),
      accent: const Color(0xFF0050F0),
      bubbleIn: const Color(0xFFF5F4F0),
      bubbleOut: const Color(0xFF0050F0),
      textOut: const Color(0xFFFFFFFF),
      dark: false,
    ),
  ),
  Skin(
    id: 'feed',
    name: 'Feed',
    group: SkinGroup.v2,
    dark: true,
    font: 'IBM Plex Sans',
    colors: _derive(
      bg: const Color(0xFF101418),
      text: const Color(0xFFE8EAED),
      secondary: const Color(0xFF8A939C),
      accent: const Color(0xFFF2C94C),
      dark: true,
    ),
  ),
  Skin(
    id: 'bento',
    name: 'Bento',
    group: SkinGroup.v2,
    dark: false,
    font: 'Manrope',
    colors: _derive(
      bg: const Color(0xFFEEF0F3),
      text: const Color(0xFF15151A),
      secondary: const Color(0xFF5E6068),
      accent: const Color(0xFF15151A),
      bubbleIn: const Color(0xFFC8F2DA),
      bubbleOut: const Color(0xFFDCD3FF),
      dark: false,
    ),
  ),
  Skin(
    id: 'editorial',
    name: 'Editorial',
    group: SkinGroup.v2,
    dark: false,
    font: 'Archivo',
    colors: _derive(
      bg: const Color(0xFFFFFFFF),
      text: const Color(0xFF000000),
      secondary: const Color(0xFF555555),
      accent: const Color(0xFFD40000),
      bubbleIn: const Color(0xFFF2F2F2),
      bubbleOut: const Color(0xFF000000),
      textOut: const Color(0xFFFFFFFF),
      deleted: const Color(0xFFD40000),
      dark: false,
    ),
  ),
  Skin(
    id: 'void',
    name: 'Void',
    group: SkinGroup.v1,
    dark: true,
    font: 'Inter',
    colors: _derive(
      bg: const Color(0xFF000000),
      text: const Color(0xFFF2F2F2),
      secondary: const Color(0xFF8A8A8A),
      accent: const Color(0xFFC6F432),
      bubbleOut: const Color(0xFFC6F432),
      textOut: const Color(0xFF000000),
      dark: true,
    ),
  ),
  Skin(
    id: 'nord',
    name: 'Glass Nord',
    group: SkinGroup.v1,
    dark: true,
    font: 'Manrope',
    colors: _derive(
      bg: const Color(0xFF0F141B),
      text: const Color(0xFFE6EDF5),
      secondary: const Color(0xFF8592A3),
      accent: const Color(0xFF6FB2FF),
      dark: true,
    ),
  ),
  Skin(
    id: 'paper',
    name: 'Paper',
    group: SkinGroup.v1,
    dark: false,
    font: 'Instrument Sans',
    colors: _derive(
      bg: const Color(0xFFF4F2EE),
      text: const Color(0xFF1A1A1A),
      secondary: const Color(0xFF6E6A63),
      accent: const Color(0xFF2F5BEA),
      bubbleIn: const Color(0xFFFFFFFF),
      bubbleOut: const Color(0xFF2F5BEA),
      textOut: const Color(0xFFFFFFFF),
      dark: false,
    ),
  ),
  Skin(
    id: 'terminal',
    name: 'Terminal',
    group: SkinGroup.v1,
    dark: true,
    font: 'JetBrains Mono',
    colors: _derive(
      bg: const Color(0xFF0A0D0A),
      text: const Color(0xFFB8F5C4),
      secondary: const Color(0xFF5E8A66),
      accent: const Color(0xFF4BE36B),
      dark: true,
    ),
  ),
  Skin(
    id: 'brutal',
    name: 'Neo-Brutal',
    group: SkinGroup.v1,
    dark: false,
    font: 'Space Grotesk',
    colors: _derive(
      bg: const Color(0xFFFFF7D6),
      text: const Color(0xFF000000),
      secondary: const Color(0xFF4A4A4A),
      accent: const Color(0xFF000000),
      bubbleIn: const Color(0xFFFFFFFF),
      bubbleOut: const Color(0xFFFFD400),
      dark: false,
    ),
  ),
];

Skin skinById(String? id) =>
    skins.firstWhere((s) => s.id == id, orElse: () => skins.first);

ThemeData buildSkinTheme(Skin skin) {
  final c = skin.colors;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: skin.dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: c.accent,
        onPrimary: c.accent.computeLuminance() > 0.5
            ? Colors.black
            : Colors.white,
        surface: c.panel,
        onSurface: c.textIn,
        onSurfaceVariant: c.secondary,
        surfaceContainerHighest: c.bubbleIn,
        outline: c.divider,
        error: c.deleted,
      );
  final base = ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: c.panel,
    dividerColor: c.divider,
    appBarTheme: AppBarTheme(
      backgroundColor: c.panel,
      foregroundColor: c.textIn,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    drawerTheme: DrawerThemeData(backgroundColor: c.panel),
    extensions: [c],
  );
  final font = skin.font;
  if (font == null) return base;
  try {
    return base.copyWith(
      textTheme: GoogleFonts.getTextTheme(font, base.textTheme),
    );
  } on Exception {
    return base;
  }
}
