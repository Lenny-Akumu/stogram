import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/l10n/l10n.dart';
import '../../core/util/phone.dart';
import '../../ui/components/avatar.dart';
import '../../ui/theme/chat_colors.dart';
import '../../ui/theme/skin_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    ref.watch(usersChangedProvider);
    final me = ref.watch(meProvider).value;
    final user = me == null
        ? null
        : ref.read(usersRepositoryProvider).user(me.id) ?? me;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Avatar(
              id: user?.id ?? 0,
              title: user?.name ?? '',
              photo: user?.photo,
              size: 60,
            ),
            title: Text(
              user?.name ?? '',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                if (user != null && user.phone.isNotEmpty)
                  maskPhone(user.phone),
                if (user != null && user.username.isNotEmpty)
                  '@${user.username}',
              ].join(' · '),
              style: TextStyle(color: colors.secondary),
            ),
            onTap: () => unawaited(context.push(Routes.profile)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.menuProfile),
            onTap: () => unawaited(context.push(Routes.profile)),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.menuAppearance),
            subtitle: Text(
              ref.watch(skinProvider).name,
              style: TextStyle(color: colors.secondary),
            ),
            onTap: () => unawaited(context.push(Routes.appearance)),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(l10n.menuAyu),
            onTap: () => unawaited(context.push(Routes.ayu)),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: colors.deleted),
            title: Text(
              l10n.actionLogOut,
              style: TextStyle(color: colors.deleted),
            ),
            onTap: () => unawaited(ref.read(authRepositoryProvider).logOut()),
          ),
        ],
      ),
    );
  }
}
