import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/l10n.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.chatsPlaceholder),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => ref.read(authRepositoryProvider).logOut(),
              child: Text(context.l10n.actionLogOut),
            ),
          ],
        ),
      ),
    );
  }
}
