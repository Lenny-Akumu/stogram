import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ayu/ayu_settings.dart';
import '../../core/l10n/l10n.dart';
import '../../ui/theme/chat_colors.dart';

class AyuSettingsScreen extends ConsumerWidget {
  const AyuSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    final s = ref.watch(ayuSettingsProvider);
    final n = ref.read(ayuSettingsProvider.notifier);

    Widget tile(
      String title,
      String desc,
      bool value,
      Future<void> Function(bool) set, {
      IconData? icon,
      bool enabled = true,
    }) => SwitchListTile(
      secondary: icon == null ? null : Icon(icon, color: colors.accent),
      title: Text(title),
      subtitle: Text(desc, style: TextStyle(color: colors.secondary)),
      value: value,
      onChanged: enabled ? (v) => unawaited(set(v)) : null,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ayuTitle)),
      body: ListView(
        children: [
          tile(
            l10n.ayuGhost,
            l10n.ayuGhostDesc,
            s.ghostMode,
            n.setGhostMode,
            icon: Icons.visibility_off_outlined,
          ),
          tile(
            l10n.ayuReadSilently,
            l10n.ayuReadSilentlyDesc,
            s.readSilentlyOnReply,
            n.setReadSilentlyOnReply,
            icon: Icons.mark_chat_read_outlined,
            enabled: s.ghostMode,
          ),
          const Divider(),
          tile(
            l10n.ayuSaveDeleted,
            l10n.ayuSaveDeletedDesc,
            s.saveDeleted,
            n.setSaveDeleted,
            icon: Icons.delete_sweep_outlined,
          ),
          tile(
            l10n.ayuEditHistory,
            l10n.ayuEditHistoryDesc,
            s.editHistory,
            n.setEditHistory,
            icon: Icons.history,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.ayuTosWarning,
              style: TextStyle(color: colors.secondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
