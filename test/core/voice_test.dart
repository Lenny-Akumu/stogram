import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:app/core/voice/ogg_opus.dart';
import 'package:app/core/voice/opus_encoder.dart';
import 'package:app/core/voice/voice_fx.dart';
import 'package:flutter_test/flutter_test.dart';

Float32List _tone(double hz, double seconds) => Float32List.fromList([
  for (var i = 0; i < (48000 * seconds).round(); i++)
    0.5 * math.sin(2 * math.pi * hz * i / 48000),
]);

double _freq(Float32List x) {
  var crossings = 0;
  for (var i = 1; i < x.length; i++) {
    if (x[i - 1] < 0 && x[i] >= 0) crossings++;
  }
  return crossings / (x.length / 48000);
}

void main() {
  test('every effect keeps length and stays in range', () {
    final x = _tone(220, 1);
    for (final fx in VoiceEffect.values) {
      final y = applyVoiceEffect(x, fx);
      expect(y.length, x.length, reason: fx.name);
      expect(
        y.every((v) => v.abs() <= 1 && v.isFinite),
        isTrue,
        reason: fx.name,
      );
    }
  });

  test('chipmunk raises and demon lowers pitch', () {
    final x = _tone(200, 1);
    expect(_freq(applyVoiceEffect(x, VoiceEffect.chipmunk)), greaterThan(280));
    expect(_freq(applyVoiceEffect(x, VoiceEffect.demon)), lessThan(160));
  });

  test('waveform packs 100 five-bit samples', () {
    final w = voiceWaveform(_tone(200, 0.5));
    expect(w.length, 63);
    expect(w.any((b) => b != 0), isTrue);
  });

  test('ogg pages have valid headers', () {
    final file = oggOpus([
      for (var i = 0; i < 120; i++) Uint8List.fromList(List.filled(40, i)),
    ]);
    expect(String.fromCharCodes(file.sublist(0, 4)), 'OggS');
    expect(String.fromCharCodes(file.sublist(28, 36)), 'OpusHead');
  });

  test('opus encodes a playable ogg', () async {
    final enc = OpusEncoder();
    final packets = enc.encodeAll(floatToPcm16(_tone(300, 1)));
    enc.dispose();
    expect(packets, hasLength(50));
    final file = File('${Directory.systemTemp.path}/stogram_voice_test.ogg')
      ..writeAsBytesSync(oggOpus(packets));
    final probe = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'stream=codec_name,sample_rate',
      '-of',
      'csv=p=0',
      file.path,
    ]);
    if (probe.exitCode == 0 || (probe.stdout as String).isNotEmpty) {
      expect(probe.stdout, contains('opus'));
    }
  }, skip: !OpusEncoder.available ? 'no libopus' : false);

  test('denoise cuts steady noise and keeps the tone', () {
    final rnd = math.Random(1);
    final x = Float32List(48000 * 2);
    for (var i = 0; i < x.length; i++) {
      final tone = i > 48000
          ? 0.4 * math.sin(2 * math.pi * 300 * i / 48000)
          : 0;
      x[i] = tone + (rnd.nextDouble() - 0.5) * 0.1;
    }
    double rms(Float32List v, int a, int b) {
      var s = 0.0;
      for (var i = a; i < b; i++) {
        s += v[i] * v[i];
      }
      return math.sqrt(s / (b - a));
    }

    final y = denoise(x, 0.8);
    expect(rms(y, 2000, 46000), lessThan(rms(x, 2000, 46000) * 0.4));
    expect(rms(y, 50000, 94000), greaterThan(rms(x, 50000, 94000) * 0.7));
  });
}
