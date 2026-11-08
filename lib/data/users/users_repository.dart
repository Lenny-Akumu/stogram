import 'dart:async';

import '../../core/tdlib/td_api.dart';
import '../../core/tdlib/td_dispatcher.dart';

class UsersRepository {
  UsersRepository(this._td) {
    _sub = _td.updates
        .where((u) => u['@type'] == 'updateUser')
        .listen((u) => _put(u['user'] as TdObject));
  }

  final TdApi _td;
  final _names = <int, String>{};
  late final StreamSubscription<TdObject> _sub;

  String? nameOf(int userId) => _names[userId];

  void _put(TdObject user) {
    final first = user['first_name'] as String? ?? '';
    final last = user['last_name'] as String? ?? '';
    _names[user['id'] as int] = [
      first,
      last,
    ].where((s) => s.isNotEmpty).join(' ');
  }

  Future<void> dispose() => _sub.cancel();
}
