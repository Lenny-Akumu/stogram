import '../../core/tdlib/td_client.dart';

sealed class AuthState {
  const AuthState();

  factory AuthState.fromJson(TdObject json) {
    return switch (json['@type']) {
      'authorizationStateWaitTdlibParameters' => const AuthWaitParams(),
      'authorizationStateWaitPhoneNumber' => const AuthWaitPhone(),
      'authorizationStateWaitCode' => AuthWaitCode(
        phone:
            (json['code_info'] as TdObject?)?['phone_number'] as String? ?? '',
      ),
      'authorizationStateWaitPassword' => AuthWaitPassword(
        hint: json['password_hint'] as String? ?? '',
      ),
      'authorizationStateReady' => const AuthReady(),
      'authorizationStateLoggingOut' ||
      'authorizationStateClosing' => const AuthLoggingOut(),
      'authorizationStateClosed' => const AuthClosed(),
      final type => AuthUnsupported(type as String? ?? ''),
    };
  }
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
  const AuthWaitCode({required this.phone});
  final String phone;
}

class AuthWaitPassword extends AuthState {
  const AuthWaitPassword({required this.hint});
  final String hint;
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
