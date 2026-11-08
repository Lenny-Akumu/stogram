import 'package:app/data/files/files_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_td.dart';

Map<String, dynamic> _file(int id, {bool done = false, int got = 0}) => {
  '@type': 'file',
  'id': id,
  'size': 1000,
  'local': {
    'path': done ? '/tmp/f$id' : '',
    'is_downloading_completed': done,
    'downloaded_size': got,
  },
};

void main() {
  test('download asks TDLib and tracks updateFile progress', () async {
    final td = FakeTd()..handler = (_) => _file(3, got: 10);
    final files = FilesRepository(td);
    final seen = <double>[];
    files.watch(3).listen((f) => seen.add(f.progress));

    await files.download(3);
    expect(td.sent.single['@type'], 'downloadFile');
    expect(td.sent.single['file_id'], 3);

    td.push({'@type': 'updateFile', 'file': _file(3, done: true, got: 1000)});
    await pumpEventQueue();
    expect(files.get(3)?.ready, isTrue);
    expect(seen.last, 1);

    await files.download(3);
    expect(td.sent, hasLength(1));
    await files.dispose();
  });

  test('seed keeps already known state', () {
    final files = FilesRepository(FakeTd());
    files.seed(_file(4, done: true));
    files.seed(_file(4));
    expect(files.get(4)?.ready, isTrue);
  });
}
