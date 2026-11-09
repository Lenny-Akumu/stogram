abstract final class Env {
  static const apiId = int.fromEnvironment('TG_API_ID');
  static const apiHash = String.fromEnvironment('TG_API_HASH');
  static const tdjsonPath = String.fromEnvironment('TDJSON_PATH');

  /// Release tag this build was published under, empty for local builds.
  static const buildTag = String.fromEnvironment('BUILD_TAG');
  static const updateRepo = String.fromEnvironment(
    'UPDATE_REPO',
    defaultValue: 'Lenny-Akumu/stogram',
  );

  static bool get isConfigured => apiId != 0 && apiHash.isNotEmpty;
}
