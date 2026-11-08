import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth/auth_state.dart';
import '../features/auth/auth_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/chat_list/chat_list_screen.dart';
import 'providers.dart';

abstract final class Routes {
  static const auth = '/auth';
  static const chats = '/chats';
  static String chat(int id) => '/chats/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthState>(const AuthLoading());
  ref.listen(authStateProvider, (_, next) {
    final value = next.value;
    if (value != null) auth.value = value;
  }, fireImmediately: true);

  final router = GoRouter(
    initialLocation: Routes.auth,
    refreshListenable: auth,
    redirect: (context, state) {
      final ready = auth.value is AuthReady;
      final atAuth = state.matchedLocation == Routes.auth;
      if (ready && atAuth) return Routes.chats;
      if (!ready && !atAuth) return Routes.auth;
      return null;
    },
    routes: [
      GoRoute(path: Routes.auth, builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: Routes.chats,
        builder: (_, _) => const ChatListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                ChatScreen(chatId: int.parse(state.pathParameters['id']!)),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    auth.dispose();
  });
  return router;
});
