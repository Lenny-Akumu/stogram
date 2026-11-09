import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n.dart';
import '../ui/components/update_banner.dart';
import '../features/chat_list/app_drawer.dart';
import 'providers.dart';
import 'router.dart';
import '../ui/theme/chat_colors.dart';

const appLocalizationDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // subscribe before TDLib starts pushing updateNewChat
    ref
      ..watch(chatsRepositoryProvider)
      ..watch(usersRepositoryProvider)
      ..watch(filesRepositoryProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: buildClassicTheme(dark: false),
      darkTheme: buildClassicTheme(dark: true),
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: appLocalizationDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('uk'),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          UpdateGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

class FatalApp extends StatelessWidget {
  const FatalApp({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildClassicTheme(dark: true),
      localizationsDelegates: appLocalizationDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('uk'),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(context.l10n.tdlibMissing(error)),
            ),
          ),
        ),
      ),
    );
  }
}
