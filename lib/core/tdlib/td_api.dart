import 'td_dispatcher.dart';

abstract interface class TdApi {
  Stream<TdObject> get updates;

  Future<TdObject> send(TdObject request);

  /// Creates a fresh TDLib instance after the old one reached `closed`.
  void reopen();
}
