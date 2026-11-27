import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ayu/ayu_settings.dart';

class VoicePrefs {
  const VoicePrefs({
    this.denoise = true,
    this.strength = 0.6,
    this.echoCancel = true,
    this.autoGain = false,
  });

  final bool denoise;
  final double strength;
  final bool echoCancel;
  final bool autoGain;

  double get denoiseLevel => denoise ? strength : 0;

  VoicePrefs copyWith({
    bool? denoise,
    double? strength,
    bool? echoCancel,
    bool? autoGain,
  }) => VoicePrefs(
    denoise: denoise ?? this.denoise,
    strength: strength ?? this.strength,
    echoCancel: echoCancel ?? this.echoCancel,
    autoGain: autoGain ?? this.autoGain,
  );
}

final voicePrefsProvider = NotifierProvider<VoicePrefsNotifier, VoicePrefs>(
  VoicePrefsNotifier.new,
);

class VoicePrefsNotifier extends Notifier<VoicePrefs> {
  @override
  VoicePrefs build() {
    final p = ref.watch(sharedPrefsProvider);
    if (p == null) return const VoicePrefs();
    return VoicePrefs(
      denoise: p.getBool('voice.denoise') ?? true,
      strength: p.getDouble('voice.strength') ?? 0.6,
      echoCancel: p.getBool('voice.echo') ?? true,
      autoGain: p.getBool('voice.gain') ?? false,
    );
  }

  Future<void> update(VoicePrefs v) async {
    state = v;
    final p = ref.read(sharedPrefsProvider);
    await p?.setBool('voice.denoise', v.denoise);
    await p?.setDouble('voice.strength', v.strength);
    await p?.setBool('voice.echo', v.echoCancel);
    await p?.setBool('voice.gain', v.autoGain);
  }
}
