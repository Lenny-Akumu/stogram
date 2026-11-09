import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth/auth_state.dart';
import '../features/auth/auth_screen.dart';
import '../features/settings/appearance_screen.dart';
import '../features/settings/ayu_settings_screen.dart';
import '../features/settings/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../ui/shell/classic_shell.dart';
import 'providers.dart';

abstract final class Routes {
  static const auth = '/auth';
  static const chats = '/chats';
  static String chat(int id) => '/chats/$id';
  static const settings = '/settings';
  static const ayu = '/settings/ayu';
  static const profile = '/settings/profile';
  static const appearance = '/settings/appearance';
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
      GoRoute(
        path: Routes.settings,
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(path: 'ayu', builder: (_, _) => const AyuSettingsScreen()),
          GoRoute(path: 'profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(
            path: 'appearance',
            builder: (_, _) => const AppearanceScreen(),
          ),
        ],
      ),
      GoRoute(path: Routes.auth, builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: Routes.chats,
        builder: (_, _) => const ClassicShell(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                ClassicShell(chatId: int.parse(state.pathParameters['id']!)),
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
