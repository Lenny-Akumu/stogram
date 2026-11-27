import 'dart:math' as math;
import 'dart:typed_data';

enum VoiceEffect {
  none,
  chipmunk,
  robot,
  stadium,
  demon,
  autotune,
  intercom,
  karaoke,
}

const _sr = 48000;

/// Applies [fx] to mono 48 kHz samples in -1..1, keeping the duration.
Float32List applyVoiceEffect(Float32List x, VoiceEffect fx) {
  final y = switch (fx) {
    VoiceEffect.none => Float32List.fromList(x),
    VoiceEffect.chipmunk => _pitch(x, (_) => 1.6),
    VoiceEffect.demon => _drive(_lowShelf(_pitch(x, (_) => 0.68), 2), 1.6),
    VoiceEffect.robot => _robot(x),
    VoiceEffect.stadium => _reverb(_echo(x, 0.32, 0.3, 0.35), 0.86, 0.5),
    VoiceEffect.autotune => _autotune(x),
    VoiceEffect.intercom => _intercom(x),
    VoiceEffect.karaoke => _reverb(_echo(x, 0.22, 0.25, 0.3), 0.7, 0.3),
  };
  return _normalize(y);
}

/// Granular pitch shifter: two crossfaded read heads over a delay line.
Float32List _pitch(Float32List x, double Function(int i) ratio) {
  const window = 2048;
  final y = Float32List(x.length);
  var phase = 0.0;
  for (var i = 0; i < x.length; i++) {
    final r = ratio(i);
    phase += (1 - r) / window;
    phase -= phase.floorToDouble();
    var s = 0.0;
    for (var k = 0; k < 2; k++) {
      final p = (phase + k * 0.5) % 1.0;
      final delay = p * window;
      final pos = i - delay;
      if (pos < 0) continue;
      final a = pos.floor();
      final f = pos - a;
      final v0 = x[a];
      final v1 = a + 1 < x.length ? x[a + 1] : v0;
      final g = math.sin(math.pi * p);
      s += (v0 + (v1 - v0) * f) * g * g;
    }
    y[i] = s;
  }
  return y;
}

Float32List _autotune(Float32List x) {
  const hop = 1024;
  final low = _lowPass(x, 1500);
  final d = Float32List(x.length ~/ 4);
  for (var i = 0; i < d.length; i++) {
    d[i] = low[i * 4];
  }
  final ratios = Float64List(x.length ~/ hop + 2);
  for (var f = 0; f * 256 + 512 < d.length; f++) {
    final f0 = _detectPitch(d, f * 256, 512);
    if (f0 <= 0) {
      ratios[f] = 1;
      continue;
    }
    final midi = 69 + 12 * math.log(f0 / 440) / math.ln2;
    final target = 440 * math.pow(2, (midi.roundToDouble() - 69) / 12);
    ratios[f] = (target / f0).clamp(0.8, 1.25);
  }
  var smooth = 1.0;
  final per = Float64List(x.length);
  for (var i = 0; i < x.length; i++) {
    smooth += (ratios[i ~/ hop] - smooth) * 0.02;
    per[i] = smooth;
  }
  final shifted = _pitch(x, (i) => per[i]);
  return _mix(shifted, _pitch(x, (i) => per[i] * 1.0005), 0.3);
}

double _detectPitch(Float32List x, int start, int n) {
  const sr = _sr ~/ 4;
  const minLag = sr ~/ 800;
  const maxLag = sr ~/ 80;
  var energy = 0.0;
  for (var i = 0; i < n; i++) {
    energy += x[start + i] * x[start + i];
  }
  if (energy / n < 1e-4) return 0;
  var best = 0.0;
  var bestLag = 0;
  for (var lag = minLag; lag <= maxLag; lag++) {
    var sum = 0.0;
    for (var i = 0; i + lag < n && start + i + lag < x.length; i++) {
      sum += x[start + i] * x[start + i + lag];
    }
    if (sum > best) {
      best = sum;
      bestLag = lag;
    }
  }
  return bestLag == 0 || best < energy * 0.15 ? 0 : sr / bestLag;
}

Float32List _robot(Float32List x) {
  final y = Float32List(x.length);
  const d = 360;
  for (var i = 0; i < x.length; i++) {
    final ring = math.sin(2 * math.pi * 55 * i / _sr);
    final fb = i >= d ? y[i - d] * 0.55 : 0.0;
    y[i] = x[i] * ring + fb;
  }
  return _mix(_drive(y, 1.4), x, 0.15);
}

Float32List _echo(Float32List x, double seconds, double feedback, double mix) {
  final d = (seconds * _sr).round();
  final y = Float32List(x.length);
  final buf = Float32List(x.length);
  for (var i = 0; i < x.length; i++) {
    final delayed = i >= d ? buf[i - d] : 0.0;
    buf[i] = x[i] + delayed * feedback;
    y[i] = x[i] + delayed * mix;
  }
  return y;
}

