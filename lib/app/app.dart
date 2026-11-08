import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n.dart';
import 'router.dart';
import 'theme.dart';

const _delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: buildBaseTheme(),
      localizationsDelegates: _delegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('uk'),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class FatalApp extends StatelessWidget {
  const FatalApp({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildBaseTheme(),
      localizationsDelegates: _delegates,
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
