import '../../core/tdlib/td_client.dart';

enum CodeKind {
  telegram,
  sms,
  call,
  flashCall,
  missedCall,
  fragment,
  email,
  unknown,
}

class CodeDelivery {
  const CodeDelivery(this.kind, {this.length = 0, this.hint = ''});

  static CodeDelivery? fromJson(TdObject? json) {
    if (json == null) return null;
    final length = json['length'] as int? ?? 0;
    return switch (json['@type']) {
      'authenticationCodeTypeTelegramMessage' => CodeDelivery(
        CodeKind.telegram,
        length: length,
      ),
      'authenticationCodeTypeSms' ||
      'authenticationCodeTypeFirebaseAndroid' ||
      'authenticationCodeTypeFirebaseIos' => CodeDelivery(
        CodeKind.sms,
        length: length,
      ),
      'authenticationCodeTypeSmsWord' => CodeDelivery(
        CodeKind.sms,
        hint: json['first_letter'] as String? ?? '',
      ),
      'authenticationCodeTypeSmsPhrase' => CodeDelivery(
        CodeKind.sms,
        hint: json['first_word'] as String? ?? '',
      ),
      'authenticationCodeTypeCall' => CodeDelivery(
        CodeKind.call,
        length: length,
      ),
      'authenticationCodeTypeFlashCall' => CodeDelivery(
        CodeKind.flashCall,
        hint: json['pattern'] as String? ?? '',
      ),
      'authenticationCodeTypeMissedCall' => CodeDelivery(
        CodeKind.missedCall,
        length: length,
        hint: json['phone_number_prefix'] as String? ?? '',
      ),
      'authenticationCodeTypeFragment' => CodeDelivery(
        CodeKind.fragment,
        length: length,
        hint: json['url'] as String? ?? '',
      ),
      _ => const CodeDelivery(CodeKind.unknown),
    };
  }

  final CodeKind kind;
  final int length;
  final String hint;
}

sealed class AuthState {
  const AuthState();

  factory AuthState.fromJson(TdObject json) {
    return switch (json['@type']) {
      'authorizationStateWaitTdlibParameters' => const AuthWaitParams(),
      'authorizationStateWaitPhoneNumber' => const AuthWaitPhone(),
      'authorizationStateWaitCode' => _code(json['code_info'] as TdObject?),
      'authorizationStateWaitEmailAddress' => const AuthWaitEmail(),
      'authorizationStateWaitEmailCode' => AuthWaitEmailCode(
        pattern:
            (json['code_info'] as TdObject?)?['email_address_pattern']
                as String? ??
            '',
        length: (json['code_info'] as TdObject?)?['length'] as int? ?? 0,
      ),
      'authorizationStateWaitOtherDeviceConfirmation' => AuthWaitQr(
        json['link'] as String? ?? '',
      ),
      'authorizationStateWaitRegistration' => AuthWaitRegistration(
        terms:
            ((json['terms_of_service'] as TdObject?)?['text']
                    as TdObject?)?['text']
                as String? ??
            '',
      ),
      'authorizationStateWaitPassword' => AuthWaitPassword(
        hint: json['password_hint'] as String? ?? '',
        recoveryEmail: json['recovery_email_address_pattern'] as String? ?? '',
      ),
      'authorizationStateReady' => const AuthReady(),
      'authorizationStateLoggingOut' ||
      'authorizationStateClosing' => const AuthLoggingOut(),
      'authorizationStateClosed' => const AuthClosed(),
      final type => AuthUnsupported(type as String? ?? ''),
    };
  }

  static AuthWaitCode _code(TdObject? info) => AuthWaitCode(
    phone: info?['phone_number'] as String? ?? '',
    delivery:
        CodeDelivery.fromJson(info?['type'] as TdObject?) ??
        const CodeDelivery(CodeKind.unknown),
    next: CodeDelivery.fromJson(info?['next_type'] as TdObject?),
    timeout: info?['timeout'] as int? ?? 0,
  );
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthWaitParams extends AuthState {
  const AuthWaitParams();
}

class AuthWaitPhone extends AuthState {
  const AuthWaitPhone();
}

class AuthWaitCode extends AuthState {
  const AuthWaitCode({
    required this.phone,
    this.delivery = const CodeDelivery(CodeKind.unknown),
    this.next,
    this.timeout = 0,
  });

  final String phone;
  final CodeDelivery delivery;
  final CodeDelivery? next;
  final int timeout;
}

class AuthWaitEmail extends AuthState {
  const AuthWaitEmail();
}

class AuthWaitEmailCode extends AuthState {
  const AuthWaitEmailCode({required this.pattern, this.length = 0});
  final String pattern;
  final int length;
}

class AuthWaitQr extends AuthState {
  const AuthWaitQr(this.link);
  final String link;
}

class AuthWaitRegistration extends AuthState {
  const AuthWaitRegistration({this.terms = ''});
  final String terms;
}

class AuthWaitPassword extends AuthState {
  const AuthWaitPassword({required this.hint, this.recoveryEmail = ''});
  final String hint;
  final String recoveryEmail;
}

class AuthReady extends AuthState {
  const AuthReady();
}

class AuthLoggingOut extends AuthState {
  const AuthLoggingOut();
}

class AuthClosed extends AuthState {
  const AuthClosed();
}

class AuthUnsupported extends AuthState {
  const AuthUnsupported(this.type);
  final String type;
}
