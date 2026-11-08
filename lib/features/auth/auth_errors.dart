import '../../core/l10n/l10n.dart';
import '../../core/tdlib/td_error.dart';

String authErrorText(AppLocalizations l10n, TdError e) {
  final m = e.message.toUpperCase();
  final wait = _floodSeconds(e);
  if (wait != null) return l10n.errFlood(_duration(l10n, wait));
  if (m.contains('PHONE_NUMBER')) return l10n.errPhoneInvalid;
  if (m.contains('CODE_EXPIRED')) return l10n.errCodeExpired;
  if (m.contains('CODE_INVALID') || m.contains('CODE_EMPTY')) {
    return l10n.errCodeInvalid;
  }
  if (m.contains('PASSWORD_HASH_INVALID')) return l10n.errPasswordInvalid;
  if (m.contains('EMAIL_INVALID') || m.contains('EMAIL_NOT_ALLOWED')) {
    return l10n.errEmailInvalid;
  }
  if (m.contains('FIRSTNAME_INVALID')) return l10n.errNameInvalid;
  return e.message;
}

int? _floodSeconds(TdError e) {
  if (e.code != 429 && !e.message.toUpperCase().contains('FLOOD_WAIT')) {
    return null;
  }
  final n = RegExp(r'(\d+)').firstMatch(e.message);
  return n == null ? null : int.parse(n.group(1)!);
}

String _duration(AppLocalizations l10n, int seconds) {
  if (seconds >= 3600) return l10n.durationHours((seconds / 3600).ceil());
  if (seconds >= 60) return l10n.durationMinutes((seconds / 60).ceil());
  return l10n.durationSeconds(seconds);
}
