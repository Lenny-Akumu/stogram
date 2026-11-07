class TdError implements Exception {
  const TdError(this.code, this.message);

  factory TdError.fromJson(Map<String, dynamic> json) =>
      TdError(json['code'] as int? ?? 0, json['message'] as String? ?? '');

  final int code;
  final String message;

  @override
  String toString() => 'TdError($code, $message)';
}
