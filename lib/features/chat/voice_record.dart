import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/l10n/l10n.dart';
import '../../core/settings/voice_prefs.dart';
import '../../core/voice/voice_fx.dart';
import '../../core/voice/voice_recorder.dart';
import '../../ui/theme/chat_colors.dart';

IconData effectIcon(VoiceEffect e) => switch (e) {
  VoiceEffect.none => Icons.block,
  VoiceEffect.chipmunk => Icons.pets,
  VoiceEffect.robot => Icons.smart_toy_outlined,
  VoiceEffect.stadium => Icons.stadium_outlined,
  VoiceEffect.demon => Icons.local_fire_department_outlined,
  VoiceEffect.autotune => Icons.graphic_eq,
  VoiceEffect.intercom => Icons.doorbell_outlined,
  VoiceEffect.karaoke => Icons.mic_external_on_outlined,
};

String effectName(BuildContext context, VoiceEffect e) {
  final l = context.l10n;
  return switch (e) {
    VoiceEffect.none => l.fxNone,
    VoiceEffect.chipmunk => l.fxChipmunk,
    VoiceEffect.robot => l.fxRobot,
    VoiceEffect.stadium => l.fxStadium,
    VoiceEffect.demon => l.fxDemon,
    VoiceEffect.autotune => l.fxAutotune,
    VoiceEffect.intercom => l.fxIntercom,
    VoiceEffect.karaoke => l.fxKaraoke,
  };
}

/// Replaces the composer while recording and previewing a voice note.
class VoiceComposer extends ConsumerStatefulWidget {
  const VoiceComposer({super.key, required this.onSend, required this.onClose});

  final Future<void> Function(EncodedVoice voice) onSend;
  final VoidCallback onClose;

  @override
  ConsumerState<VoiceComposer> createState() => _VoiceComposerState();
}

enum _Stage { recording, processing, preview }

