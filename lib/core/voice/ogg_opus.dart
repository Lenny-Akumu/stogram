import 'dart:convert';
import 'dart:typed_data';

/// Wraps Opus packets (20 ms, mono, 48 kHz) into an Ogg Opus file.
Uint8List oggOpus(List<Uint8List> packets, {int preSkip = 312}) {
  final out = BytesBuilder(copy: false);
  final serial = 0x5354474d;
  var seq = 0;

  void page(List<Uint8List> segs, int granule, int flags) {
    final lacing = <int>[];
    for (final p in segs) {
      var n = p.length;
      while (n >= 255) {
        lacing.add(255);
        n -= 255;
      }
      lacing.add(n);
    }
    final header = ByteData(27 + lacing.length)
      ..setUint32(0, 0x4f676753)
      ..setUint8(4, 0)
      ..setUint8(5, flags)
      ..setInt64(6, granule, Endian.little)
      ..setUint32(14, serial, Endian.little)
      ..setUint32(18, seq++, Endian.little)
      ..setUint32(22, 0, Endian.little)
      ..setUint8(26, lacing.length);
    for (var i = 0; i < lacing.length; i++) {
      header.setUint8(27 + i, lacing[i]);
    }
    final bytes = BytesBuilder(copy: false)..add(header.buffer.asUint8List());
    for (final p in segs) {
      bytes.add(p);
    }
    final data = bytes.toBytes();
    ByteData.sublistView(data).setUint32(22, _crc(data), Endian.little);
    out.add(data);
  }

  final head = ByteData(19)
    ..setUint8(8, 1)
    ..setUint8(9, 1)
    ..setUint16(10, preSkip, Endian.little)
    ..setUint32(12, 48000, Endian.little)
    ..setInt16(16, 0, Endian.little)
    ..setUint8(18, 0);
  final headBytes = head.buffer.asUint8List()
    ..setRange(0, 8, ascii.encode('OpusHead'));
  page([headBytes], 0, 2);

  final vendor = utf8.encode('stogram');
  final tags = ByteData(8 + 4 + vendor.length + 4);
  final tagBytes = tags.buffer.asUint8List()
    ..setRange(0, 8, ascii.encode('OpusTags'));
  tags.setUint32(8, vendor.length, Endian.little);
  tagBytes.setRange(12, 12 + vendor.length, vendor);
  tags.setUint32(12 + vendor.length, 0, Endian.little);
  page([tagBytes], 0, 0);

  var granule = preSkip;
  var batch = <Uint8List>[];
  var lacing = 0;
  for (var i = 0; i < packets.length; i++) {
    final p = packets[i];
    final need = p.length ~/ 255 + 1;
    if (lacing + need > 255) {
      page(batch, granule, 0);
      batch = [];
      lacing = 0;
    }
    batch.add(p);
    lacing += need;
    granule += 960;
  }
  page(batch, granule, 4);
  return out.toBytes();
}

final _table = List<int>.generate(256, (i) {
  var r = i << 24;
  for (var j = 0; j < 8; j++) {
    r = (r & 0x80000000) != 0 ? ((r << 1) ^ 0x04c11db7) : (r << 1);
  }
  return r & 0xffffffff;
});

int _crc(Uint8List data) {
  var crc = 0;
  for (final b in data) {
    crc = ((crc << 8) ^ _table[((crc >> 24) & 0xff) ^ b]) & 0xffffffff;
  }
  return crc;
}
