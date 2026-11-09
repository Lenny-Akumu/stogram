import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:open_filex/open_filex.dart';

import '../../app/providers.dart';
import '../../core/l10n/l10n.dart';
import '../../core/media/audio_playback.dart';
import '../../core/tdlib/td_dispatcher.dart';
import '../../data/files/files_repository.dart';
import '../../data/messages/message_media.dart';
import '../../ui/components/td_image.dart';
import '../../ui/theme/chat_colors.dart';

class MediaView extends StatelessWidget {
  const MediaView({
    super.key,
    required this.media,
    required this.maxWidth,
    this.outgoing = false,
  });

  final MessageMedia media;
  final double maxWidth;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    return switch (media) {
      PhotoMedia(:final image) => GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PhotoViewer(image: image)),
        ),
        child: _Sized(image: image, maxWidth: maxWidth, child: TdImage(image)),
      ),
      StickerMedia(:final image, :final emoji, :final isStatic) =>
        isStatic || image.fileId != null
            ? SizedBox.square(
                dimension: 160,
                child: TdImage(image, fit: BoxFit.contain),
              )
            : Text(emoji, style: const TextStyle(fontSize: 64)),
      final VideoMedia v when v.isGif => _Sized(
        image: v.cover,
        maxWidth: maxWidth,
        child: _LoopingVideo(media: v),
      ),
      final VideoMedia v when v.isRound => _RoundVideo(media: v),
      final VideoMedia v => GestureDetector(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => VideoPage(media: v))),
        child: _Sized(
          image: v.cover,
          maxWidth: maxWidth,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TdImage(v.cover),
              const Center(child: _PlayBadge()),
              if (v.duration > 0)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: _Chip(text: formatDuration(v.duration)),
                ),
            ],
          ),
        ),
      ),
      final DocumentMedia d => _DocumentTile(media: d),
      final VoiceMedia v => _VoiceTile(media: v, outgoing: outgoing),
      final AudioMedia a => _AudioTile(media: a, outgoing: outgoing),
    };
  }
}

Future<TdFile?> _fetch(WidgetRef ref, int? id, TdObject? seed) async {
  if (id == null) return null;
  return ref.read(filesRepositoryProvider).fetch(id, seed: seed);
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.loading,
    required this.onTap,
    required this.color,
  });

  final bool playing;
  final bool loading;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                playing ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
      ),
    );
  }
}

