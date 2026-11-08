import 'dart:async';

import 'package:app/core/util/streams.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not drop events emitted right after listen', () async {
    final source = StreamController<int>.broadcast(sync: true);
    var current = 1;
    final seen = <int>[];
    currentThen(() => current, source.stream).listen(seen.add);
    current = 2;
    source.add(2);
    await pumpEventQueue();
    expect(seen, [1, 2]);
    await source.close();
  });
}
