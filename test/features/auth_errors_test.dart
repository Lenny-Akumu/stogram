import 'package:app/core/l10n/gen/app_localizations_uk.dart';
import 'package:app/core/tdlib/td_error.dart';
import 'package:app/features/auth/auth_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsUk();

  test('maps known TDLib errors', () {
    expect(
      authErrorText(l10n, const TdError(400, 'PHONE_CODE_INVALID')),
      l10n.errCodeInvalid,
    );
    expect(
      authErrorText(l10n, const TdError(400, 'PHONE_NUMBER_INVALID')),
      l10n.errPhoneInvalid,
    );
    expect(
      authErrorText(l10n, const TdError(400, 'PASSWORD_HASH_INVALID')),
      l10n.errPasswordInvalid,
    );
  });

  test('flood wait shows rounded duration', () {
    expect(
      authErrorText(
        l10n,
        const TdError(429, 'Too Many Requests: retry after 125'),
      ),
      l10n.errFlood(l10n.durationMinutes(3)),
    );
  });

  test('unknown error passes through', () {
    expect(authErrorText(l10n, const TdError(400, 'WAT')), 'WAT');
  });
}
