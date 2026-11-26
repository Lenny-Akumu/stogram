import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/l10n.dart';
import '../../core/tdlib/td_error.dart';
import '../../data/messages/message_media.dart';
import '../../ui/theme/chat_colors.dart';

class PollView extends ConsumerStatefulWidget {
  const PollView({
    super.key,
    required this.poll,
    required this.chatId,
    required this.messageId,
    required this.outgoing,
    required this.width,
  });

  final PollMedia poll;
  final int chatId;
  final int messageId;
  final bool outgoing;
  final double width;

  @override
  ConsumerState<PollView> createState() => _PollViewState();
}

class _PollViewState extends ConsumerState<PollView> {
  final _picked = <int>{};

  Future<void> _vote(List<int> ids) async {
    try {
      await ref
          .read(messagesRepositoryProvider(widget.chatId))
          .votePoll(widget.messageId, ids);
      _picked.clear();
    } on TdError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) setState(() {});
  }

  void _tap(int i) {
    final p = widget.poll;
    if (p.showResults) return;
    if (!p.multiple) {
      unawaited(_vote([i]));
      return;
    }
    setState(() {
      if (!_picked.remove(i)) _picked.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ChatColors.of(context);
    final p = widget.poll;
    final fg = widget.outgoing ? colors.textOut : colors.textIn;
    final accent = widget.outgoing ? colors.textOut : colors.accent;
    final meta = widget.outgoing ? colors.metaOut : colors.metaIn;
    final kind = [
      if (p.closed) l10n.pollClosed,
      p.anonymous ? l10n.pollAnonymous : l10n.pollPublic,
      if (p.isQuiz) l10n.pollQuiz,
    ].join(' · ');

    return SizedBox(
      width: widget.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            p.question,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          Text(kind, style: TextStyle(color: meta, fontSize: 12.5)),
          const SizedBox(height: 6),
          for (var i = 0; i < p.options.length; i++)
            _option(i, p, fg, accent, meta),
          const SizedBox(height: 4),
          if (p.multiple && !p.showResults)
            Center(
              child: TextButton(
                onPressed: _picked.isEmpty
                    ? null
                    : () => _vote(_picked.toList()..sort()),
                child: Text(l10n.pollVote, style: TextStyle(color: accent)),
              ),
            )
          else
            Row(
              children: [
                Text(
                  l10n.pollVoters(p.total),
                  style: TextStyle(color: meta, fontSize: 12.5),
                ),
                const Spacer(),
                if (p.voted && !p.closed && !p.isQuiz)
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _vote(const []),
                    child: Text(
                      l10n.pollRetract,
                      style: TextStyle(color: accent, fontSize: 13),
                    ),
                  ),
                if (p.isQuiz && p.voted && p.explanation.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.lightbulb_outline, color: accent),
                    onPressed: () => ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(p.explanation))),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _option(int i, PollMedia p, Color fg, Color accent, Color meta) {
    final o = p.options[i];
    final results = p.showResults;
    final right = p.isQuiz && p.correct.contains(i);
    final barColor = !p.isQuiz
        ? accent
        : right
        ? const Color(0xFF4FAE4E)
        : (o.chosen ? const Color(0xFFE53935) : accent);
    return InkWell(
      onTap: results ? null : () => _tap(i),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: results
                  ? Text(
                      '${o.percent}%',
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    )
                  : Icon(
                      p.multiple
                          ? (_picked.contains(i)
                                ? Icons.check_box
                                : Icons.check_box_outline_blank)
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: meta,
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(o.text, style: TextStyle(color: fg)),
                      ),
                      if (results && (o.chosen || right))
                        Icon(
                          right || !p.isQuiz
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 15,
                          color: barColor,
                        ),
                    ],
                  ),
                  if (results) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: o.percent / 100,
                        minHeight: 3,
                        color: barColor,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Poll composer dialog, returns the poll to send or null.
class NewPoll {
  const NewPoll({
    required this.question,
    required this.options,
    this.anonymous = true,
    this.multiple = false,
    this.quiz = false,
    this.correct = 0,
  });
  final String question;
  final List<String> options;
  final bool anonymous;
  final bool multiple;
  final bool quiz;
  final int correct;
}

Future<NewPoll?> showNewPollDialog(BuildContext context) =>
    showDialog<NewPoll>(context: context, builder: (_) => const _PollDialog());

class _PollDialog extends StatefulWidget {
  const _PollDialog();

  @override
  State<_PollDialog> createState() => _PollDialogState();
}

class _PollDialogState extends State<_PollDialog> {
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  var _anonymous = true;
  var _multiple = false;
  var _quiz = false;
  var _correct = 0;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _question.text.trim().isNotEmpty &&
      _options.where((c) => c.text.trim().isNotEmpty).length >= 2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.pollNew),
      content: SizedBox(
        width: 380,
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
              controller: _question,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.pollQuestion),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _options.length; i++)
              Row(
                children: [
                  if (_quiz)
                    IconButton(
                      icon: Icon(
                        _correct == i
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      onPressed: () => setState(() => _correct = i),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _options[i],
                      decoration: InputDecoration(
                        hintText: l10n.pollOption(i + 1),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_options.length > 2)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _options.removeAt(i).dispose();
                        if (_correct >= _options.length) _correct = 0;
                      }),
                    ),
                ],
              ),
            if (_options.length < 10)
              TextButton.icon(
                onPressed: () =>
                    setState(() => _options.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: Text(l10n.pollAddOption),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.pollAnonymous),
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.pollMultiple),
              value: _multiple,
              onChanged: _quiz ? null : (v) => setState(() => _multiple = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.pollQuiz),
              value: _quiz,
              onChanged: (v) => setState(() {
                _quiz = v;
                if (v) _multiple = false;
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: !_valid
              ? null
              : () {
                  final opts = <String>[];
                  var correct = 0;
                  for (var i = 0; i < _options.length; i++) {
                    final t = _options[i].text.trim();
                    if (t.isEmpty) continue;
                    if (i == _correct) correct = opts.length;
                    opts.add(t);
                  }
                  Navigator.pop(
                    context,
                    NewPoll(
                      question: _question.text.trim(),
                      options: opts,
                      anonymous: _anonymous,
                      multiple: _multiple,
                      quiz: _quiz,
                      correct: correct,
                    ),
                  );
                },
          child: Text(l10n.actionSend),
        ),
      ],
    );
  }
}
