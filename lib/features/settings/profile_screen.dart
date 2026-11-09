import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/l10n.dart';
import '../../core/tdlib/td_error.dart';
import '../../ui/components/avatar.dart';
import '../../ui/theme/chat_colors.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _bio = TextEditingController();
  final _username = TextEditingController();
  bool _filled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final users = ref.read(usersRepositoryProvider);
    final me = users.me ?? await ref.read(meProvider.future);
    if (me == null) return;
    await users.loadFullInfo(me.id);
    final u = users.user(me.id) ?? me;
    if (!mounted) return;
    setState(() {
      _first.text = u.firstName;
      _last.text = u.lastName;
      _bio.text = u.bio;
      _username.text = u.username;
      _filled = true;
    });
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _bio.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final users = ref.read(usersRepositoryProvider);
    final me = users.me;
    if (me == null || _busy) return;
    setState(() => _busy = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_first.text.trim() != me.firstName ||
          _last.text.trim() != me.lastName) {
        await users.setName(_first.text.trim(), _last.text.trim());
      }
      if (_bio.text.trim() != me.bio) await users.setBio(_bio.text.trim());
      final name = _username.text.trim().replaceFirst('@', '');
      if (name != me.username) await users.setUsername(name);
      await users.loadFullInfo(me.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    } on TdError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileSaveError(e.message))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPhoto() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp']),
      ],
    );
    if (file == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(usersRepositoryProvider).setPhoto(file.path);
    } on TdError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileSaveError(e.message))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    ref.watch(usersChangedProvider);
    final users = ref.read(usersRepositoryProvider);
    final me = users.me;

    InputDecoration deco(String label, [String? hint]) => InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: colors.secondary),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            tooltip: l10n.actionSave,
            onPressed: _busy || !_filled ? null : _save,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: !_filled
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Stack(
                    children: [
                      Avatar(
                        id: me?.id ?? 0,
                        title: me?.name ?? '',
                        photo: me?.photo,
                        size: 110,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton.filled(
                          tooltip: l10n.profileChangePhoto,
                          onPressed: _pickPhoto,
                          icon: const Icon(Icons.photo_camera),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _first,
                  decoration: deco(l10n.profileFirstName),
                ),
                TextField(
                  controller: _last,
                  decoration: deco(l10n.profileLastName),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bio,
                  maxLength: 70,
                  maxLines: 3,
                  minLines: 1,
                  decoration: deco(l10n.profileBio, l10n.profileBioHint),
                ),
                TextField(
                  controller: _username,
                  decoration: deco(
                    l10n.profileUsername,
                    l10n.profileUsernameHint,
                  ).copyWith(prefixText: '@'),
                ),
              ],
            ),
    );
  }
}
