import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/l10n.dart';
import '../../core/util/phone.dart';
import '../../ui/components/avatar.dart';
import '../../ui/theme/chat_colors.dart';

final themeModeProvider = NotifierProvider<ThemeModeSetting, ThemeMode>(
  ThemeModeSetting.new,
);

class ThemeModeSetting extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggle() =>
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    final me = ref.watch(meProvider).value;
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Drawer(
      width: 300,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
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
                  id: me?.id ?? 0,
                  title: me?.name ?? '',
                  photo: me?.photo,
                  size: 64,
                ),
                const SizedBox(height: 12),
                Text(
                  me?.name ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (me != null && me.phone.isNotEmpty)
                  Text(
                    maskPhone(me.phone),
                    style: TextStyle(color: colors.secondary),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: Text(l10n.menuNightMode),
            trailing: Switch(
              value: dark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
            ),
            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.actionLogOut),
            onTap: () {
              Navigator.pop(context);
              unawaited(ref.read(authRepositoryProvider).logOut());
            },
          ),
        ],
      ),
    );
  }
}
