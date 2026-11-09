import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AyuSettings {
  const AyuSettings({
    this.ghostMode = false,
    this.saveDeleted = true,
    this.editHistory = true,
    this.readSilentlyOnReply = true,
  });

  final bool ghostMode;
  final bool saveDeleted;
  final bool editHistory;

  /// In ghost mode, replying still leaves the chat unread for the sender.
  final bool readSilentlyOnReply;

  bool get archives => saveDeleted || editHistory;

  AyuSettings copyWith({
    bool? ghostMode,
    bool? saveDeleted,
    bool? editHistory,
    bool? readSilentlyOnReply,
  }) => AyuSettings(
    ghostMode: ghostMode ?? this.ghostMode,
    saveDeleted: saveDeleted ?? this.saveDeleted,
    editHistory: editHistory ?? this.editHistory,
    readSilentlyOnReply: readSilentlyOnReply ?? this.readSilentlyOnReply,
  );
}

/// Null in tests; main overrides it with the real instance.
final sharedPrefsProvider = Provider<SharedPreferences?>((_) => null);

final ayuSettingsProvider = NotifierProvider<AyuSettingsNotifier, AyuSettings>(
  AyuSettingsNotifier.new,
);

class AyuSettingsNotifier extends Notifier<AyuSettings> {
  static const _ghost = 'ayu.ghost';
  static const _deleted = 'ayu.saveDeleted';
  static const _edits = 'ayu.editHistory';
  static const _silent = 'ayu.readSilentlyOnReply';

  SharedPreferences? get _prefs => ref.read(sharedPrefsProvider);

  @override
  AyuSettings build() {
    final p = ref.watch(sharedPrefsProvider);
    if (p == null) return const AyuSettings();
    return AyuSettings(
      ghostMode: p.getBool(_ghost) ?? false,
      saveDeleted: p.getBool(_deleted) ?? true,
      editHistory: p.getBool(_edits) ?? true,
      readSilentlyOnReply: p.getBool(_silent) ?? true,
    );
  }

  Future<void> setGhostMode(bool v) async {
    state = state.copyWith(ghostMode: v);
    await _prefs?.setBool(_ghost, v);
  }

  Future<void> setSaveDeleted(bool v) async {
    state = state.copyWith(saveDeleted: v);
    await _prefs?.setBool(_deleted, v);
  }

  Future<void> setEditHistory(bool v) async {
    state = state.copyWith(editHistory: v);
    await _prefs?.setBool(_edits, v);
  }

  Future<void> setReadSilentlyOnReply(bool v) async {
    state = state.copyWith(readSilentlyOnReply: v);
    await _prefs?.setBool(_silent, v);
  }
}
