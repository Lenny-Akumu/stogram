import '../../core/tdlib/td_dispatcher.dart';

enum ButtonKind {
  text,
  url,
  callback,
  callbackPassword,
  game,
  switchInline,
  buy,
  user,
  copy,
  webApp,
  loginUrl,
  phone,
  location,
  poll,
  disabled,
  other,
}

class MarkupButton {
  const MarkupButton(
    this.text,
    this.kind, {
    this.url = '',
    this.data = '',
    this.userId,
    this.query = '',
  });

  factory MarkupButton.fromJson(TdObject json) {
    final type = json['type'] as TdObject? ?? const {};
    final text = json['text'] as String? ?? '';
    return switch (type['@type']) {
      'inlineKeyboardButtonTypeUrl' => MarkupButton(
        text,
        ButtonKind.url,
        url: type['url'] as String? ?? '',
      ),
      'inlineKeyboardButtonTypeLoginUrl' => MarkupButton(
        text,
        ButtonKind.loginUrl,
        url: type['url'] as String? ?? '',
      ),
      'inlineKeyboardButtonTypeWebApp' ||
      'keyboardButtonTypeWebApp' => MarkupButton(
        text,
        ButtonKind.webApp,
        url: type['url'] as String? ?? '',
      ),
      'inlineKeyboardButtonTypeCallback' => MarkupButton(
        text,
        ButtonKind.callback,
        data: type['data'] as String? ?? '',
      ),
      'inlineKeyboardButtonTypeCallbackWithPassword' => MarkupButton(
        text,
        ButtonKind.callbackPassword,
        data: type['data'] as String? ?? '',
      ),
      'inlineKeyboardButtonTypeCallbackGame' => MarkupButton(
        text,
        ButtonKind.game,
      ),
      'inlineKeyboardButtonTypeSwitchInline' => MarkupButton(
        text,
        ButtonKind.switchInline,
        query: type['query'] as String? ?? '',
      ),
      'inlineKeyboardButtonTypeBuy' => MarkupButton(text, ButtonKind.buy),
      'inlineKeyboardButtonTypeUser' => MarkupButton(
        text,
        ButtonKind.user,
        userId: type['user_id'] as int?,
      ),
      'inlineKeyboardButtonTypeCopyText' => MarkupButton(
        text,
        ButtonKind.copy,
        query: type['text'] as String? ?? '',
      ),
      'inlineKeyboardButtonTypeDisabled' => MarkupButton(
        text,
        ButtonKind.disabled,
      ),
      'keyboardButtonTypeText' => MarkupButton(text, ButtonKind.text),
      'keyboardButtonTypeRequestPhoneNumber' => MarkupButton(
        text,
        ButtonKind.phone,
      ),
      'keyboardButtonTypeRequestLocation' => MarkupButton(
        text,
        ButtonKind.location,
      ),
      'keyboardButtonTypeRequestPoll' => MarkupButton(text, ButtonKind.poll),
      _ => MarkupButton(text, ButtonKind.other),
    };
  }

  final String text;
  final ButtonKind kind;
  final String url;

  /// Base64 callback payload as TDLib returns it.
  final String data;
  final int? userId;
  final String query;
}

sealed class ReplyMarkup {
  const ReplyMarkup();

  static ReplyMarkup? fromJson(TdObject? json) {
    List<List<MarkupButton>> rows() => [
      for (final row in (json!['rows'] as List? ?? const []))
        [
          for (final b in (row as List))
            if (b is TdObject) MarkupButton.fromJson(b),
        ],
    ];
    return switch (json?['@type']) {
      'replyMarkupInlineKeyboard' => InlineKeyboard(rows()),
      'replyMarkupShowKeyboard' => ReplyKeyboard(
        rows(),
        oneTime: json!['one_time'] == true,
        resize: json['resize_keyboard'] == true,
        placeholder: json['input_field_placeholder'] as String? ?? '',
      ),
      'replyMarkupRemoveKeyboard' => const RemoveKeyboard(),
      'replyMarkupForceReply' => ForceReply(
        json!['input_field_placeholder'] as String? ?? '',
      ),
      _ => null,
    };
  }
}

class InlineKeyboard extends ReplyMarkup {
  const InlineKeyboard(this.rows);
  final List<List<MarkupButton>> rows;
}

class ReplyKeyboard extends ReplyMarkup {
  const ReplyKeyboard(
    this.rows, {
    this.oneTime = false,
    this.resize = false,
    this.placeholder = '',
  });
  final List<List<MarkupButton>> rows;
  final bool oneTime;
  final bool resize;
  final String placeholder;
}

class RemoveKeyboard extends ReplyMarkup {
  const RemoveKeyboard();
}

class ForceReply extends ReplyMarkup {
  const ForceReply(this.placeholder);
  final String placeholder;
}

class BotCommand {
  const BotCommand(this.command, this.description);
  final String command;
  final String description;
}
