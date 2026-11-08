import 'dart:convert';

import 'package:app/core/tdlib/td_dispatcher.dart';
import 'package:app/core/tdlib/td_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TdDispatcher d;

  setUp(() => d = TdDispatcher());
  tearDown(() => d.close());

  test('routes response by @extra', () async {
    final (id, future) = d.register();
    d.handle(jsonEncode({'@type': 'ok', '@extra': id, '@client_id': 1}));
    expect(await future, {'@type': 'ok'});
  });

  test('error response completes with TdError', () async {
    final (id, future) = d.register();
    d.handle(
      jsonEncode({'@type': 'error', '@extra': id, 'code': 400, 'message': 'X'}),
    );
    await expectLater(
      future,
      throwsA(isA<TdError>().having((e) => e.code, 'code', 400)),
    );
  });

  test('objects without known @extra go to updates', () async {
    final next = d.updates.first;
    d.handle(jsonEncode({'@type': 'updateOption', '@extra': 'nope'}));
    expect((await next)['@type'], 'updateOption');
  });
}
