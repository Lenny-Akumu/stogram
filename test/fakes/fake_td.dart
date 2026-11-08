import 'dart:async';

import 'package:app/core/tdlib/td_api.dart';
import 'package:app/core/tdlib/td_dispatcher.dart';

class FakeTd implements TdApi {
  final _updates = StreamController<TdObject>.broadcast(sync: true);
  final sent = <TdObject>[];
  FutureOr<TdObject> Function(TdObject request)? handler;
  int reopened = 0;

  void push(TdObject update) => _updates.add(update);

  @override
  Stream<TdObject> get updates => _updates.stream;

  @override
  Future<TdObject> send(TdObject request) async {
    sent.add(request);
    return await handler?.call(request) ?? {'@type': 'ok'};
  }

  @override
  void reopen() => reopened++;
}
