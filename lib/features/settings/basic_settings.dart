import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/ayu/ayu_settings.dart';
import '../../core/l10n/l10n.dart';
import '../../core/notify/notifier.dart';
import '../../core/settings/app_prefs.dart';
import '../../core/settings/voice_prefs.dart';
import '../../core/tdlib/td_dispatcher.dart';
import '../../core/tdlib/td_error.dart';
import '../../ui/components/avatar.dart';
import '../../ui/theme/chat_colors.dart';

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Widget _header(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
  child: Text(
    text,
    style: TextStyle(
      color: ChatColors.of(context).accent,
      fontWeight: FontWeight.w600,
    ),
  ),
);

enum Visibility3 { everyone, contacts, nobody }

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  static const _settings = [
    'userPrivacySettingShowPhoneNumber',
    'userPrivacySettingShowStatus',
    'userPrivacySettingShowProfilePhoto',
    'userPrivacySettingShowBio',
    'userPrivacySettingShowLinkInForwardedMessages',
    'userPrivacySettingAllowCalls',
    'userPrivacySettingAllowChatInvites',
    'userPrivacySettingAllowPrivateVoiceAndVideoNoteMessages',
  ];
  final _values = <String, Visibility3>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final td = ref.read(tdApiProvider);
    for (final s in _settings) {
      try {
        final res = await td.send({
          '@type': 'getUserPrivacySettingRules',
          'setting': {'@type': s},
        });
        final types = [
          for (final r in (res['rules'] as List? ?? const []))
            (r as TdObject)['@type'],
        ];
        _values[s] = types.contains('userPrivacySettingRuleAllowAll')
            ? Visibility3.everyone
            : types.contains('userPrivacySettingRuleAllowContacts')
            ? Visibility3.contacts
            : Visibility3.nobody;
      } on TdError {
        continue;
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _set(String s, Visibility3 v) async {
    setState(() => _values[s] = v);
    try {
      await ref.read(tdApiProvider).send({
        '@type': 'setUserPrivacySettingRules',
        'setting': {'@type': s},
        'rules': {
          '@type': 'userPrivacySettingRules',
          'rules': [
            switch (v) {
              Visibility3.everyone => {
                '@type': 'userPrivacySettingRuleAllowAll',
              },
              Visibility3.contacts => {
                '@type': 'userPrivacySettingRuleAllowContacts',
              },
              Visibility3.nobody => {
                '@type': 'userPrivacySettingRuleRestrictAll',
              },
            },
          ],
        },
      });
    } on TdError catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  String _title(BuildContext context, String s) {
    final l = context.l10n;
    return switch (s) {
      'userPrivacySettingShowPhoneNumber' => l.privacyPhone,
      'userPrivacySettingShowStatus' => l.privacyLastSeen,
      'userPrivacySettingShowProfilePhoto' => l.privacyPhoto,
      'userPrivacySettingShowBio' => l.privacyBio,
      'userPrivacySettingShowLinkInForwardedMessages' => l.privacyForwards,
      'userPrivacySettingAllowCalls' => l.privacyCalls,
      'userPrivacySettingAllowChatInvites' => l.privacyInvites,
      _ => l.privacyVoice,
    };
  }

  String _label(BuildContext context, Visibility3 v) => switch (v) {
    Visibility3.everyone => context.l10n.privacyEveryone,
    Visibility3.contacts => context.l10n.privacyContacts,
    Visibility3.nobody => context.l10n.privacyNobody,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    final ghost = ref.watch(ayuSettingsProvider).ghostMode;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.menuPrivacy)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.block),
            title: Text(l10n.blockedTitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BlockedScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: Text(l10n.menuSessions),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SessionsScreen()),
            ),
          ),
          _header(context, l10n.privacySection),
          for (final s in _settings)
            ListTile(
              title: Text(_title(context, s)),
              subtitle: Text(
                _values[s] == null ? '…' : _label(context, _values[s]!),
                style: TextStyle(color: colors.accent),
              ),
              onTap: _values[s] == null
                  ? null
                  : () async {
                      final v = await showDialog<Visibility3>(
                        context: context,
                        builder: (d) => SimpleDialog(
                          title: Text(_title(context, s)),
                          children: [
                            for (final v in Visibility3.values)
                              ListTile(
                                leading: Icon(
                                  v == _values[s]
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: colors.accent,
                                ),
                                title: Text(_label(context, v)),
                                onTap: () => Navigator.pop(d, v),
                              ),
                          ],
                        ),
                      );
                      if (v != null) await _set(s, v);
                    },
            ),
          if (ghost)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.privacyGhostHint,
                style: TextStyle(color: colors.secondary, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  List<TdObject>? _sessions;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(tdApiProvider).send({
        '@type': 'getActiveSessions',
      });
      _sessions = [
        for (final s in (res['sessions'] as List? ?? const [])) s as TdObject,
      ];
    } on TdError {
      _sessions = const [];
    }
    if (mounted) setState(() {});
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(context.l10n.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(context.l10n.sessionsTerminate),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _run(TdObject req) async {
    try {
      await ref.read(tdApiProvider).send(req);
    } on TdError catch (e) {
      if (mounted) _snack(context, e.message);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    final list = _sessions;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = DateFormat('dd.MM.yy HH:mm', locale);
    Widget tile(TdObject s) {
      final last = DateTime.fromMillisecondsSinceEpoch(
        (s['last_active_date'] as int? ?? 0) * 1000,
      );
      final current = s['is_current'] == true;
      return ListTile(
        leading: Icon(switch ((s['device_type'] as TdObject?)?['@type']) {
          'sessionTypeAndroid' => Icons.android,
          'sessionTypeApple' || 'sessionTypeIphone' => Icons.phone_iphone,
          'sessionTypeChrome' ||
          'sessionTypeFirefox' ||
          'sessionTypeSafari' ||
          'sessionTypeEdge' => Icons.language,
          _ => Icons.computer,
        }, color: colors.accent),
        title: Text(
          '${s['application_name']} ${s['application_version']}',
          maxLines: 1,
        ),
        subtitle: Text(
          [
            '${s['device_model']}, ${s['platform']} ${s['system_version']}',
            [
              s['location'] as String? ?? '',
              if (!current) fmt.format(last),
            ].where((e) => e.isNotEmpty).join(' · '),
          ].join('\n'),
          style: TextStyle(color: colors.secondary),
        ),
        isThreeLine: true,
        onTap: current
            ? null
            : () async {
                if (await _confirm(l10n.sessionsTerminateOne)) {
                  await _run({
                    '@type': 'terminateSession',
                    'session_id': s['id'],
                  });
                }
              },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.menuSessions)),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _header(context, l10n.sessionsCurrent),
                ...list.where((s) => s['is_current'] == true).map(tile),
                if (list.length > 1) ...[
                  ListTile(
                    leading: Icon(Icons.back_hand, color: colors.deleted),
                    title: Text(
                      l10n.sessionsTerminateAll,
                      style: TextStyle(color: colors.deleted),
                    ),
                    onTap: () async {
                      if (await _confirm(l10n.sessionsTerminateAllAsk)) {
                        await _run({'@type': 'terminateAllOtherSessions'});
                      }
                    },
                  ),
                  _header(context, l10n.sessionsOther),
                  ...list.where((s) => s['is_current'] != true).map(tile),
                ],
              ],
            ),
    );
  }
}

