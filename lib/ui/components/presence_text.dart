import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../data/chats/chat_summary.dart';
import '../../data/users/users_repository.dart';

String presenceText(
  AppLocalizations l10n,
  Presence p,
  DateTime now,
  String locale,
) {
  return switch (p) {
    Online() => l10n.statusOnline,
    LastSeen(:final at) => _lastSeen(l10n, at, now, locale),
    SeenRecently() => l10n.statusRecently,
    SeenWithin(:final week) => week ? l10n.statusWeek : l10n.statusMonth,
    PresenceHidden() => l10n.statusLongAgo,
  };
}

String _lastSeen(AppLocalizations l10n, DateTime at, DateTime now, String loc) {
  final time = DateFormat.Hm(loc).format(at);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l10n.statusLastSeenAt(time);
  if (diff == 1) return l10n.statusLastSeenYesterday(time);
  return l10n.statusLastSeenDate(DateFormat('dd.MM.yy', loc).format(at));
}

String typingText(
  AppLocalizations l10n,
  Map<int, TypingKind> typing,
  UsersRepository users, {
  required bool group,
}) {
  if (typing.isEmpty) return '';
  if (typing.length > 1) return l10n.typingMany(typing.length);
  final MapEntry(key: userId, value: kind) = typing.entries.first;
  final action = switch (kind) {
    TypingKind.typing => l10n.typing,
    TypingKind.voice => l10n.typingVoice,
    TypingKind.video => l10n.typingVideo,
    TypingKind.upload => l10n.typingUpload,
    TypingKind.sticker => l10n.typingSticker,
    TypingKind.other => l10n.typingOther,
  };
  if (!group) return action;
  final name = users.user(userId)?.firstName ?? '';
  return name.isEmpty ? action : l10n.typingNamed(name, action);
}

/// Subtitle under a chat title: presence, member count or typing.
String chatSubtitle(
  AppLocalizations l10n,
  ChatSummary chat,
  UsersRepository users,
  DateTime now,
  String locale,
) {
  final group = chat.peer.userId == null;
  final typing = typingText(l10n, users.typingIn(chat.id), users, group: group);
  if (typing.isNotEmpty) return typing;
  final p = chat.peer;
  if (p.userId != null) {
    final u = users.user(p.userId!);
    if (u == null) return '';
    if (u.isBot) return l10n.statusBot;
    return presenceText(l10n, u.presence, now, locale);
  }
  final n = users.memberCount(
    basicGroupId: p.basicGroupId,
    supergroupId: p.supergroupId,
  );
  if (n == null || n == 0) return '';
  return p.isChannel ? l10n.subscribersCount(n) : l10n.membersCount(n);
}

String dayLabel(AppLocalizations l10n, DateTime d, DateTime now, String loc) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l10n.today;
  if (diff == 1) return l10n.yesterday;
  if (d.year == now.year) return DateFormat.MMMMd(loc).format(d);
  return DateFormat.yMMMMd(loc).format(d);
}
