import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/ayu/ayu_settings.dart';
import '../../core/l10n/l10n.dart';
import '../../core/util/phone.dart';
import '../../ui/components/avatar.dart';
import '../../ui/theme/chat_colors.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    ref.watch(usersChangedProvider);
    final me = ref.watch(meProvider).value;
    final fresh = me == null
        ? null
        : ref.read(usersRepositoryProvider).user(me.id);
    final user = fresh ?? me;

    void go(String route) {
      Navigator.pop(context);
      unawaited(context.push(route));
    }

    return Drawer(
      width: 300,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          InkWell(
            onTap: () => go(Routes.profile),
            child: Container(
              color: colors.chatBackground,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 20,
                20,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Avatar(
                    id: user?.id ?? 0,
                    title: user?.name ?? '',
                    photo: user?.photo,
                    size: 64,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (user != null && user.phone.isNotEmpty)
                    Text(
                      maskPhone(user.phone),
                      style: TextStyle(color: colors.secondary),
                    ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.menuProfile),
            onTap: () => go(Routes.profile),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.menuAppearance),
            onTap: () => go(Routes.appearance),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(l10n.menuAyu),
            trailing: ref.watch(ayuSettingsProvider).ghostMode
                ? Icon(Icons.visibility_off, color: colors.accent, size: 20)
                : null,
            onTap: () => go(Routes.ayu),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.menuSettings),
            onTap: () => go(Routes.settings),
          ),
        ],
      ),
    );
  }
}
