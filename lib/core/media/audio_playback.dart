import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

class AudioState {
  const AudioState({
    this.fileId,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final int? fileId;
  final bool playing;
  final Duration position;
  final Duration duration;

  double get progress => duration.inMilliseconds == 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);

  AudioState copyWith({
    bool? playing,
    Duration? position,
    Duration? duration,
  }) => AudioState(
    fileId: fileId,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
  );
}

final audioPlaybackProvider = NotifierProvider<AudioPlayback, AudioState>(
  AudioPlayback.new,
);

/// One shared player for voice notes and music, like the official apps.
class AudioPlayback extends Notifier<AudioState> {
  Player? _player;
  final _subs = <StreamSubscription<Object?>>[];

  @override
  AudioState build() {
    ref.onDispose(() {
      for (final s in _subs) {
        unawaited(s.cancel());
      }
      unawaited(_player?.dispose());
    });
    return const AudioState();
  }

  Player _create() {
    final p = Player();
    _subs
      ..add(p.stream.playing.listen((v) => state = state.copyWith(playing: v)))
      ..add(
        p.stream.position.listen((v) => state = state.copyWith(position: v)),
      )
      ..add(
        p.stream.duration.listen((v) => state = state.copyWith(duration: v)),
      )
      ..add(
        p.stream.completed.listen((done) {
          if (done) state = const AudioState();
        }),
      );
    return p;
  }

  Future<void> toggle(int fileId, String path) async {
    final p = _player ??= _create();
    if (state.fileId == fileId) {
      await p.playOrPause();
      return;
    }
    state = AudioState(fileId: fileId, playing: true);
    await p.open(Media(Uri.file(path).toString()));
  }

  Future<void> seek(double fraction) async {
    final p = _player;
    if (p == null || state.duration == Duration.zero) return;
    await p.seek(state.duration * fraction);
  }
}
