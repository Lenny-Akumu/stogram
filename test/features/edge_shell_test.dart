import 'package:app/app/app.dart';
import 'package:app/app/providers.dart';
import 'package:app/core/l10n/l10n.dart';
import 'package:app/ui/shell/edge_panels.dart';
import 'package:app/ui/shell/edge_shell.dart';
import 'package:app/ui/shell/shell_switch.dart';
import 'package:app/ui/theme/skin_provider.dart';
import 'package:app/ui/theme/skins.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_td.dart';

class _Monolith extends SkinSetting {
  @override
  Skin build() => skinById('monolith');
}

Map<String, dynamic> _chat(int id, String title, {int unread = 0}) => {
  '@type': 'updateNewChat',
  'chat': {
    'id': id,
    'title': title,
    'unread_count': unread,
    'positions': [
      {
        'list': {'@type': 'chatListMain'},
        'order': '${100 - id}',
      },
    ],
  },
};

Future<FakeTd> _pump(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final td = FakeTd()..handler = (_) => {'messages': <Object>[]};
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        tdApiProvider.overrideWithValue(td),
        skinProvider.overrideWith(_Monolith.new),
      ],
      child: const MaterialApp(
        locale: Locale('uk'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: ShellSwitch(),
      ),
    ),
  );
  td
    ..push(_chat(1, 'Софія', unread: 2))
    ..push(_chat(2, 'Марко'));
  await t.pumpAndSettle();
  return td;
}

double _panelX(WidgetTester t) {
  final f = find.byType(EdgePanelView);
  if (f.evaluate().isEmpty) return -1;
  return t.getTopLeft(f.first).dx;
}

String _shown(WidgetTester t) =>
    t.widget<EdgePanelView>(find.byType(EdgePanelView).first).panel.name;

void main() {
  testWidgets('edge skins use the edge shell', (t) async {
    await _pump(t, const Size(1400, 900));
    expect(find.byType(EdgeShell), findsOneWidget);
  });

  testWidgets('hovering a tab opens its panel, leaving closes', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await _pump(t, const Size(1400, 900));
    expect(_panelX(t), lessThan(0));
    final l10n = await AppLocalizations.delegate.load(const Locale('uk'));

    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(700, 450));
    await t.pump();
    await mouse.moveTo(t.getCenter(find.byTooltip(l10n.chatsTitle).first));
    await t.pumpAndSettle();
    expect(_panelX(t), greaterThanOrEqualTo(0));
    expect(_shown(t), 'chats');
    expect(find.text('Софія'), findsWidgets);

    await mouse.moveTo(const Offset(1200, 450));
    await t.pumpAndSettle();
    expect(_panelX(t), lessThan(0));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('phone swipe opens the first tab, scrim tap closes', (t) async {
    await _pump(t, const Size(400, 800));
    await t.dragFrom(const Offset(4, 400), const Offset(260, 0));
    await t.pumpAndSettle();
    expect(_panelX(t), greaterThanOrEqualTo(0));
    expect(_shown(t), 'search');

    await t.tapAt(const Offset(345, 400));
    await t.pumpAndSettle();
    expect(_panelX(t), lessThan(0));
  });

  testWidgets('pinned panel stays, another tab replaces it for a while', (
    t,
  ) async {
    await _pump(t, const Size(1400, 900));
    final l10n = await AppLocalizations.delegate.load(const Locale('uk'));
    await t.tap(find.byTooltip(l10n.chatsTitle).first);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip(l10n.panelPin));
    await t.pumpAndSettle();

    await t.tapAt(const Offset(1000, 450));
    await t.pumpAndSettle();
    expect(_shown(t), 'chats');

    await t.tap(find.byTooltip(l10n.menuAyu).first);
    await t.pumpAndSettle();
    expect(_shown(t), 'ayu');

    await t.tap(find.byTooltip(l10n.menuAyu).first);
    await t.pumpAndSettle();
    await t.tapAt(const Offset(1000, 450));
    await t.pumpAndSettle();
    expect(_shown(t), 'chats');
  });

  testWidgets('layout override puts a classic skin into the edge shell', (
    t,
  ) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          tdApiProvider.overrideWithValue(FakeTd()),
          layoutModeProvider.overrideWith(_ForceEdge.new),
        ],
        child: const MaterialApp(
          locale: Locale('uk'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          home: ShellSwitch(),
        ),
      ),
    );
    await t.pump();
    expect(find.byType(EdgeShell), findsOneWidget);
  });
}

class _ForceEdge extends LayoutSetting {
  @override
  LayoutMode build() => LayoutMode.edge;
}
