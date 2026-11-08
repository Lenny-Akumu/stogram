import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tdlib/td_client.dart';
import '../data/auth/auth_repository.dart';
import '../data/auth/auth_state.dart';
import '../data/chats/chat_summary.dart';
import '../data/chats/chats_repository.dart';

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

final chatsRepositoryProvider = Provider<ChatsRepository>((ref) {
  final repo = ChatsRepository(ref.watch(tdClientProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final chatsProvider = StreamProvider<List<ChatSummary>>((ref) async* {
  final repo = ref.watch(chatsRepositoryProvider);
  yield repo.current;
  yield* repo.chats;
});
