import 'dart:async';

import '../../core/tdlib/td_api.dart';
import '../../core/tdlib/td_dispatcher.dart';
import '../../core/tdlib/td_error.dart';
import '../chats/chat_summary.dart';
import '../messages/message_media.dart';

sealed class Presence {
  const Presence();

  factory Presence.fromJson(TdObject? json) => switch (json?['@type']) {
    'userStatusOnline' => const Online(),
    'userStatusOffline' => LastSeen(
      DateTime.fromMillisecondsSinceEpoch(
        ((json?['was_online'] as int?) ?? 0) * 1000,
      ),
    ),
    'userStatusRecently' => const SeenRecently(),
    'userStatusLastWeek' => const SeenWithin(week: true),
    'userStatusLastMonth' => const SeenWithin(week: false),
    _ => const PresenceHidden(),
  };
}

class Online extends Presence {
  const Online();
}

class LastSeen extends Presence {
  const LastSeen(this.at);
  final DateTime at;
}

class SeenRecently extends Presence {
  const SeenRecently();
}

class SeenWithin extends Presence {
  const SeenWithin({required this.week});
  final bool week;
}

class PresenceHidden extends Presence {
  const PresenceHidden();
}

class TgUser {
  const TgUser({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.username = '',
    this.phone = '',
    this.bio = '',
    this.photo,
    this.presence = const PresenceHidden(),
    this.isBot = false,
  });

  factory TgUser.fromJson(TdObject json) {
    final names =
        (json['usernames'] as TdObject?)?['active_usernames'] as List?;
    return TgUser(
      id: json['id'] as int,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      username: names == null || names.isEmpty ? '' : names.first as String,
      phone: json['phone_number'] as String? ?? '',
      photo: chatPhoto(json['profile_photo'] as TdObject?),
      presence: Presence.fromJson(json['status'] as TdObject?),
      isBot: (json['type'] as TdObject?)?['@type'] == 'userTypeBot',
    );
  }

  final int id;
  final String firstName;
  final String lastName;
  final String username;
  final String phone;
  final String bio;
  final MediaImage? photo;
  final Presence presence;
  final bool isBot;

  String get name => [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

  TgUser copyWith({Presence? presence, String? bio}) => TgUser(
    id: id,
    firstName: firstName,
    lastName: lastName,
    username: username,
    phone: phone,
    bio: bio ?? this.bio,
    photo: photo,
    presence: presence ?? this.presence,
    isBot: isBot,
  );
}

enum TypingKind { typing, voice, video, upload, sticker, other }

class UsersRepository {
  UsersRepository(this._td) {
    _sub = _td.updates.listen(_onUpdate);
  }

  final TdApi _td;
  final _users = <int, TgUser>{};
  final _members = <String, int>{};
  final _typing = <int, Map<int, TypingKind>>{};
  final _changes = StreamController<void>.broadcast();
  late final StreamSubscription<TdObject> _sub;
  int? _meId;

  Stream<void> get changes => _changes.stream;

  TgUser? user(int id) => _users[id];
  String? nameOf(int userId) => _users[userId]?.name;
  TgUser? get me => _meId == null ? null : _users[_meId];

  int? memberCount({int? basicGroupId, int? supergroupId}) =>
      basicGroupId != null
      ? _members['b$basicGroupId']
      : _members['s$supergroupId'];

  /// Who is doing what in a chat right now, by sender user id.
  Map<int, TypingKind> typingIn(int chatId) => _typing[chatId] ?? const {};

  Future<TgUser?> loadMe() async {
    try {
      final me = TgUser.fromJson(await _td.send({'@type': 'getMe'}));
      _meId = me.id;
      _users[me.id] = me;
      _changes.add(null);
      return me;
    } on TdError {
      return null;
    }
  }

  Future<void> loadFullInfo(int userId) async {
    try {
      final full = await _td.send({
        '@type': 'getUserFullInfo',
        'user_id': userId,
      });
      final bio = (full['bio'] as TdObject?)?['text'] as String? ?? '';
      final u = _users[userId];
      if (u != null) {
        _users[userId] = u.copyWith(bio: bio);
        _changes.add(null);
      }
    } on TdError {
      // no extra info
    }
  }

  void _onUpdate(TdObject u) {
    switch (u['@type']) {
      case 'updateUser':
        final user = TgUser.fromJson(u['user'] as TdObject);
        _users[user.id] = user.copyWith(bio: _users[user.id]?.bio);
      case 'updateUserStatus':
        final id = u['user_id'] as int;
        final old = _users[id];
        if (old == null) return;
        _users[id] = old.copyWith(
          presence: Presence.fromJson(u['status'] as TdObject?),
        );
      case 'updateBasicGroup':
        final g = u['basic_group'] as TdObject;
        _members['b${g['id']}'] = g['member_count'] as int? ?? 0;
      case 'updateSupergroup':
        final g = u['supergroup'] as TdObject;
        _members['s${g['id']}'] = g['member_count'] as int? ?? 0;
      case 'updateChatAction':
        final chatId = u['chat_id'] as int;
        final sender = u['sender_id'] as TdObject?;
        final userId = sender?['user_id'] as int?;
        if (userId == null) return;
        final kind = _typingKind((u['action'] as TdObject?)?['@type']);
        final map = _typing.putIfAbsent(chatId, () => {});
        if (kind == null) {
          map.remove(userId);
        } else {
          map[userId] = kind;
        }
      default:
        return;
    }
    _changes.add(null);
  }

  static TypingKind? _typingKind(Object? type) => switch (type) {
    'chatActionCancel' || null => null,
    'chatActionTyping' => TypingKind.typing,
    'chatActionRecordingVoiceNote' => TypingKind.voice,
    'chatActionRecordingVideoNote' ||
    'chatActionRecordingVideo' => TypingKind.video,
    'chatActionUploadingPhoto' ||
    'chatActionUploadingVideo' ||
    'chatActionUploadingDocument' ||
    'chatActionUploadingVoiceNote' ||
    'chatActionUploadingVideoNote' => TypingKind.upload,
    'chatActionChoosingSticker' => TypingKind.sticker,
    _ => TypingKind.other,
  };

  Future<void> dispose() async {
    await _sub.cancel();
    await _changes.close();
  }
}
