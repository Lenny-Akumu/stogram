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
