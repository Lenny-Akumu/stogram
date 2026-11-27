import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'ogg_opus.dart';
import 'opus_encoder.dart';
import 'voice_fx.dart';

class VoiceRecorder {
  final _rec = AudioRecorder();
  final _bytes = BytesBuilder(copy: false);
  final level = ValueNotifier<double>(0);
  final levels = <double>[];
  StreamSubscription<Uint8List>? _sub;
  final _watch = Stopwatch();

  Duration get elapsed => _watch.elapsed;

  Future<bool> start({bool echoCancel = true, bool autoGain = false}) async {
    if (!await _rec.hasPermission()) return false;
    final stream = await _rec.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: OpusEncoder.sampleRate,
        numChannels: 1,
        echoCancel: echoCancel,
        autoGain: autoGain,
      ),
    );
    _watch.start();
    var pending = <int>[];
    _sub = stream.listen((chunk) {
      _bytes.add(chunk);
      final data = ByteData.sublistView(chunk);
      var peak = 0;
      for (var i = 0; i + 1 < chunk.length; i += 2) {
        final v = data.getInt16(i, Endian.little).abs();
        if (v > peak) peak = v;
      }
      pending.add(peak);
      if (pending.length >= 3) {
        final p = pending.reduce((a, b) => a > b ? a : b) / 32768;
        level.value = p;
        levels.add(p);
        pending = [];
      }
    });
    return true;
  }

  Future<Int16List> stop() async {
    _watch.stop();
    await _rec.stop();
    await _sub?.cancel();
    final b = _bytes.takeBytes();
    return Int16List.sublistView(b, 0, b.length ~/ 2);
  }

  Future<void> cancel() async {
    _watch.stop();
    await _rec.cancel();
    await _sub?.cancel();
    _bytes.clear();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _rec.dispose();
    level.dispose();
  }
}

class EncodedVoice {
  const EncodedVoice(this.path, this.duration, this.waveform);
  final String path;
  final int duration;
  final Uint8List waveform;
}

({Uint8List ogg, Uint8List waveform}) _encode(VoiceJob job) {
  final r = processVoice(job);
  final enc = OpusEncoder();
  try {
    return (ogg: oggOpus(enc.encodeAll(r.pcm)), waveform: r.waveform);
  } finally {
    enc.dispose();
  }
}

/// Runs denoise, effect and Opus encoding off the UI isolate.
Future<EncodedVoice> encodeVoice(VoiceJob job) async {
  final r = await compute(_encode, job);
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.ogg',
  );
  await file.writeAsBytes(r.ogg);
  return EncodedVoice(
    file.path,
    (job.pcm.length / OpusEncoder.sampleRate).ceil(),
    r.waveform,
  );
}
