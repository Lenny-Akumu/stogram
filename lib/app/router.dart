import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth/auth_state.dart';
import '../features/auth/auth_screen.dart';
import '../features/settings/appearance_screen.dart';
import '../features/settings/ayu_settings_screen.dart';
import '../features/settings/basic_settings.dart';
import '../features/settings/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../ui/shell/shell_switch.dart';
import 'providers.dart';

abstract final class Routes {
  static const auth = '/auth';
  static const chats = '/chats';
  static String chat(int id) => '/chats/$id';
  static const settings = '/settings';
  static const ayu = '/settings/ayu';
  static const profile = '/settings/profile';
  static const appearance = '/settings/appearance';
  static const privacy = '/settings/privacy';
  static const sessions = '/settings/sessions';
  static const notifications = '/settings/notifications';
  static const storage = '/settings/storage';
  static const chatSettings = '/settings/chat';
  static const sound = '/settings/sound';
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
          GoRoute(path: 'privacy', builder: (_, _) => const PrivacyScreen()),
          GoRoute(path: 'sessions', builder: (_, _) => const SessionsScreen()),
          GoRoute(
            path: 'notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(path: 'storage', builder: (_, _) => const StorageScreen()),
          GoRoute(path: 'chat', builder: (_, _) => const ChatSettingsScreen()),
          GoRoute(
            path: 'sound',
            builder: (_, _) => const SoundSettingsScreen(),
          ),
        ],
      ),
      GoRoute(path: Routes.auth, builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: Routes.chats,
        builder: (_, _) => const ShellSwitch(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                ShellSwitch(chatId: int.parse(state.pathParameters['id']!)),
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
