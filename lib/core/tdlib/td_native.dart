import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _CreateC = Int32 Function();
typedef _CreateDart = int Function();
typedef _SendC = Void Function(Int32, Pointer<Utf8>);
typedef _SendDart = void Function(int, Pointer<Utf8>);
typedef _ReceiveC = Pointer<Utf8> Function(Double);
typedef _ReceiveDart = Pointer<Utf8> Function(double);
typedef _ExecuteC = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _ExecuteDart = Pointer<Utf8> Function(Pointer<Utf8>);

class TdNative {
  TdNative(DynamicLibrary lib)
    : _create = lib.lookupFunction<_CreateC, _CreateDart>(
        'td_create_client_id',
      ),
      _send = lib.lookupFunction<_SendC, _SendDart>('td_send'),
      _receive = lib.lookupFunction<_ReceiveC, _ReceiveDart>('td_receive'),
      _execute = lib.lookupFunction<_ExecuteC, _ExecuteDart>('td_execute');

  factory TdNative.open([String? path]) => TdNative(_open(path));

  final _CreateDart _create;
  final _SendDart _send;
  final _ReceiveDart _receive;
  final _ExecuteDart _execute;

  int createClientId() => _create();

  void send(int clientId, String json) {
    final ptr = json.toNativeUtf8();
    try {
      _send(clientId, ptr);
    } finally {
      malloc.free(ptr);
    }
  }

  String? receive(double timeout) {
    final ptr = _receive(timeout);
    return ptr == nullptr ? null : ptr.toDartString();
  }

  String? execute(String json) {
    final ptr = json.toNativeUtf8();
    try {
      final res = _execute(ptr);
      return res == nullptr ? null : res.toDartString();
    } finally {
      malloc.free(ptr);
    }
  }

  static DynamicLibrary _open(String? path) {
    if (path != null && path.isNotEmpty) return DynamicLibrary.open(path);
    if (Platform.isIOS) return DynamicLibrary.process();
    if (Platform.isMacOS) return DynamicLibrary.open('libtdjson.dylib');
    if (Platform.isWindows) return DynamicLibrary.open('tdjson.dll');
    return DynamicLibrary.open('libtdjson.so');
  }
}
