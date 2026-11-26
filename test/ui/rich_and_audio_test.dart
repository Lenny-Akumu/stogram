import 'package:app/app/app.dart';
import 'package:app/core/l10n/l10n.dart';
import 'package:app/core/media/audio_playback.dart';
import 'package:app/data/messages/rich_text.dart';
import 'package:app/ui/components/audio_bar.dart';
import 'package:app/ui/components/rich_message_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

class _Playing extends AudioPlayback {
  @override
  AudioState build() => const AudioState(
    fileId: 1,
    label: 'Голосове',
    playing: true,
    position: Duration(seconds: 5),
    duration: Duration(seconds: 20),
  );

  @override
  Future<void> nextRate() async =>
      state = state.copyWith(rate: state.rate == 1 ? 1.5 : 2);

  @override
  Future<void> stop() async => state = const AudioState();
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('uk'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('links render as separate tappable spans', (t) async {
    await t.pumpWidget(
      _wrap(
        const RichMessageText(
          text: 'go example.com now',
          spans: [TextSpanInfo(3, 11, SpanKind.url)],
          style: TextStyle(),
          linkColor: Colors.blue,
        ),
      ),
    );
    final rich = t.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final parts = rich.children!.cast<TextSpan>();
    expect(parts.map((p) => p.text), ['go ', 'example.com', ' now']);
    expect(parts[1].recognizer, isNotNull);
    expect(parts[1].style?.color, Colors.blue);
  });

  testWidgets('link preview card shows site, title and description', (t) async {
    await t.pumpWidget(
      _wrap(
        const LinkPreviewCard(
          preview: LinkPreviewData(
            url: 'https://x.ua',
            siteName: 'X',
            title: 'Новина',
            description: 'Опис',
          ),
          accent: Colors.blue,
          textColor: Colors.white,
          maxWidth: 300,
        ),
      ),
    );
    expect(find.text('X'), findsOneWidget);
    expect(find.text('Новина'), findsOneWidget);
    expect(find.text('Опис'), findsOneWidget);
  });

  testWidgets('audio bar shows track, cycles speed and closes', (t) async {
    await t.pumpWidget(
      _wrap(
        const AudioBar(),
        overrides: [audioPlaybackProvider.overrideWith(_Playing.new)],
      ),
    );
    expect(find.text('Голосове'), findsOneWidget);
    expect(find.text('0:05 / 0:20'), findsOneWidget);
    expect(find.text('1×'), findsOneWidget);

    await t.tap(find.text('1×'));
    await t.pump();
    expect(find.text('1.5×'), findsOneWidget);

    await t.tap(find.byIcon(Icons.close));
    await t.pump();
    expect(find.text('Голосове'), findsNothing);
  });
}
