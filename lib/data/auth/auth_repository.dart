import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';

import '../../core/config.dart';
import '../../core/tdlib/td_client.dart';
import 'auth_state.dart';

class AuthRepository {
  AuthRepository(this._td) {
    _sub = _td.updates
        .where((u) => u['@type'] == 'updateAuthorizationState')
        .listen(
          (u) => _set(AuthState.fromJson(u['authorization_state'] as TdObject)),
        );
    unawaited(_requestState());
  }

  final TdApi _td;
  final _states = StreamController<AuthState>.broadcast();
  late final StreamSubscription<TdObject> _sub;
  AuthState _current = const AuthLoading();
  bool _paramsSent = false;

  AuthState get current => _current;
  Stream<AuthState> get states => _states.stream;

  void _set(AuthState state) {
    _current = state;
    _states.add(state);
    if (state is AuthWaitParams && !_paramsSent) {
      _paramsSent = true;
      unawaited(_sendParams());
    } else if (state is AuthClosed) {
      _paramsSent = false;
      _td.reopen();
      unawaited(_requestState());
    }
  }

  Future<void> _requestState() async {
    try {
      _set(
        AuthState.fromJson(await _td.send({'@type': 'getAuthorizationState'})),
      );
    } on TdError {
      // the update stream will deliver the state anyway
    }
  }

  Future<void> _sendParams() async {
    final dir = (await getApplicationSupportDirectory()).path;
    await _td.send({
      '@type': 'setTdlibParameters',
      'use_test_dc': false,
      'database_directory': '$dir/td',
      'files_directory': '$dir/td_files',
      'database_encryption_key': '',
      'use_file_database': true,
      'use_chat_info_database': true,
      'use_message_database': true,
      'use_secret_chats': false,
      'api_id': Env.apiId,
      'api_hash': Env.apiHash,
      'system_language_code': PlatformDispatcher.instance.locale.languageCode,
      'device_model': _deviceModel(),
      'system_version': Platform.operatingSystemVersion,
      'application_version': '0.1.0',
    });
  }

  static String _deviceModel() => switch (Platform.operatingSystem) {
    'linux' => 'Linux',
    'windows' => 'Windows',
    'android' => 'Android',
    'macos' => 'macOS',
    'ios' => 'iOS',
    final os => os,
  };

  Future<void> setPhone(String phone) => _td.send({
    '@type': 'setAuthenticationPhoneNumber',
    'phone_number': phone,
  });

  Future<void> checkCode(String code) =>
      _td.send({'@type': 'checkAuthenticationCode', 'code': code});

  Future<void> checkPassword(String password) =>
      _td.send({'@type': 'checkAuthenticationPassword', 'password': password});

  Future<void> resendCode() =>
      _td.send({'@type': 'resendAuthenticationCode', 'reason': null});

  Future<void> setEmail(String email) => _td.send({
    '@type': 'setAuthenticationEmailAddress',
    'email_address': email,
  });

  Future<void> checkEmailCode(String code) => _td.send({
    '@type': 'checkAuthenticationEmailCode',
    'code': {'@type': 'emailAddressAuthenticationCode', 'code': code},
  });

  Future<void> requestQr() => _td.send({
    '@type': 'requestQrCodeAuthentication',
    'other_user_ids': <int>[],
  });

  Future<void> register(String firstName, String lastName) => _td.send({
    '@type': 'registerUser',
    'first_name': firstName,
    'last_name': lastName,
    'disable_notification': false,
  });

  Future<void> logOut() => _td.send({'@type': 'logOut'});

  Future<void> dispose() async {
    await _sub.cancel();
    await _states.close();
  }
}
