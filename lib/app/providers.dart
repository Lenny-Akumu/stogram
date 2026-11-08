import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tdlib/td_client.dart';
import '../data/auth/auth_repository.dart';
import '../data/auth/auth_state.dart';

final tdClientProvider = Provider<TdClient>(
  (ref) => throw UnimplementedError('override in ProviderScope'),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = AuthRepository(ref.watch(tdClientProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final authStateProvider = StreamProvider<AuthState>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  yield repo.current;
  yield* repo.states;
});
