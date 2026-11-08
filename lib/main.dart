import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/config.dart';
import 'core/tdlib/td_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final TdClient td;
  try {
    td = await TdClient.start(libPath: Env.tdjsonPath);
  } catch (e) {
    runApp(FatalApp(error: '$e'));
    return;
  }
  runApp(
    ProviderScope(
      overrides: [tdClientProvider.overrideWithValue(td)],
      child: const App(),
    ),
  );
}
