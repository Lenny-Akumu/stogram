import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/util/streams.dart';
import '../core/config.dart';
import '../core/tdlib/td_api.dart';
import '../data/auth/auth_repository.dart';
import '../data/auth/auth_state.dart';
import '../data/chats/chat_summary.dart';
import '../data/chats/chats_repository.dart';
import '../data/files/files_repository.dart';
import '../data/messages/chat_message.dart';
import '../data/messages/messages_repository.dart';
import '../data/users/users_repository.dart';

final envConfiguredProvider = Provider<bool>((_) => Env.isConfigured);

final tdApiProvider = Provider<TdApi>(
  (ref) => throw UnimplementedError('override in ProviderScope'),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = AuthRepository(ref.watch(tdApiProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return currentThen(() => repo.current, repo.states);
});

final chatsRepositoryProvider = Provider<ChatsRepository>((ref) {
  final repo = ChatsRepository(ref.watch(tdApiProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final chatsProvider = StreamProvider<List<ChatSummary>>((ref) {
  final repo = ref.watch(chatsRepositoryProvider);
  return currentThen(() => repo.current, repo.chats);
});

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  final repo = UsersRepository(ref.watch(tdApiProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final messagesRepositoryProvider = Provider.autoDispose
    .family<MessagesRepository, int>((ref, chatId) {
      final repo = MessagesRepository(ref.watch(tdApiProvider), chatId);
      ref.onDispose(repo.dispose);
      return repo;
    });

final messagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, int>((ref, chatId) {
      final repo = ref.watch(messagesRepositoryProvider(chatId));
      return currentThen(() => repo.current, repo.messages);
    });

final filesRepositoryProvider = Provider<FilesRepository>((ref) {
  final repo = FilesRepository(ref.watch(tdApiProvider));
  ref.onDispose(repo.dispose);
  return repo;
});
