import 'package:app/app/app.dart';
import 'package:app/app/providers.dart';
import 'package:app/core/l10n/l10n.dart';
import 'package:app/data/messages/message_media.dart';
import 'package:app/features/chat/media_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_td.dart';

Widget _app(Widget child) => ProviderScope(
  overrides: [tdApiProvider.overrideWithValue(FakeTd())],
  child: MaterialApp(
    locale: const Locale('uk'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: appLocalizationDelegates,
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('voice note shows play button and duration', (t) async {
    await t.pumpWidget(
      _app(
        const MediaView(
          media: VoiceMedia(duration: 75, fileId: 1, waveform: [1, 31, 8]),
          maxWidth: 300,
        ),
      ),
    );
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.text('1:15'), findsOneWidget);
  });

  testWidgets('document shows name, size and download icon', (t) async {
    await t.pumpWidget(
      _app(
        const MediaView(
          media: DocumentMedia(fileId: 2, name: 'cv.pdf', size: 2048),
          maxWidth: 300,
        ),
      ),
    );
    expect(find.text('cv.pdf'), findsOneWidget);
    expect(find.text('2 KB'), findsOneWidget);
    expect(find.byIcon(Icons.download), findsOneWidget);
  });

  testWidgets('round video shows cover with play badge', (t) async {
    await t.pumpWidget(
      _app(
        const MediaView(
          media: VideoMedia(
            MediaImage(fileId: null),
            duration: 9,
            isRound: true,
            fileId: 3,
          ),
          maxWidth: 300,
        ),
      ),
    );
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.text('0:09'), findsOneWidget);
  });
}
