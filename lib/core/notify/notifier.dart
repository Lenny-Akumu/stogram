import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../data/chats/chat_summary.dart';
import '../../data/messages/chat_message.dart';
import '../ayu/ayu_settings.dart';
import '../tdlib/td_dispatcher.dart';

const _notifyKey = 'app.notify';

/// Shows a system notification for incoming messages the user is not looking at.
class MessageNotifier with WidgetsBindingObserver {
  MessageNotifier(this._ref);

  final Ref _ref;
  final _plugin = FlutterLocalNotificationsPlugin();
  final _started = DateTime.now();
  StreamSubscription<TdObject>? _sub;
  AppLifecycleState _life = AppLifecycleState.resumed;
  bool _ready = false;
  void Function(int chatId)? onOpen;

  bool get enabled =>
      _ref.read(sharedPrefsProvider)?.getBool(_notifyKey) ?? true;

  Future<void> start() async {
    if (kIsWeb ||
        !(Platform.isAndroid || Platform.isLinux || Platform.isWindows)) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    try {
      _ready =
          await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('ic_notify'),
              linux: LinuxInitializationSettings(defaultActionName: 'Open'),
              windows: WindowsInitializationSettings(
                appName: 'stogram',
                appUserModelId: 'dev.lenny.app',
                guid: '6b0f3c4e-58c1-4d1a-9f63-2a7d5e1b9c40',
              ),
            ),
            onDidReceiveNotificationResponse: (r) {
              final id = int.tryParse(r.payload ?? '');
              if (id != null) onOpen?.call(id);
            },
          ) ??
          false;
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }
    } on Object {
      _ready = false;
    }
    _sub = _ref.read(tdApiProvider).updates.listen(_onUpdate);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _life = state;

  void _onUpdate(TdObject u) {
    if (!_ready || !enabled || u['@type'] != 'updateNewMessage') return;
    final raw = u['message'] as TdObject;
    if (raw['is_outgoing'] == true) return;
    final m = ChatMessage.fromJson(raw);
    if (m.date.isBefore(_started)) return;
    final chat = _ref.read(chatsRepositoryProvider).byId(m.chatId);
    if (chat == null || chat.isMuted) return;
    final looking =
        _life == AppLifecycleState.resumed &&
        _ref.read(selectedChatProvider) == m.chatId;
    if (looking) return;
    unawaited(_show(chat, m));
  }

  Future<void> _show(ChatSummary chat, ChatMessage m) async {
    final users = _ref.read(usersRepositoryProvider);
    final sender = m.senderUserId == null
        ? null
        : users.nameOf(m.senderUserId!);
    final text = m.content.text.isEmpty ? '…' : m.content.text;
    final body = chat.isGroup && sender != null ? '$sender: $text' : text;
    try {
      await _plugin.show(
        id: m.chatId.hashCode & 0x7fffffff,
        title: chat.title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'messages',
            'Messages',
            importance: Importance.high,
            priority: Priority.high,
          ),
          linux: LinuxNotificationDetails(),
          windows: WindowsNotificationDetails(),
        ),
        payload: '${m.chatId}',
      );
    } on Object {
      // notifications are best effort
    }
  }

  Future<void> clear(int chatId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: chatId.hashCode & 0x7fffffff);
    } on Object {
      return;
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _sub?.cancel();
  }
}

final messageNotifierProvider = Provider<MessageNotifier>((ref) {
  final n = MessageNotifier(ref);
  ref.onDispose(() => unawaited(n.dispose()));
  return n;
});

final notifyEnabledProvider = NotifierProvider<NotifyEnabled, bool>(
  NotifyEnabled.new,
);

class NotifyEnabled extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedPrefsProvider)?.getBool(_notifyKey) ?? true;

  Future<void> set(bool v) async {
    state = v;
    await ref.read(sharedPrefsProvider)?.setBool(_notifyKey, v);
  }
}

/// True only in the real app; tests keep the platform plugin out.
final nativeNotificationsProvider = Provider<bool>((_) => false);

final notifierBootProvider = Provider<void>((ref) {
  if (!ref.watch(nativeNotificationsProvider)) return;
  final n = ref.watch(messageNotifierProvider)
    ..onOpen = (id) {
      ref.read(selectedChatProvider.notifier).select(id);
      ref.read(routerProvider).go(Routes.chat(id));
    };
  unawaited(n.start());
});
