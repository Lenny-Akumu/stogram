import 'package:app/core/ayu/ayu_settings.dart';
import 'package:app/ui/theme/skin_provider.dart';
import 'package:app/ui/theme/skins.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every mockup design has a skin with a unique id', () {
    expect(skins, hasLength(22));
    expect(skins.map((s) => s.id).toSet(), hasLength(skins.length));
    for (final g in SkinGroup.values) {
      expect(skins.where((s) => s.group == g), isNotEmpty);
    }
    expect(skins.where((s) => s.group == SkinGroup.v4), hasLength(5));
  });

  test('unknown id falls back to classic night', () {
    expect(skinById('nope').id, 'classic-night');
    expect(skinById('hud').name, 'HUD');
  });

  test('selected skin survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    await c.read(skinProvider.notifier).select(skinById('riso'));
    c.dispose();

    final again = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(again.dispose);
    expect(again.read(skinProvider).id, 'riso');
  });

  test('themes build for every skin without fonts', () {
    for (final s in skins) {
      expect(
        buildSkinTheme(
          Skin(
            id: s.id,
            name: s.name,
            group: s.group,
            dark: s.dark,
            colors: s.colors,
          ),
        ).extensions.values,
        isNotEmpty,
      );
    }
  });
}
