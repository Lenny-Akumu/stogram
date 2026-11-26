import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ayu/ayu_settings.dart';

class AppPrefs {
  const AppPrefs({
    this.language = 'uk',
    this.sendWithEnter = true,
    this.textScale = 1,
  });

  /// 'uk', 'en' or 'system'.
  final String language;
  final bool sendWithEnter;
  final double textScale;

  Locale? get locale => language == 'system' ? null : Locale(language);

  AppPrefs copyWith({
    String? language,
    bool? sendWithEnter,
    double? textScale,
  }) => AppPrefs(
    language: language ?? this.language,
    sendWithEnter: sendWithEnter ?? this.sendWithEnter,
    textScale: textScale ?? this.textScale,
  );
}

final appPrefsProvider = NotifierProvider<AppPrefsNotifier, AppPrefs>(
  AppPrefsNotifier.new,
);

class AppPrefsNotifier extends Notifier<AppPrefs> {
  static const _lang = 'app.language';
  static const _enter = 'app.sendWithEnter';
  static const _scale = 'app.textScale';

  @override
  AppPrefs build() {
    final p = ref.watch(sharedPrefsProvider);
    if (p == null) return const AppPrefs();
    return AppPrefs(
      language: p.getString(_lang) ?? 'uk',
      sendWithEnter: p.getBool(_enter) ?? true,
      textScale: p.getDouble(_scale) ?? 1,
    );
  }

  Future<void> setLanguage(String v) async {
    state = state.copyWith(language: v);
    await ref.read(sharedPrefsProvider)?.setString(_lang, v);
  }

  Future<void> setSendWithEnter(bool v) async {
    state = state.copyWith(sendWithEnter: v);
    await ref.read(sharedPrefsProvider)?.setBool(_enter, v);
  }

  void previewTextScale(double v) => state = state.copyWith(textScale: v);

  Future<void> setTextScale(double v) async {
    state = state.copyWith(textScale: v);
    await ref.read(sharedPrefsProvider)?.setDouble(_scale, v);
  }
}
