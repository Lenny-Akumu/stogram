import 'package:app/data/messages/chat_message.dart';
import 'package:app/data/messages/rich_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('entities become spans with link targets', () {
    const text = 'Дивись example.com і @durov, тут [це]';
    final spans = parseEntities({
      'text': text,
      'entities': [
        {
          'offset': 7,
          'length': 11,
          'type': {'@type': 'textEntityTypeUrl'},
        },
        {
          'offset': 21,
          'length': 6,
          'type': {'@type': 'textEntityTypeMention'},
        },
        {
          'offset': 33,
          'length': 4,
          'type': {'@type': 'textEntityTypeTextUrl', 'url': 'https://a.b/c'},
        },
        {
          'offset': 0,
          'length': 6,
          'type': {'@type': 'textEntityTypeBold'},
        },
        {
          'offset': 0,
          'length': 1,
          'type': {'@type': 'textEntityTypeSpoiler'},
        },
      ],
    });
    expect(spans, hasLength(4));
    expect(spanTarget(text, spans[0]), 'https://example.com');
    expect(spanTarget(text, spans[1]), 'https://t.me/durov');
    expect(spanTarget(text, spans[2]), 'https://a.b/c');
    expect(spans[3].kind, SpanKind.bold);
  });

  test('message keeps link preview and drops empty ones', () {
    final m = ChatMessage.fromJson({
      'id': 1,
      'chat_id': 2,
      'date': 0,
      'edit_date': 0,
      'content': {
        '@type': 'messageText',
        'text': {'text': 'https://x.ua'},
        'link_preview': {
          'url': 'https://x.ua',
          'site_name': 'X',
          'title': 'Новина',
          'description': {'text': 'Опис'},
          'type': {'@type': 'linkPreviewTypeArticle'},
        },
      },
    });
    expect(m.linkPreview?.title, 'Новина');
    expect(m.linkPreview?.description, 'Опис');

    final empty = ChatMessage.linkPreviewOf({
      '@type': 'messageText',
      'link_preview': {'url': 'https://y.ua'},
    });
    expect(empty, isNull);
  });
}
