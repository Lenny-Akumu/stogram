import 'package:app/app/app.dart';
import 'package:app/app/providers.dart';
import 'package:app/core/l10n/l10n.dart';
import 'package:app/features/chat/chat_screen.dart';
import 'package:app/features/chat_list/chat_list_screen.dart';
import 'package:app/ui/shell/classic_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_td.dart';

Widget _app(Widget home) => ProviderScope(
  overrides: [
    tdApiProvider.overrideWithValue(
      FakeTd()..handler = (_) => {'messages': <Object>[]},
    ),
  ],
  child: MaterialApp(
    locale: const Locale('uk'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: appLocalizationDelegates,
    home: home,
  ),
);

void main() {
  testWidgets('wide screen shows list and chat side by side', (t) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const ClassicShell(chatId: 7)));
    await t.pump();
    expect(find.byType(ChatListPane), findsOneWidget);
    expect(find.byType(ChatScreen), findsOneWidget);
  });

  testWidgets('phone shows only the open chat', (t) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const ClassicShell(chatId: 7)));
    await t.pump();
    expect(find.byType(ChatListPane), findsNothing);
    expect(find.byType(ChatScreen), findsOneWidget);
  });

  testWidgets('wide screen without chat shows the hint', (t) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const ClassicShell()));
    await t.pump();
    final l10n = await AppLocalizations.delegate.load(const Locale('uk'));
    expect(find.text(l10n.selectChat), findsOneWidget);
  });
}
