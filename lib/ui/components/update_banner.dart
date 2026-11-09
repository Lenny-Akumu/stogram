import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/update/update_controller.dart';

/// Wraps the whole app and slides an update strip in on top.
class UpdateGate extends ConsumerWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateProvider);
    if (state is UpdateIdle) return child;
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SafeArea(bottom: false, child: _Strip(state: state)),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _Strip extends ConsumerWidget {
  const _Strip({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ctrl = ref.read(updateProvider.notifier);
    void start() => unawaited(ctrl.start());

    final (
      String text,
      List<Widget> actions,
      double? progress,
    ) = switch (state) {
      UpdateAvailable(:final release) => (
        l10n.updateAvailable(release.tag),
        [
          TextButton(onPressed: ctrl.dismiss, child: Text(l10n.updateLater)),
          FilledButton(onPressed: start, child: Text(l10n.updateAction)),
        ],
        null,
      ),
      UpdateDownloading(:final progress) => (
        l10n.updateDownloading((progress * 100).round()),
        const <Widget>[],
        progress,
      ),
      UpdateInstalling() => (l10n.updateInstalling, const <Widget>[], null),
      UpdateReady(:final needsPermission) => (
        needsPermission ? l10n.updatePermission : l10n.updateReady,
        [FilledButton(onPressed: start, child: Text(l10n.updateInstallAction))],
        null,
      ),
      UpdateFailed() => (
        l10n.updateFailed,
        [
          TextButton(onPressed: ctrl.dismiss, child: Text(l10n.updateLater)),
          FilledButton(onPressed: start, child: Text(l10n.updateRetry)),
        ],
        null,
      ),
      UpdateIdle() => ('', const <Widget>[], null),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.system_update_alt, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
              for (final a in actions)
                Padding(padding: const EdgeInsets.only(left: 8), child: a),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
          ],
        ],
      ),
    );
  }
}