/// Small Schroeder reverb: parallel combs into series allpasses.
Float32List _reverb(Float32List x, double room, double wet) {
  const combs = [1557, 1617, 1491, 1422, 1277, 1356];
  const allpasses = [225, 556, 441];
  final acc = Float32List(x.length);
  for (final c in combs) {
    final d = c * 1.09;
    final n = d.round();
    final buf = Float32List(n);
    var idx = 0;
    var lp = 0.0;
    for (var i = 0; i < x.length; i++) {
      final out = buf[idx];
      lp = out * 0.7 + lp * 0.3;
      buf[idx] = x[i] + lp * room;
      idx = (idx + 1) % n;
      acc[i] += out / combs.length;
    }
  }
  var y = acc;
  for (final a in allpasses) {
    final buf = Float32List(a);
    var idx = 0;
    final z = Float32List(y.length);
    for (var i = 0; i < y.length; i++) {
      final b = buf[idx];
      final out = -y[i] + b;
      buf[idx] = y[i] + b * 0.5;
      idx = (idx + 1) % a;
      z[i] = out;
    }
    y = z;
  }
  return _mix(y, x, 1 - wet, wetGain: wet * 2.2);
}

Float32List _intercom(Float32List x) {
  var y = _highPass(x, 500);
  y = _lowPass(y, 2800);
  y = _lowPass(y, 3200);
  y = _drive(y, 3);
  final rnd = math.Random(7);
  for (var i = 0; i < y.length; i++) {
    final crushed = (y[i] * 24).roundToDouble() / 24;
    y[i] = crushed + (rnd.nextDouble() - 0.5) * 0.015;
  }
  return y;
}

Float32List _lowPass(Float32List x, double hz) {
  final a = 1 - math.exp(-2 * math.pi * hz / _sr);
  final y = Float32List(x.length);
  var s = 0.0;
  for (var i = 0; i < x.length; i++) {
    s += (x[i] - s) * a;
    y[i] = s;
  }
  return y;
}

Float32List _highPass(Float32List x, double hz) {
  final low = _lowPass(x, hz);
  return Float32List.fromList([
    for (var i = 0; i < x.length; i++) x[i] - low[i],
  ]);
}

Float32List _lowShelf(Float32List x, double gain) {
  final low = _lowPass(x, 250);
  return Float32List.fromList([
    for (var i = 0; i < x.length; i++) x[i] + low[i] * (gain - 1),
  ]);
}

Float32List _drive(Float32List x, double amount) => Float32List.fromList([
  for (final v in x) _tanh(v * amount) / _tanh(amount),
]);

double _tanh(double v) {
  final e = math.exp(2 * v.clamp(-20, 20));
  return (e - 1) / (e + 1);
}

Float32List _mix(
  Float32List wet,
  Float32List dry,
  double dryGain, {
  double wetGain = 1,
}) => Float32List.fromList([
  for (var i = 0; i < wet.length; i++) wet[i] * wetGain + dry[i] * dryGain,
]);

Float32List _normalize(Float32List y) {
  var peak = 0.0;
  for (final v in y) {
    final a = v.abs();
    if (a > peak) peak = a;
  }
  if (peak < 1e-6) return y;
  final g = peak > 0.98 ? 0.98 / peak : 1.0;
  if (g == 1) return y;
  for (var i = 0; i < y.length; i++) {
    y[i] *= g;
  }
  return y;
}

Float32List pcm16ToFloat(Int16List pcm) =>
    Float32List.fromList([for (final s in pcm) s / 32768]);

Int16List floatToPcm16(Float32List x) =>
    Int16List.fromList([for (final v in x) (v.clamp(-1, 1) * 32767).round()]);

/// Telegram's 5-bit packed waveform with 100 samples.
Uint8List voiceWaveform(Float32List x) {
  const n = 100;
  final peaks = List<double>.filled(n, 0);
  if (x.isEmpty) return Uint8List(63);
  final chunk = (x.length / n).ceil();
  for (var i = 0; i < x.length; i++) {
    final k = i ~/ chunk;
    final a = x[i].abs();
    if (a > peaks[k]) peaks[k] = a;
  }
  final top = peaks.reduce(math.max);
  final values = [for (final p in peaks) top == 0 ? 0 : (p / top * 31).round()];
  final out = Uint8List((n * 5 + 7) ~/ 8);
  for (var i = 0; i < n; i++) {
    final bit = i * 5;
    final v = values[i] << (bit & 7);
    out[bit >> 3] |= v & 0xff;
    if ((bit >> 3) + 1 < out.length) out[(bit >> 3) + 1] |= v >> 8;
  }
  return out;
}

