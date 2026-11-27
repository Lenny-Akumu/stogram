import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../tdlib/td_native.dart';

typedef _CreateC = Pointer<Void> Function(Int32, Int32, Int32, Pointer<Int32>);
typedef _Create = Pointer<Void> Function(int, int, int, Pointer<Int32>);
typedef _EncodeC =
    Int32 Function(Pointer<Void>, Pointer<Int16>, Int32, Pointer<Uint8>, Int32);
typedef _Encode =
    int Function(Pointer<Void>, Pointer<Int16>, int, Pointer<Uint8>, int);
typedef _DestroyC = Void Function(Pointer<Void>);
typedef _Destroy = void Function(Pointer<Void>);

/// Mono 48 kHz Opus encoder over the system or bundled libopus.
class OpusEncoder {
  OpusEncoder._(this._st, this._encode, this._destroy);

  static const sampleRate = 48000;
  static const frame = 960;
  static const _voip = 2048;

  static DynamicLibrary? _lib;

  static DynamicLibrary _open() {
    if (_lib != null) return _lib!;
    final names = Platform.isWindows
        ? ['opus.dll']
        : Platform.isAndroid
        ? ['libopus.so']
        : ['libopus.so.0', 'libopus.so'];
    Object? last;
    for (final n in names) {
      if (Platform.isLinux || Platform.isWindows) {
        final bundled = TdNative.bundledPath(Platform.resolvedExecutable, n);
        if (File(bundled).existsSync()) {
          return _lib = DynamicLibrary.open(bundled);
        }
      }
      try {
        return _lib = DynamicLibrary.open(n);
      } on ArgumentError catch (e) {
        last = e;
      }
    }
    throw StateError('libopus not found: $last');
  }

  static bool get available {
    try {
      _open();
      return true;
    } on Object {
      return false;
    }
  }

  factory OpusEncoder() {
    final lib = _open();
    final create = lib.lookupFunction<_CreateC, _Create>('opus_encoder_create');
    final err = calloc<Int32>();
    try {
      final st = create(sampleRate, 1, _voip, err);
      if (err.value != 0 || st == nullptr) {
        throw StateError('opus_encoder_create failed: ${err.value}');
      }
      return OpusEncoder._(
        st,
        lib.lookupFunction<_EncodeC, _Encode>('opus_encode'),
        lib.lookupFunction<_DestroyC, _Destroy>('opus_encoder_destroy'),
      );
    } finally {
      calloc.free(err);
    }
  }

  final Pointer<Void> _st;
  final _Encode _encode;
  final _Destroy _destroy;

  /// Encodes 20 ms frames; the tail is padded with silence.
  List<Uint8List> encodeAll(Int16List pcm) {
    final input = calloc<Int16>(frame);
    final out = calloc<Uint8>(4000);
    final packets = <Uint8List>[];
    try {
      for (var i = 0; i < pcm.length; i += frame) {
        final n = (pcm.length - i).clamp(0, frame);
        final view = input.asTypedList(frame)..fillRange(0, frame, 0);
        view.setRange(0, n, pcm, i);
        final len = _encode(_st, input, frame, out, 4000);
        if (len < 0) throw StateError('opus_encode failed: $len');
        packets.add(Uint8List.fromList(out.asTypedList(len)));
      }
    } finally {
      calloc
        ..free(input)
        ..free(out);
    }
    return packets;
  }

  void dispose() => _destroy(_st);
}
