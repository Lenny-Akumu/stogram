import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/util/streams.dart';
import '../core/ayu/ayu_archive.dart';
import '../core/ayu/ayu_settings.dart';
import '../core/config.dart';
import '../core/db/app_db.dart';
import '../core/tdlib/td_api.dart';
import '../data/auth/auth_repository.dart';
import '../data/auth/auth_state.dart';
import '../data/chats/chat_summary.dart';
import '../data/chats/chats_repository.dart';
import '../data/files/files_repository.dart';
import '../data/messages/chat_message.dart';
import '../data/messages/messages_repository.dart';
import '../data/users/users_repository.dart';

export '../data/users/users_repository.dart';

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
      final repo = MessagesRepository(
        ref.watch(tdApiProvider),
        chatId,
        archive: ref.watch(ayuArchiveProvider),
        settings: () => ref.read(ayuSettingsProvider),
      );
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

/// Ticks whenever any user, group or typing state changes.
final usersChangedProvider = StreamProvider<void>((ref) {
  return ref.watch(usersRepositoryProvider).changes;
});

final meProvider = FutureProvider<TgUser?>((ref) {
  return ref.watch(usersRepositoryProvider).loadMe();
});

final selectedChatProvider = NotifierProvider<SelectedChat, int?>(
  SelectedChat.new,
);

class SelectedChat extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

/// Null in tests; main overrides it with the on-disk database.
final appDbProvider = Provider<AppDb?>((_) => null);

final ayuArchiveProvider = Provider<AyuArchive?>((ref) {
  final db = ref.watch(appDbProvider);
  if (db == null) return null;
  final archive = AyuArchive(
    ref.watch(tdApiProvider),
    db,
    () => ref.read(ayuSettingsProvider),
  );
  ref.onDispose(archive.dispose);
  return archive;
});

/// Keeps TDLib's online flag in line with ghost mode.
final ghostSyncProvider = Provider<void>((ref) {
  final td = ref.watch(tdApiProvider);
  void apply() {
    final ghost = ref.read(ayuSettingsProvider).ghostMode;
    td.send({
      '@type': 'setOption',
      'name': 'online',
      'value': {'@type': 'optionValueBoolean', 'value': !ghost},
    }).ignore();
  }

  ref
    ..listen(ayuSettingsProvider, (prev, next) {
      if (prev?.ghostMode != next.ghostMode) apply();
    })
    ..listen(authStateProvider, (_, next) {
      if (next.value is AuthReady) apply();
    }, fireImmediately: true);
});
