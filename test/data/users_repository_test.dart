import 'package:app/core/l10n/gen/app_localizations_uk.dart';
import 'package:app/data/chats/chat_summary.dart';
import 'package:app/data/users/users_repository.dart';
import 'package:app/ui/components/presence_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_td.dart';

void main() {
  final l10n = AppLocalizationsUk();
  late FakeTd td;
  late UsersRepository users;

  setUpAll(() => initializeDateFormatting('uk'));
  setUp(() {
    td = FakeTd();
    users = UsersRepository(td);
    td.push({
      '@type': 'updateUser',
      'user': {
        'id': 1,
        'first_name': 'Софія',
        'status': {'@type': 'userStatusOffline', 'was_online': 0},
      },
    });
  });
  tearDown(() => users.dispose());

  const chat = ChatSummary(
    id: 10,
    title: 'Софія',
    order: 1,
    isPinned: false,
    unreadCount: 0,
    preview: null,
    date: null,
    peer: ChatPeer(userId: 1),
  );

  test('status follows updateUserStatus', () {
    final now = DateTime(2026, 11, 9, 12);
    td.push({
      '@type': 'updateUserStatus',
      'user_id': 1,
      'status': {'@type': 'userStatusOnline', 'expires': 0},
    });
    expect(chatSubtitle(l10n, chat, users, now, 'uk'), l10n.statusOnline);

    td.push({
      '@type': 'updateUserStatus',
      'user_id': 1,
      'status': {'@type': 'userStatusRecently'},
    });
    expect(chatSubtitle(l10n, chat, users, now, 'uk'), l10n.statusRecently);
  });

  test('typing wins over status and clears on cancel', () {
    final now = DateTime(2026, 11, 9);
    td.push({
      '@type': 'updateChatAction',
      'chat_id': 10,
      'sender_id': {'@type': 'messageSenderUser', 'user_id': 1},
      'action': {'@type': 'chatActionRecordingVoiceNote'},
    });
    expect(chatSubtitle(l10n, chat, users, now, 'uk'), l10n.typingVoice);

    td.push({
      '@type': 'updateChatAction',
      'chat_id': 10,
      'sender_id': {'@type': 'messageSenderUser', 'user_id': 1},
      'action': {'@type': 'chatActionCancel'},
    });
    expect(users.typingIn(10), isEmpty);
  });

  test('group subtitle shows member count', () {
    td.push({
      '@type': 'updateSupergroup',
      'supergroup': {'id': 5, 'member_count': 21},
    });
    const group = ChatSummary(
      id: 11,
      title: 'Група',
      order: 1,
      isPinned: false,
      unreadCount: 0,
      preview: null,
      date: null,
      isGroup: true,
      peer: ChatPeer(supergroupId: 5),
    );
    expect(
      chatSubtitle(l10n, group, users, DateTime(2026), 'uk'),
      l10n.membersCount(21),
    );
  });

  test('day labels', () {
    final now = DateTime(2026, 11, 9, 10);
    expect(dayLabel(l10n, DateTime(2026, 11, 9, 1), now, 'uk'), l10n.today);
    expect(
      dayLabel(l10n, DateTime(2026, 11, 8, 23), now, 'uk'),
      l10n.yesterday,
    );
  });
}
