import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/skin_provider.dart';
import '../theme/skins.dart';
import 'classic_shell.dart';
import 'edge_shell.dart';

/// Picks the layout the current skin asks for.
class ShellSwitch extends ConsumerWidget {
  const ShellSwitch({super.key, this.chatId});

  final int? chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(effectiveLayoutProvider)) {
      SkinLayout.edge => EdgeShell(chatId: chatId),
      SkinLayout.classic => ClassicShell(chatId: chatId),
    };
  }
}
