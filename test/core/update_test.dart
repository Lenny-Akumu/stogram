import 'package:app/app/app.dart';
import 'package:app/core/l10n/l10n.dart';
import 'package:app/core/update/release.dart';
import 'package:app/core/update/update_controller.dart';
import 'package:app/core/update/updater.dart';
import 'package:app/ui/components/update_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _release(
  String tag,
  List<String> assets, {
  bool draft = false,
}) => {
  'tag_name': tag,
  'draft': draft,
  'assets': [
    for (final a in assets)
      {
        'name': a,
        'state': 'uploaded',
        'browser_download_url': 'https://x/$tag/$a',
        'size': 10,
      },
  ],
};

class FakeUpdater implements Updater {
  FakeUpdater(this.release);

  ReleaseInfo? release;
  final installed = <String>[];
  Object? installError;

  @override
  bool get supported => true;

  @override
  Future<ReleaseInfo?> latest() async => release;

  @override
  Future<String> download(
    ReleaseInfo r,
    void Function(double) onProgress,
  ) async {
    onProgress(0.5);
    onProgress(1);
    return '/tmp/${r.assetName}';
  }

  @override
  Future<void> install(String path) async {
    installed.add(path);
    if (installError != null) throw installError!;
  }
}

const _info = ReleaseInfo(
  tag: 'dev-new',
  assetUrl: 'https://x/a.apk',
  assetName: 'stogram.apk',
);

ProviderContainer _container(FakeUpdater u, {String tag = 'dev-old'}) =>
    ProviderContainer(
      overrides: [
        updaterProvider.overrideWithValue(u),
        currentTagProvider.overrideWithValue(tag),
      ],
    );

void main() {
  group('pickRelease', () {
    test('skips drafts and releases without this platform asset', () {
      final r = pickRelease([
        _release('dev-draft', ['stogram.apk'], draft: true),
        _release('dev-c', ['stogram-linux-x64.tar.gz']),
        _release('dev-b', ['stogram.apk', 'stogram-linux-x64.tar.gz']),
      ], 'stogram.apk');
      expect(r?.tag, 'dev-b');
      expect(r?.assetUrl, 'https://x/dev-b/stogram.apk');
    });

    test('same tag or local build is not an update', () {
      expect(isUpdate(_info, 'dev-new'), isFalse);
      expect(isUpdate(_info, ''), isFalse);
      expect(isUpdate(_info, 'dev-old'), isTrue);
      expect(isUpdate(null, 'dev-old'), isFalse);
    });
  });

  group('UpdateController', () {
    test('finds update, downloads and installs', () async {
      final u = FakeUpdater(_info);
      final c = _container(u);
      addTearDown(c.dispose);
      c.read(updateProvider);
      await pumpEventQueue();
      expect(c.read(updateProvider), isA<UpdateAvailable>());

      await c.read(updateProvider.notifier).start();
      expect(u.installed, ['/tmp/stogram.apk']);
      expect(c.read(updateProvider), isA<UpdateReady>());
    });

    test('missing install permission keeps the download for retry', () async {
      final u = FakeUpdater(_info)
        ..installError = const InstallPermissionRequired();
      final c = _container(u);
      addTearDown(c.dispose);
      c.read(updateProvider);
      await pumpEventQueue();
      await c.read(updateProvider.notifier).start();
      final s = c.read(updateProvider) as UpdateReady;
      expect(s.needsPermission, isTrue);

      u.installError = null;
      await c.read(updateProvider.notifier).start();
      expect(u.installed, hasLength(2));
    });

    test('no prompt when already on the latest build', () async {
      final c = _container(FakeUpdater(_info), tag: 'dev-new');
      addTearDown(c.dispose);
      c.read(updateProvider);
      await pumpEventQueue();
      expect(c.read(updateProvider), isA<UpdateIdle>());
    });

    test('dismiss hides the banner', () async {
      final c = _container(FakeUpdater(_info));
      addTearDown(c.dispose);
      c.read(updateProvider);
      await pumpEventQueue();
      c.read(updateProvider.notifier).dismiss();
      expect(c.read(updateProvider), isA<UpdateIdle>());
    });
  });

  testWidgets('banner shows the tag and starts the update', (t) async {
    final u = FakeUpdater(_info);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          updaterProvider.overrideWithValue(u),
          currentTagProvider.overrideWithValue('dev-old'),
        ],
        child: const MaterialApp(
          locale: Locale('uk'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          home: UpdateGate(child: Scaffold(body: Text('chats'))),
        ),
      ),
    );
    await t.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('uk'));

    expect(find.text(l10n.updateAvailable('dev-new')), findsOneWidget);
    expect(find.text('chats'), findsOneWidget);
    await t.tap(find.text(l10n.updateAction));
    await t.pumpAndSettle();
    expect(u.installed, isNotEmpty);
    expect(find.text(l10n.updateReady), findsOneWidget);
  });
}
