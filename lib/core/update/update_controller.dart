import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import 'release.dart';
import 'updater.dart';

sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.release);
  final ReleaseInfo release;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.release, this.progress);
  final ReleaseInfo release;
  final double progress;
}

class UpdateInstalling extends UpdateState {
  const UpdateInstalling(this.release);
  final ReleaseInfo release;
}

/// Downloaded; installing again is one tap away.
class UpdateReady extends UpdateState {
  const UpdateReady(this.release, this.path, {this.needsPermission = false});
  final ReleaseInfo release;
  final String path;
  final bool needsPermission;
}

class UpdateFailed extends UpdateState {
  const UpdateFailed(this.release, this.error);
  final ReleaseInfo release;
  final String error;
}

final updaterProvider = Provider<Updater>((_) => GithubUpdater());

final currentTagProvider = Provider<String>((_) => Env.buildTag);

final updateProvider = NotifierProvider<UpdateController, UpdateState>(
  UpdateController.new,
);

class UpdateController extends Notifier<UpdateState> {
  static const interval = Duration(hours: 6);

  bool _dismissed = false;

  Updater get _updater => ref.read(updaterProvider);

  @override
  UpdateState build() {
    if (!_updater.supported) return const UpdateIdle();
    final timer = Timer.periodic(interval, (_) => unawaited(check()));
    ref.onDispose(timer.cancel);
    Future.microtask(check);
    return const UpdateIdle();
  }

  Future<void> check() async {
    if (state is! UpdateIdle) return;
    try {
      final release = await _updater.latest();
      if (!_dismissed && isUpdate(release, ref.read(currentTagProvider))) {
        state = UpdateAvailable(release!);
      }
    } catch (_) {
      // offline or rate limited, try again next round
    }
  }

  void dismiss() {
    _dismissed = true;
    state = const UpdateIdle();
  }

  Future<void> start() async {
    switch (state) {
      case UpdateReady(:final release, :final path):
        await _install(release, path);
      case UpdateAvailable(:final release) || UpdateFailed(:final release):
        await _download(release);
      default:
    }
  }

  Future<void> _download(ReleaseInfo release) async {
    state = UpdateDownloading(release, 0);
    try {
      final path = await _updater.download(release, (p) {
        state = UpdateDownloading(release, p);
      });
      await _install(release, path);
    } catch (e) {
      state = UpdateFailed(release, '$e');
    }
  }

  Future<void> _install(ReleaseInfo release, String path) async {
    state = UpdateInstalling(release);
    try {
      await _updater.install(path);
      // desktop restarts before getting here, Android shows its installer
      state = UpdateReady(release, path);
    } on InstallPermissionRequired {
      state = UpdateReady(release, path, needsPermission: true);
    } catch (e) {
      state = UpdateFailed(release, '$e');
    }
  }
}
