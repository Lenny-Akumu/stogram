import 'dart:async';

/// Emits [current] on listen, then every event of [changes] with no gap.
Stream<T> currentThen<T>(T Function() current, Stream<T> changes) {
  StreamSubscription<T>? sub;
  late final StreamController<T> out;
  out = StreamController<T>(
    onListen: () {
      sub = changes.listen(out.add, onError: out.addError, onDone: out.close);
      out.add(current());
    },
    onCancel: () => sub?.cancel(),
  );
  return out.stream;
}
