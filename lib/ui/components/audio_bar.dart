import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/media/audio_playback.dart';
import '../theme/chat_colors.dart';

String _clock(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Strip under the chat header while a voice note or track is playing.
class AudioBar extends ConsumerWidget {
  const AudioBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(audioPlaybackProvider);
    if (a.fileId == null) return const SizedBox.shrink();
    final n = ref.read(audioPlaybackProvider.notifier);
    final colors = ChatColors.of(context);
    final rate = a.rate == 1.5 ? '1.5×' : '${a.rate.toInt()}×';
    return Material(
      color: colors.panel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
            child: Row(
              children: [
                IconButton(
                  color: colors.accent,
                  onPressed: () => unawaited(n.playPause()),
                  icon: Icon(a.playing ? Icons.pause : Icons.play_arrow),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.label.isEmpty ? context.l10n.previewAudio : a.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${_clock(a.position)} / ${_clock(a.duration)}',
                        style: TextStyle(color: colors.secondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => unawaited(n.nextRate()),
                  child: Text(
                    rate,
                    style: TextStyle(
                      color: a.rate == 1 ? colors.secondary : colors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.actionCancel,
                  color: colors.secondary,
                  onPressed: () => unawaited(n.stop()),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              value: a.progress,
              activeColor: colors.accent,
              inactiveColor: colors.divider,
              onChanged: (v) => unawaited(n.seek(v)),
            ),
          ),
        ],
      ),
    );
  }
}
