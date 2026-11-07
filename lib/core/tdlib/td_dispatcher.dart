import 'dart:async';
import 'dart:convert';

import 'td_error.dart';

typedef TdObject = Map<String, dynamic>;

class TdDispatcher {
  final _pending = <String, Completer<TdObject>>{};
  final _updates = StreamController<TdObject>.broadcast();
  var _seq = 0;

  Stream<TdObject> get updates => _updates.stream;

  (String, Future<TdObject>) register() {
    final id = '${++_seq}';
    final completer = Completer<TdObject>();
    _pending[id] = completer;
    return (id, completer.future);
  }

  void handle(String raw) {
    final obj = jsonDecode(raw) as TdObject;
    obj.remove('@client_id');
    final extra = obj.remove('@extra');
    final completer = extra == null ? null : _pending.remove('$extra');
    if (completer == null) {
      _updates.add(obj);
    } else if (obj['@type'] == 'error') {
      completer.completeError(TdError.fromJson(obj));
    } else {
      completer.complete(obj);
    }
  }

  Future<void> close() async {
    for (final c in _pending.values) {
      c.completeError(const TdError(-1, 'client closed'));
    }
    _pending.clear();
    await _updates.close();
  }
}
