import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../ui/theme/chat_colors.dart';
import '../../ui/theme/skin_provider.dart';
import '../../ui/theme/skins.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(skinProvider);
    final colors = ChatColors.of(context);

    String groupName(SkinGroup g) => switch (g) {
      SkinGroup.classic => l10n.skinGroupClassic,
      SkinGroup.v4 => l10n.skinGroupV4,
      SkinGroup.v3 => l10n.skinGroupV3,
      SkinGroup.v2 => l10n.skinGroupV2,
      SkinGroup.v1 => l10n.skinGroupV1,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearanceTitle)),
      body: CustomScrollView(
        slivers: [
          for (final group in SkinGroup.values) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  groupName(group),
                  style: TextStyle(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid.extent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
                children: [
                  for (final s in skins.where((s) => s.group == group))
                    SkinCard(
                      skin: s,
                      selected: s.id == current.id,
                      onTap: () =>
                          unawaited(ref.read(skinProvider.notifier).select(s)),
                    ),
                ],
              ),
            ),
          ],
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Text(
                l10n.skinLayoutNote,
                style: TextStyle(color: colors.secondary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SkinCard extends StatelessWidget {
  const SkinCard({
    super.key,
    required this.skin,
    required this.selected,
    required this.onTap,
  });

  final Skin skin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = skin.colors;
    final l10n = context.l10n;
    final accent = ChatColors.of(context).accent;

    Widget bubble(String text, {required bool out}) => Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: out ? c.bubbleOut : c.bubbleIn,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: out ? c.textOut : c.textIn),
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 3,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: ColoredBox(
            color: c.chatBackground,
            child: Column(
              children: [
                Container(
                  height: 28,
                  color: c.panel,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 7, backgroundColor: c.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: c.secondary.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        bubble(l10n.previewIncoming, out: false),
                        bubble(l10n.previewOutgoing, out: true),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: c.panel,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (selected)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.check_circle,
                            size: 14,
                            color: c.accent,
                          ),
                        ),
                      Flexible(
                        child: Text(
                          skin.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textIn,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
