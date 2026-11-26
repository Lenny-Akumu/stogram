import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../ui/shell/edge_config.dart';
import '../../ui/theme/chat_colors.dart';

class EdgeTabsSettings extends ConsumerWidget {
  const EdgeTabsSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    final cfg = ref.watch(edgeConfigProvider);
    final n = ref.read(edgeConfigProvider.notifier);

    Widget side(String title, List<EdgePanel> tabs, bool left) {
      void save(List<EdgePanel> next) =>
          unawaited(n.setSide(left: left, tabs: next));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(title, style: TextStyle(color: colors.secondary)),
          ),
          for (var i = 0; i < tabs.length; i++)
            Row(
              children: [
                SizedBox(width: 22, child: Text('${i + 1}')),
                Expanded(
                  child: DropdownButton<EdgePanel>(
                    isExpanded: true,
                    value: tabs[i],
                    items: [
                      for (final p in EdgePanel.values)
                        DropdownMenuItem(
                          value: p,
                          child: Row(
                            children: [
                              Icon(p.icon, size: 18),
                              const SizedBox(width: 8),
                              Text(p.label(l10n)),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (p) {
                      if (p == null) return;
                      save([...tabs]..[i] = p);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: i == 0
                      ? null
                      : () {
                          final next = [...tabs];
                          final t = next.removeAt(i);
                          next.insert(i - 1, t);
                          save(next);
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: i == tabs.length - 1
                      ? null
                      : () {
                          final next = [...tabs];
                          final t = next.removeAt(i);
                          next.insert(i + 1, t);
                          save(next);
                        },
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: colors.deleted),
                  onPressed: tabs.length <= 1
                      ? null
                      : () => save([...tabs]..removeAt(i)),
                ),
              ],
            ),
          if (tabs.length < EdgeConfig.maxTabs)
            TextButton.icon(
              onPressed: () => save([...tabs, EdgePanel.emoji]),
              icon: const Icon(Icons.add),
              label: Text(l10n.edgeTabsAdd),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.edgeTabsTitle,
          style: TextStyle(color: colors.accent, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.edgeTabsHint,
          style: TextStyle(color: colors.secondary, fontSize: 13),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.edgeTabsIcons),
          value: cfg.showIcons,
          onChanged: (v) => unawaited(n.setShowIcons(v)),
        ),
        side(l10n.edgeTabsLeft, cfg.left, true),
        side(l10n.edgeTabsRight, cfg.right, false),
      ],
    );
  }
}