/// Spectral gate: learns the noise floor from the quietest frames and
/// attenuates bins that do not rise above it. [strength] is 0..1.
Float32List denoise(Float32List x, double strength) {
  const n = 1024;
  const hop = n ~/ 2;
  if (x.length < n * 2 || strength <= 0) return Float32List.fromList(x);
  final win = Float64List.fromList([
    for (var i = 0; i < n; i++) 0.5 - 0.5 * math.cos(2 * math.pi * i / n),
  ]);
  final frames = (x.length - n) ~/ hop + 1;
  final mags = List<Float64List>.generate(
    frames,
    (_) => Float64List(n ~/ 2 + 1),
  );
  final res = List<Float64List>.generate(frames, (_) => Float64List(n));
  final ims = List<Float64List>.generate(frames, (_) => Float64List(n));
  final energy = Float64List(frames);
  for (var f = 0; f < frames; f++) {
    final re = res[f];
    final im = ims[f];
    for (var i = 0; i < n; i++) {
      re[i] = x[f * hop + i] * win[i];
    }
    _fft(re, im, false);
    for (var k = 0; k <= n ~/ 2; k++) {
      final m = math.sqrt(re[k] * re[k] + im[k] * im[k]);
      mags[f][k] = m;
      energy[f] += m;
    }
  }
  final order = List<int>.generate(frames, (i) => i)
    ..sort((a, b) => energy[a].compareTo(energy[b]));
  final quiet = order.take(math.max(4, frames ~/ 10)).toList();
  final noise = Float64List(n ~/ 2 + 1);
  for (final f in quiet) {
    for (var k = 0; k <= n ~/ 2; k++) {
      noise[k] += mags[f][k] / quiet.length;
    }
  }
  final over = 1 + strength * 2.5;
  final floor = 1 - strength * 0.92;
  final y = Float64List(x.length);
  final norm = Float64List(x.length);
  var prev = Float64List(n ~/ 2 + 1)..fillRange(0, n ~/ 2 + 1, 1);
  for (var f = 0; f < frames; f++) {
    final re = res[f];
    final im = ims[f];
    final gains = Float64List(n ~/ 2 + 1);
    for (var k = 0; k <= n ~/ 2; k++) {
      final m = mags[f][k];
      var g = m <= 0 ? 0.0 : (m - noise[k] * over) / m;
      g = g.clamp(floor, 1.0);
      g = prev[k] * 0.35 + g * 0.65;
      gains[k] = g;
    }
    prev = gains;
    for (var k = 0; k < n; k++) {
      final g = gains[k <= n ~/ 2 ? k : n - k];
      re[k] *= g;
      im[k] *= g;
    }
    _fft(re, im, true);
    for (var i = 0; i < n; i++) {
      y[f * hop + i] += re[i] * win[i];
      norm[f * hop + i] += win[i] * win[i];
    }
  }
  return Float32List.fromList([
    for (var i = 0; i < x.length; i++)
      norm[i] > 1e-3 ? y[i] / norm[i] : x[i] * floor,
  ]);
}

void _fft(Float64List re, Float64List im, bool inverse) {
  final n = re.length;
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; (j & bit) != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }
  for (var len = 2; len <= n; len <<= 1) {
    final ang = 2 * math.pi / len * (inverse ? 1 : -1);
    final wr = math.cos(ang);
    final wi = math.sin(ang);
    for (var i = 0; i < n; i += len) {
      var cr = 1.0;
      var ci = 0.0;
      for (var j = 0; j < len ~/ 2; j++) {
        final a = i + j;
        final b = a + len ~/ 2;
        final xr = re[b] * cr - im[b] * ci;
        final xi = re[b] * ci + im[b] * cr;
        re[b] = re[a] - xr;
        im[b] = im[a] - xi;
        re[a] += xr;
        im[a] += xi;
        final t = cr * wr - ci * wi;
        ci = cr * wi + ci * wr;
        cr = t;
      }
    }
  }
  if (inverse) {
    for (var i = 0; i < n; i++) {
      re[i] /= n;
      im[i] /= n;
    }
  }
}

class VoiceJob {
  const VoiceJob(this.pcm, this.effect, this.denoise);
  final Int16List pcm;
  final VoiceEffect effect;

  /// 0 disables noise suppression.
  final double denoise;
}

/// Processed samples plus the waveform, ready to encode.
({Int16List pcm, Uint8List waveform}) processVoice(VoiceJob job) {
  var x = pcm16ToFloat(job.pcm);
  if (job.denoise > 0) x = denoise(x, job.denoise);
  x = applyVoiceEffect(x, job.effect);
  return (pcm: floatToPcm16(x), waveform: voiceWaveform(x));
}
