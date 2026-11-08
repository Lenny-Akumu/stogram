import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'td_api.dart';
import 'td_dispatcher.dart';
import 'td_native.dart';

export 'td_api.dart';
export 'td_dispatcher.dart' show TdObject;
export 'td_error.dart';

class TdClient implements TdApi {
  TdClient._(
    this._native,
    this._clientId,
    this._dispatcher,
    this._isolate,
    this._port,
    this._control,
  );

  final TdNative _native;
  int _clientId;
  final TdDispatcher _dispatcher;
  final Isolate _isolate;
  final ReceivePort _port;
  final SendPort _control;

  @override
  Stream<TdObject> get updates => _dispatcher.updates;

  static Future<TdClient> start({String? libPath}) async {
    final native = TdNative.open(libPath);
    native.execute(
      jsonEncode({'@type': 'setLogVerbosityLevel', 'new_verbosity_level': 1}),
    );
    final clientId = native.createClientId();
    final dispatcher = TdDispatcher()..clientId = clientId;
    final port = ReceivePort();
    final control = Completer<SendPort>();
    port.listen((msg) {
      if (msg is String) {
        dispatcher.handle(msg);
      } else if (msg is SendPort) {
        control.complete(msg);
      }
    });
    final isolate = await Isolate.spawn(_receiveLoop, (port.sendPort, libPath));
    return TdClient._(
      native,
      clientId,
      dispatcher,
      isolate,
      port,
      await control.future,
    );
  }

  @override
  Future<TdObject> send(TdObject request) {
    final (id, future) = _dispatcher.register();
    _native.send(_clientId, jsonEncode({...request, '@extra': id}));
    return future;
  }

  @override
  void reopen() {
    _clientId = _native.createClientId();
    _dispatcher.clientId = _clientId;
  }

  TdObject? execute(TdObject request) {
    final res = _native.execute(jsonEncode(request));
    return res == null ? null : jsonDecode(res) as TdObject;
  }

  Future<void> dispose() async {
    _control.send(null);
    _port.close();
    _isolate.kill();
    await _dispatcher.close();
  }
}

Future<void> _receiveLoop((SendPort, String?) args) async {
  final (out, libPath) = args;
  final native = TdNative.open(libPath);
  final control = ReceivePort();
  var running = true;
  control.listen((_) {
    running = false;
    control.close();
  });
  out.send(control.sendPort);
  while (running) {
    final msg = native.receive(0.5);
    if (msg != null) out.send(msg);
    await Future<void>.delayed(Duration.zero);
  }
}
