import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ayu/ayu_settings.dart';
import 'skins.dart';

final skinProvider = NotifierProvider<SkinSetting, Skin>(SkinSetting.new);

class SkinSetting extends Notifier<Skin> {
  static const _key = 'look.skin';

  @override
  Skin build() => skinById(ref.watch(sharedPrefsProvider)?.getString(_key));

  Future<void> select(Skin skin) async {
    state = skin;
    await ref.read(sharedPrefsProvider)?.setString(_key, skin.id);
  }
}

enum LayoutMode { auto, classic, edge }

final layoutModeProvider = NotifierProvider<LayoutSetting, LayoutMode>(
  LayoutSetting.new,
);

class LayoutSetting extends Notifier<LayoutMode> {
  static const _key = 'look.layout';

  @override
  LayoutMode build() {
    final saved = ref.watch(sharedPrefsProvider)?.getString(_key);
    return LayoutMode.values.where((m) => m.name == saved).firstOrNull ??
        LayoutMode.auto;
  }

  Future<void> select(LayoutMode mode) async {
    state = mode;
    await ref.read(sharedPrefsProvider)?.setString(_key, mode.name);
  }
}

/// Layout actually used: the user's choice, or what the skin asks for.
final effectiveLayoutProvider = Provider<SkinLayout>((ref) {
  return switch (ref.watch(layoutModeProvider)) {
    LayoutMode.classic => SkinLayout.classic,
    LayoutMode.edge => SkinLayout.edge,
    LayoutMode.auto => ref.watch(skinProvider).layout,
  };
});
