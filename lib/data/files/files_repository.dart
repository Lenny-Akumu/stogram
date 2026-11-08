import 'dart:async';

import '../../core/tdlib/td_api.dart';
import '../../core/tdlib/td_dispatcher.dart';
import '../../core/tdlib/td_error.dart';

class TdFile {
  const TdFile({
    required this.id,
    this.path = '',
    this.done = false,
    this.size = 0,
    this.downloaded = 0,
  });

  factory TdFile.fromJson(TdObject json) {
    final local = json['local'] as TdObject? ?? const {};
    final size = json['size'] as int? ?? 0;
    return TdFile(
      id: json['id'] as int,
      path: local['path'] as String? ?? '',
      done: local['is_downloading_completed'] == true,
      size: size == 0 ? json['expected_size'] as int? ?? 0 : size,
      downloaded: local['downloaded_size'] as int? ?? 0,
    );
  }

  final int id;
  final String path;
  final bool done;
  final int size;
  final int downloaded;

  bool get ready => done && path.isNotEmpty;
  double get progress => size == 0 ? 0 : downloaded / size;
}

class FilesRepository {
  FilesRepository(this._td) {
    _sub = _td.updates
        .where((u) => u['@type'] == 'updateFile')
        .listen((u) => _put(TdFile.fromJson(u['file'] as TdObject)));
  }

  final TdApi _td;
  final _files = <int, TdFile>{};
  final _out = StreamController<TdFile>.broadcast();
  late final StreamSubscription<TdObject> _sub;

  TdFile? get(int id) => _files[id];

  Stream<TdFile> watch(int id) => _out.stream.where((f) => f.id == id);

  /// Remembers file info that came inside a message or chat.
  void seed(TdObject? json) {
    if (json == null || json['id'] is! int) return;
    final f = TdFile.fromJson(json);
    _files.putIfAbsent(f.id, () => f);
  }

  Future<void> download(int id, {int priority = 16}) async {
    if (_files[id]?.ready ?? false) return;
    try {
      _put(
        TdFile.fromJson(
          await _td.send({
            '@type': 'downloadFile',
            'file_id': id,
            'priority': priority,
            'offset': 0,
            'limit': 0,
            'synchronous': false,
          }),
        ),
      );
    } on TdError {
      // stays a placeholder
    }
  }

  void _put(TdFile f) {
    _files[f.id] = f;
    if (!_out.isClosed) _out.add(f);
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await _out.close();
  }
}