class BlockedScreen extends ConsumerStatefulWidget {
  const BlockedScreen({super.key});

  @override
  ConsumerState<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends ConsumerState<BlockedScreen> {
  List<TdObject>? _senders;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(tdApiProvider).send({
        '@type': 'getBlockedMessageSenders',
        'block_list': {'@type': 'blockListMain'},
        'offset': 0,
        'limit': 100,
      });
      _senders = [
        for (final s in (res['senders'] as List? ?? const [])) s as TdObject,
      ];
      final users = ref.read(usersRepositoryProvider);
      for (final s in _senders!) {
        final id = s['user_id'] as int?;
        if (id != null) await users.load(id);
      }
    } on TdError {
      _senders = const [];
    }
    if (mounted) setState(() {});
  }

  Future<void> _unblock(TdObject sender) async {
    try {
      await ref.read(tdApiProvider).send({
        '@type': 'setMessageSenderBlockList',
        'sender_id': sender,
        'block_list': null,
      });
    } on TdError catch (e) {
      if (mounted) _snack(context, e.message);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.watch(usersChangedProvider);
    final users = ref.read(usersRepositoryProvider);
    final list = _senders;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.blockedTitle)),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
          ? Center(child: Text(l10n.blockedEmpty))
          : ListView(
              children: [
                for (final s in list)
                  () {
                    final id =
                        s['user_id'] as int? ?? s['chat_id'] as int? ?? 0;
                    final u = users.user(id);
                    return ListTile(
                      leading: Avatar(
                        id: id,
                        title: u?.name ?? '$id',
                        photo: u?.photo,
                        size: 40,
                      ),
                      title: Text(u?.name ?? '$id'),
                      trailing: TextButton(
                        onPressed: () => _unblock(s),
                        child: Text(l10n.blockedUnblock),
                      ),
                    );
                  }(),
              ],
            ),
    );
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const _scopes = [
    'notificationSettingsScopePrivateChats',
    'notificationSettingsScopeGroupChats',
    'notificationSettingsScopeChannelChats',
  ];
  final _values = <String, TdObject>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    for (final s in _scopes) {
      try {
        _values[s] = await ref.read(tdApiProvider).send({
          '@type': 'getScopeNotificationSettings',
          'scope': {'@type': s},
        });
      } on TdError {
        continue;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _update(String scope, Map<String, Object?> patch) async {
    final next = {...?_values[scope], ...patch}
      ..['@type'] = 'scopeNotificationSettings';
    setState(() => _values[scope] = next);
    try {
      await ref.read(tdApiProvider).send({
        '@type': 'setScopeNotificationSettings',
        'scope': {'@type': scope},
        'notification_settings': next,
      });
    } on TdError catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titles = [l10n.notifPrivate, l10n.notifGroups, l10n.notifChannels];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.menuNotifications)),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.notifDevice),
            subtitle: Text(l10n.notifDeviceHint),
            value: ref.watch(notifyEnabledProvider),
            onChanged: ref.read(notifyEnabledProvider.notifier).set,
          ),
          for (final (i, s) in _scopes.indexed) ...[
            _header(context, titles[i]),
            if (_values[s] case final v?) ...[
              SwitchListTile(
                title: Text(l10n.notifEnabled),
                value: (v['mute_for'] as int? ?? 0) == 0,
                onChanged: (on) =>
                    _update(s, {'mute_for': on ? 0 : 0x7fffffff}),
              ),
              SwitchListTile(
                title: Text(l10n.notifPreview),
                value: v['show_preview'] != false,
                onChanged: (on) => _update(s, {'show_preview': on}),
              ),
              if (i > 0)
                SwitchListTile(
                  title: Text(l10n.notifPinned),
                  value: v['disable_pinned_message_notifications'] != true,
                  onChanged: (on) =>
                      _update(s, {'disable_pinned_message_notifications': !on}),
                ),
            ] else
              const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  TdObject? _stats;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      _stats = await ref.read(tdApiProvider).send({
        '@type': 'getStorageStatisticsFast',
      });
    } on TdError {
      _stats = const {};
    }
    if (mounted) setState(() {});
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    try {
      await ref.read(tdApiProvider).send({
        '@type': 'optimizeStorage',
        'size': 0,
        'ttl': 0,
        'count': 0,
        'immunity_delay': 0,
        'file_types': <Object>[],
        'chat_ids': <Object>[],
        'exclude_chat_ids': <Object>[],
        'return_deleted_file_statistics': false,
        'chat_limit': 0,
      });
    } on TdError catch (e) {
      if (mounted) _snack(context, e.message);
    }
    _busy = false;
    await _load();
  }

  static String _size(num bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB'];
    var v = bytes / 1024;
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v < 10 ? 1 : 0)} ${units[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = _stats;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.menuStorage)),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  title: Text(l10n.storageFiles),
                  trailing: Text(
                    '${_size(s['files_size'] as num? ?? 0)} · '
                    '${s['file_count'] ?? 0}',
                  ),
                ),
                ListTile(
                  title: Text(l10n.storageDb),
                  trailing: Text(_size(s['database_size'] as num? ?? 0)),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _clear,
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: Text(l10n.storageClear),
                  ),
                ),
              ],
            ),
    );
  }
}