class _VoiceComposerState extends ConsumerState<VoiceComposer> {
  final _rec = VoiceRecorder();
  var _stage = _Stage.recording;
  Timer? _tick;
  Int16List? _raw;
  EncodedVoice? _encoded;
  VoiceEffect _effect = VoiceEffect.none;
  bool _effectsOpen = false;
  Player? _player;
  final _subs = <StreamSubscription<Object?>>[];
  bool _playing = false;
  double _progress = 0;
  int _job = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final prefs = ref.read(voicePrefsProvider);
    bool ok;
    try {
      ok = await _rec.start(
        echoCancel: prefs.echoCancel,
        autoGain: prefs.autoGain,
      );
    } on Object {
      ok = false;
    }
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.voiceNoMic)));
      widget.onClose();
      return;
    }
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
      if (_rec.elapsed.inMinutes >= 30) unawaited(_stop());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(_player?.dispose());
    if (_stage == _Stage.recording) unawaited(_rec.cancel());
    unawaited(_rec.dispose());
    final path = _encoded?.path;
    if (path != null) unawaited(_delete(path));
    super.dispose();
  }

  static Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      return;
    }
  }

  Future<void> _stop() async {
    if (_stage != _Stage.recording) return;
    _tick?.cancel();
    final raw = await _rec.stop();
    if (!mounted) return;
    if (raw.length < 48000 ~/ 2) {
      widget.onClose();
      return;
    }
    _raw = raw;
    await _process();
  }

  Future<void> _process() async {
    final raw = _raw;
    if (raw == null) return;
    final job = ++_job;
    setState(() => _stage = _Stage.processing);
    await _player?.stop();
    final old = _encoded?.path;
    try {
      final enc = await encodeVoice(
        VoiceJob(raw, _effect, ref.read(voicePrefsProvider).denoiseLevel),
      );
      if (!mounted || job != _job) return;
      _encoded = enc;
      if (old != null) unawaited(_delete(old));
      setState(() {
        _stage = _Stage.preview;
        _progress = 0;
      });
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.voiceEncodeError('$e'))),
      );
      widget.onClose();
    }
  }

  Future<void> _togglePlay() async {
    final enc = _encoded;
    if (enc == null) return;
    var p = _player;
    if (p == null) {
      p = _player = Player();
      _subs
        ..add(p.stream.playing.listen((v) => setState(() => _playing = v)))
        ..add(
          p.stream.position.listen((pos) {
            final d = p!.state.duration.inMilliseconds;
            if (d > 0) {
              setState(() => _progress = pos.inMilliseconds / d);
            }
          }),
        )
        ..add(
          p.stream.completed.listen((done) {
            if (done) setState(() => _progress = 0);
          }),
        );
    }
    if (_playing) {
      await p.pause();
      return;
    }
    if (p.state.playlist.medias.firstOrNull?.uri !=
        Uri.file(enc.path).toString()) {
      await p.open(Media(Uri.file(enc.path).toString()));
    } else {
      await p.play();
    }
  }

  void _pick(VoiceEffect e) {
    if (e == _effect) return;
    setState(() => _effect = e);
    unawaited(_process());
  }

  Future<void> _send() async {
    if (_stage == _Stage.recording) {
      await _stop();
      if (!mounted || _stage == _Stage.recording) return;
    }
    while (_stage == _Stage.processing && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final enc = _encoded;
    if (enc == null || !mounted) return;
    await _player?.stop();
    _encoded = null;
    widget.onClose();
    await widget.onSend(enc);
  }

  String _time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    final recording = _stage == _Stage.recording;
    return Material(
      color: colors.panel,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_effectsOpen && !recording) _effectsGrid(context, colors),
            if (!recording)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
                  child: Material(
                    color: colors.chatBackground,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _effectsOpen = !_effectsOpen),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.fxChange,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _effect == VoiceEffect.none
                                  ? l10n.fxNoEffect
                                  : effectName(context, _effect),
                              style: TextStyle(color: colors.secondary),
                            ),
                            Icon(
                              _effectsOpen
                                  ? Icons.expand_more
                                  : Icons.expand_less,
                              color: colors.secondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.actionDelete,
                    icon: Icon(Icons.delete_outline, color: colors.deleted),
                    onPressed: widget.onClose,
                  ),
                  Expanded(child: _track(colors, recording)),
                  const SizedBox(width: 6),
                  if (recording)
                    IconButton(
                      tooltip: l10n.voiceStop,
                      icon: Icon(Icons.stop_circle, color: colors.deleted),
                      onPressed: _stop,
                    ),
                  IconButton(
                    tooltip: l10n.actionSend,
                    color: colors.accent,
                    onPressed: _stage == _Stage.processing ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _track(ChatColors colors, bool recording) {
    final levels = _rec.levels;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: colors.chatBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          if (recording)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.fiber_manual_record,
                color: colors.deleted,
                size: 14,
              ),
            )
          else if (_stage == _Stage.processing)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            InkWell(
              onTap: _togglePlay,
              child: CircleAvatar(
                radius: 15,
                backgroundColor: colors.accent,
                child: Icon(
                  _playing ? Icons.pause : Icons.play_arrow,
                  color: colors.panel,
                  size: 20,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _LevelsPainter(
                levels: levels,
                color: colors.secondary,
                played: colors.accent,
                progress: recording ? 0 : _progress,
                live: recording,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _time(
              recording
                  ? _rec.elapsed
                  : Duration(seconds: _encoded?.duration ?? 0),
            ),
            style: TextStyle(color: colors.secondary, fontSize: 13),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _effectsGrid(BuildContext context, ChatColors colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        color: colors.chatBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.fxTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _effectsOpen = false),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 520 ? 4 : 2;
              final w = (c.maxWidth - (cols - 1) * 8) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in VoiceEffect.values)
                    SizedBox(
                      width: w,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          foregroundColor: colors.textIn,
                          backgroundColor: e == _effect
                              ? colors.accent.withValues(alpha: 0.18)
                              : null,
                          side: BorderSide(
                            color: e == _effect
                                ? colors.accent
                                : colors.secondary.withValues(alpha: 0.35),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _pick(e),
                        icon: Icon(effectIcon(e), size: 18),
                        label: Text(
                          effectName(context, e),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LevelsPainter extends CustomPainter {
  _LevelsPainter({
    required this.levels,
    required this.color,
    required this.played,
    required this.progress,
    required this.live,
  }) : count = levels.length;

  final List<double> levels;
  final int count;
  final Color color;
  final Color played;
  final double progress;
  final bool live;

  @override
  void paint(Canvas canvas, Size size) {
    const bar = 3.0;
    const gap = 2.0;
    final n = (size.width / (bar + gap)).floor();
    if (n <= 0) return;
    final List<double> view;
    if (live) {
      view = levels.length > n ? levels.sublist(levels.length - n) : levels;
    } else {
      view = [
        for (var i = 0; i < n; i++)
          levels.isEmpty
              ? 0
              : levels
                    .sublist(
                      (i * levels.length / n).floor(),
                      math.max(
                        (i * levels.length / n).floor() + 1,
                        ((i + 1) * levels.length / n).floor(),
                      ),
                    )
                    .reduce(math.max),
      ];
    }
    final paint = Paint()
      ..strokeWidth = bar
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < view.length; i++) {
      final h = math.max(3.0, math.sqrt(view[i]) * size.height * 0.9);
      final x = i * (bar + gap) + bar / 2;
      paint.color = !live && i / view.length < progress ? played : color;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LevelsPainter old) =>
      old.count != count || old.progress != progress || old.live != live;
}
