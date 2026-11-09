import 'dart:convert';

import 'package:app/data/messages/message_media.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _file(int id, {int size = 100}) => {
  'id': id,
  'size': size,
  'local': {'path': '', 'is_downloading_completed': false},
};

void main() {
  test('photo picks the largest size within 1280', () {
    final m = MessageMedia.fromContent({
      '@type': 'messagePhoto',
      'photo': {
        'minithumbnail': {'width': 4, 'height': 3, 'data': 'AAEC'},
        'sizes': [
          {'type': 's', 'photo': _file(1), 'width': 90, 'height': 67},
          {'type': 'x', 'photo': _file(2), 'width': 800, 'height': 600},
          {'type': 'y', 'photo': _file(3), 'width': 2560, 'height': 1920},
        ],
      },
    });
    final image = (m! as PhotoMedia).image;
    expect(image.fileId, 2);
    expect(image.aspect, closeTo(800 / 600, 0.001));
    expect(image.mini, isNotNull);
  });

  test('animated sticker falls back to its thumbnail', () {
    final m =
        MessageMedia.fromContent({
              '@type': 'messageSticker',
              'sticker': {
                'emoji': '🔥',
                'width': 512,
                'height': 512,
                'format': {'@type': 'stickerFormatTgs'},
                'thumbnail': {'file': _file(8)},
                'sticker': _file(9),
              },
            })!
            as StickerMedia;
    expect(m.isStatic, isFalse);
    expect(m.image.fileId, 8);
    expect(m.emoji, '🔥');
  });

  test('document and audio keep names and sizes', () {
    final doc =
        MessageMedia.fromContent({
              '@type': 'messageDocument',
              'document': {
                'file_name': 'cv.pdf',
                'document': _file(5, size: 2048),
              },
            })!
            as DocumentMedia;
    expect(doc.name, 'cv.pdf');
    expect(doc.size, 2048);

    final audio =
        MessageMedia.fromContent({
              '@type': 'messageAudio',
              'audio': {
                'performer': 'Okean Elzy',
                'title': 'Obijmy',
                'audio': _file(6),
              },
            })!
            as AudioMedia;
    expect(audio.title, 'Okean Elzy — Obijmy');
  });

  test('round video note is square', () {
    final v =
        MessageMedia.fromContent({
              '@type': 'messageVideoNote',
              'video_note': {'duration': 7, 'length': 240},
            })!
            as VideoMedia;
    expect(v.isRound, isTrue);
    expect(v.cover.aspect, 1);
    expect(v.duration, 7);
  });

  test('text has no media', () {
    expect(MessageMedia.fromContent({'@type': 'messageText'}), isNull);
  });

  test('waveform unpacks 5-bit samples', () {
    // bits: 11111 00000 10101 -> 31, 0, 21 (little endian bit order)
    final bytes = [0x1F, 0x54, 0x00];
    final w = decodeWaveform(base64Encode(bytes));
    expect(w.take(3), [31, 0, 21]);
  });

  test('voice keeps file and waveform', () {
    final v =
        MessageMedia.fromContent({
              '@type': 'messageVoiceNote',
              'voice_note': {
                'duration': 12,
                'waveform': base64Encode([0x1F]),
                'voice': _file(40),
              },
            })!
            as VoiceMedia;
    expect(v.fileId, 40);
    expect(v.waveform, isNotEmpty);
  });

  test('video keeps playable file', () {
    final v =
        MessageMedia.fromContent({
              '@type': 'messageVideo',
              'video': {
                'duration': 3,
                'width': 10,
                'height': 10,
                'video': _file(41),
              },
            })!
            as VideoMedia;
    expect(v.fileId, 41);
  });
}