class ChatSettingsScreen extends ConsumerWidget {
  const ChatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(appPrefsProvider);
    final n = ref.read(appPrefsProvider.notifier);
    final colors = ChatColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.menuChatSettings)),
      body: ListView(
        children: [
          _header(context, l10n.settingsLanguage),
          for (final (code, name) in [
            ('uk', 'Українська'),
            ('en', 'English'),
            ('system', l10n.languageSystem),
          ])
            ListTile(
              leading: Icon(
                prefs.language == code
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: colors.accent,
              ),
              title: Text(name),
              onTap: () => n.setLanguage(code),
            ),
          _header(context, l10n.settingsTextSize),
          Slider(
            min: 0.85,
            max: 1.4,
            divisions: 11,
            value: prefs.textScale.clamp(0.85, 1.4),
            label: '${(prefs.textScale * 100).round()}%',
            onChanged: n.previewTextScale,
            onChangeEnd: n.setTextScale,
          ),
          SwitchListTile(
            title: Text(l10n.settingsSendWithEnter),
            subtitle: Text(
              l10n.settingsSendWithEnterHint,
              style: TextStyle(color: colors.secondary),
            ),
            value: prefs.sendWithEnter,
            onChanged: n.setSendWithEnter,
          ),
        ],
      ),
    );
  }
}

class SoundSettingsScreen extends ConsumerWidget {
  const SoundSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    final v = ref.watch(voicePrefsProvider);
    final n = ref.read(voicePrefsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.menuSound)),
      body: ListView(
        children: [
          _header(context, l10n.soundRecording),
          SwitchListTile(
            title: Text(l10n.soundDenoise),
            subtitle: Text(
              l10n.soundDenoiseHint,
              style: TextStyle(color: colors.secondary),
            ),
            value: v.denoise,
            onChanged: (on) => n.update(v.copyWith(denoise: on)),
          ),
          ListTile(
            enabled: v.denoise,
            title: Text(l10n.soundDenoiseStrength),
            subtitle: Slider(
              value: v.strength,
              divisions: 10,
              label: '${(v.strength * 100).round()}%',
              onChanged: v.denoise
                  ? (x) => n.update(v.copyWith(strength: x))
                  : null,
            ),
          ),
          SwitchListTile(
            title: Text(l10n.soundEcho),
            value: v.echoCancel,
            onChanged: (on) => n.update(v.copyWith(echoCancel: on)),
          ),
          SwitchListTile(
            title: Text(l10n.soundGain),
            value: v.autoGain,
            onChanged: (on) => n.update(v.copyWith(autoGain: on)),
          ),
        ],
      ),
    );
  }
}
