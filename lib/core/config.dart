abstract final class Env {
  static const apiId = int.fromEnvironment('TG_API_ID');
  static const apiHash = String.fromEnvironment('TG_API_HASH');
  static const tdjsonPath = String.fromEnvironment('TDJSON_PATH');

  static bool get isConfigured => apiId != 0 && apiHash.isNotEmpty;
}
