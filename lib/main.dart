import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/ayu/ayu_settings.dart';
import 'core/config.dart';
import 'core/db/app_db.dart';
import 'core/tdlib/td_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final TdClient td;
  try {
    td = await TdClient.start(libPath: Env.tdjsonPath);
  } catch (e) {
    runApp(FatalApp(error: '$e'));
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        tdApiProvider.overrideWithValue(td),
        sharedPrefsProvider.overrideWithValue(prefs),
        appDbProvider.overrideWithValue(AppDb()),
      ],
      child: const App(),
    ),
  );
}