mixin _Playable<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool loading = false;

  int? get playFileId;
  TdObject? get playSeed;

  Future<void> play() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final f = await _fetch(ref, playFileId, playSeed);
      if (f != null && mounted) {
        await ref.read(audioPlaybackProvider.notifier).toggle(f.id, f.path);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class _VoiceTile extends ConsumerStatefulWidget {
  const _VoiceTile({required this.media, required this.outgoing});

  final VoiceMedia media;
  final bool outgoing;

  @override
  ConsumerState<_VoiceTile> createState() => _VoiceTileState();
}

class _VoiceTileState extends ConsumerState<_VoiceTile>
    with _Playable<_VoiceTile> {
  @override
  int? get playFileId => widget.media.fileId;
  @override
  TdObject? get playSeed => widget.media.file;

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    final audio = ref.watch(audioPlaybackProvider);
    final mine = audio.fileId != null && audio.fileId == widget.media.fileId;
    final played = mine ? audio.progress : 0.0;
    final active = widget.outgoing ? Colors.white : colors.accent;
    final idle = active.withValues(alpha: 0.35);
    final seconds = mine && audio.position > Duration.zero
        ? audio.position.inSeconds
        : widget.media.duration;

    return SizedBox(
      width: 240,
      child: Row(
        children: [
          _PlayButton(
            playing: mine && audio.playing,
            loading: loading,
            onTap: play,
            color: widget.outgoing ? Colors.white24 : colors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTapDown: (d) {
                    if (!mine) return;
                    final box = context.findRenderObject() as RenderBox?;
                    final w = (box?.size.width ?? 240) - 54;
                    unawaited(
                      ref
                          .read(audioPlaybackProvider.notifier)
                          .seek((d.localPosition.dx / w).clamp(0, 1)),
                    );
                  },
                  child: SizedBox(
                    height: 24,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _WaveformPainter(
                        samples: widget.media.waveform,
                        progress: played,
                        active: active,
                        idle: idle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatDuration(seconds),
                  style: TextStyle(
                    fontSize: 12,
                    color: idle.withValues(alpha: 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.samples,
    required this.progress,
    required this.active,
    required this.idle,
  });

  final List<int> samples;
  final double progress;
  final Color active;
  final Color idle;

  @override
  void paint(Canvas canvas, Size size) {
    const bar = 3.0;
    const gap = 2.0;
    final count = (size.width / (bar + gap)).floor();
    if (count <= 0) return;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final v = samples.isEmpty
          ? 4
          : samples[(i * samples.length / count).floor()];
      final h = (v / 31 * size.height).clamp(2.0, size.height);
      final x = i * (bar + gap);
      paint.color = i / count <= progress ? active : idle;
      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          size.height - h,
          x + bar,
          size.height,
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.samples != samples;
}

class _AudioTile extends ConsumerStatefulWidget {
  const _AudioTile({required this.media, required this.outgoing});

  final AudioMedia media;
  final bool outgoing;

  @override
  ConsumerState<_AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends ConsumerState<_AudioTile>
    with _Playable<_AudioTile> {
  @override
  int? get playFileId => widget.media.fileId;
  @override
  TdObject? get playSeed => widget.media.file;

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    final audio = ref.watch(audioPlaybackProvider);
    final mine = audio.fileId == widget.media.fileId;
    return SizedBox(
      width: 260,
      child: Row(
        children: [
          _PlayButton(
            playing: mine && audio.playing,
            loading: loading,
            onTap: play,
            color: widget.outgoing ? Colors.white24 : colors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.media.title.isEmpty
                      ? context.l10n.previewAudio
                      : widget.media.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (mine)
                  LinearProgressIndicator(value: audio.progress, minHeight: 2)
                else
                  Text(
                    formatDuration(widget.media.duration),
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends ConsumerStatefulWidget {
  const _DocumentTile({required this.media});

  final DocumentMedia media;

  @override
  ConsumerState<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends ConsumerState<_DocumentTile> {
  StreamSubscription<TdFile>? _sub;
  TdFile? _file;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final files = ref.read(filesRepositoryProvider);
    files.seed(widget.media.file);
    _file = files.get(widget.media.fileId);
    _sub = files.watch(widget.media.fileId).listen((f) {
      if (mounted) setState(() => _file = f);
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final f = await _fetch(ref, widget.media.fileId, widget.media.file);
      if (f != null) await OpenFilex.open(f.path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    final f = _file;
    final ready = f?.ready ?? false;
    final downloading = _busy && !ready;
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 260,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
              child: downloading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        value: f == null || f.progress == 0 ? null : f.progress,
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      ready ? Icons.insert_drive_file : Icons.download,
                      color: Colors.white,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.media.name.isEmpty
                        ? context.l10n.previewDocument
                        : widget.media.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    downloading && f != null
                        ? '${formatSize(f.downloaded)} / ${formatSize(widget.media.size)}'
                        : formatSize(widget.media.size),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// GIFs: silent, looped, start as soon as the file is there.
class _LoopingVideo extends ConsumerStatefulWidget {
  const _LoopingVideo({required this.media});

  final VideoMedia media;

  @override
  ConsumerState<_LoopingVideo> createState() => _LoopingVideoState();
}

class _LoopingVideoState extends ConsumerState<_LoopingVideo> {
  Player? _player;
  VideoController? _controller;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final f = await _fetch(ref, widget.media.fileId, widget.media.file);
    if (f == null || !mounted) return;
    final p = Player();
    final c = VideoController(p);
    await p.setVolume(0);
    await p.setPlaylistMode(PlaylistMode.single);
    await p.open(Media(Uri.file(f.path).toString()));
    if (!mounted) {
      await p.dispose();
      return;
    }
    setState(() {
      _player = p;
      _controller = c;
    });
  }

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return TdImage(widget.media.cover);
    return Video(controller: c, controls: _noControls, fit: BoxFit.cover);
  }
}

class _RoundVideo extends ConsumerStatefulWidget {
  const _RoundVideo({required this.media});

  final VideoMedia media;

  @override
  ConsumerState<_RoundVideo> createState() => _RoundVideoState();
}

class _RoundVideoState extends ConsumerState<_RoundVideo> {
  Player? _player;
  VideoController? _controller;
  bool _loading = false;
  bool _playing = false;
  double _progress = 0;
  final _subs = <StreamSubscription<Object?>>[];

  Future<void> _toggle() async {
    final p = _player;
    if (p != null) {
      await p.playOrPause();
      return;
    }
    setState(() => _loading = true);
    final f = await _fetch(ref, widget.media.fileId, widget.media.file);
    if (f == null || !mounted) return;
    final player = Player();
    final c = VideoController(player);
    _subs
      ..add(
        player.stream.playing.listen((v) {
          if (mounted) setState(() => _playing = v);
        }),
      )
      ..add(
        player.stream.position.listen((pos) {
          final d = player.state.duration.inMilliseconds;
          if (mounted && d > 0) {
            setState(() => _progress = pos.inMilliseconds / d);
          }
        }),
      );
    await player.open(Media(Uri.file(f.path).toString()));
    if (!mounted) {
      await player.dispose();
      return;
    }
    setState(() {
      _player = player;
      _controller = c;
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    const size = 220.0;
    return GestureDetector(
      onTap: _toggle,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipOval(
              child: c == null
                  ? TdImage(widget.media.cover)
                  : Video(
                      controller: c,
                      controls: _noControls,
                      fit: BoxFit.cover,
                    ),
            ),
            if (c != null)
              CircularProgressIndicator(
                value: _progress,
                strokeWidth: 3,
                color: Colors.white70,
              ),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (!_playing)
              const Center(child: _PlayBadge()),
            Positioned(
              left: 12,
              bottom: 12,
              child: _Chip(text: formatDuration(widget.media.duration)),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPage extends ConsumerStatefulWidget {
  const VideoPage({super.key, required this.media});

  final VideoMedia media;

  @override
  ConsumerState<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<VideoPage> {
  Player? _player;
  VideoController? _controller;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final f = await _fetch(ref, widget.media.fileId, widget.media.file);
    if (f == null || !mounted) return;
    final p = Player();
    final c = VideoController(p);
    await p.open(Media(Uri.file(f.path).toString()));
    if (!mounted) {
      await p.dispose();
      return;
    }
    setState(() {
      _player = p;
      _controller = c;
    });
  }

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: c == null
            ? Stack(
                alignment: Alignment.center,
                children: [
                  TdImage(widget.media.cover, fit: BoxFit.contain),
                  const CircularProgressIndicator(),
                ],
              )
            : Video(controller: c),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: const BoxDecoration(
      color: Colors.black45,
      shape: BoxShape.circle,
    ),
    child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
  );
}

class _Sized extends StatelessWidget {
  const _Sized({
    required this.image,
    required this.maxWidth,
    required this.child,
  });

  final MediaImage image;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final aspect = image.aspect.clamp(0.5, 2.0);
    final width = maxWidth.clamp(120.0, 400.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: width, height: width / aspect, child: child),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 11),
    ),
  );
}

class PhotoViewer extends StatelessWidget {
  const PhotoViewer({super.key, required this.image});

  final MediaImage image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(child: TdImage(image, fit: BoxFit.contain)),
      ),
    );
  }
}

String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

Widget _noControls(VideoState _) => const SizedBox.shrink();
