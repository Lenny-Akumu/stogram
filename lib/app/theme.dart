import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildBaseTheme() {
  const bg = Color(0xFF000000);
  const fg = Color(0xFFFFFFFF);
  const muted = Color(0xFF8E8E8E);
  const line = Color(0xFF262626);
  const accent = Color(0xFFFF453A);

  final base = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      surface: bg,
      onSurface: fg,
      primary: fg,
      onPrimary: bg,
      error: accent,
      outline: line,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      labelStyle: TextStyle(color: muted),
      hintStyle: TextStyle(color: muted),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: line)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg)),
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.hankenGroteskTextTheme(base.textTheme),
  );
}
