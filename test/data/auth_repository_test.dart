import 'package:app/data/auth/auth_repository.dart';
import 'package:app/data/auth/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_td.dart';

void main() {
  test('closed state reopens the client and asks for state again', () async {
    final td = FakeTd()
      ..handler = (_) => {'@type': 'authorizationStateWaitPhoneNumber'};
    final repo = AuthRepository(td);
    await pumpEventQueue();
    expect(repo.current, isA<AuthWaitPhone>());

    td.push({
      '@type': 'updateAuthorizationState',
      'authorization_state': {'@type': 'authorizationStateClosed'},
    });
    await pumpEventQueue();

    expect(td.reopened, 1);
    expect(
      td.sent.where((r) => r['@type'] == 'getAuthorizationState'),
      hasLength(2),
    );
    expect(repo.current, isA<AuthWaitPhone>());
    await repo.dispose();
  });
}
