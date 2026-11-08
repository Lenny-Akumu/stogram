import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/providers.dart';
import '../../core/l10n/l10n.dart';
import '../../core/tdlib/td_client.dart';
import '../../core/util/phone.dart';
import '../../data/auth/auth_repository.dart';
import '../../data/auth/auth_state.dart';
import 'auth_errors.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _changingPhone = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final repo = ref.watch(authRepositoryProvider);
    final state = ref.watch(authStateProvider).value ?? const AuthLoading();
    ref.listen(authStateProvider, (prev, next) {
      if (next.value is AuthWaitPhone && _changingPhone) {
        setState(() => _changingPhone = false);
      }
    });

    final phoneForm = _StepForm(
      key: const ValueKey('phone'),
      title: l10n.authPhoneTitle,
      label: l10n.authPhoneLabel,
      hint: l10n.authPhoneHint,
      keyboardType: TextInputType.phone,
      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+ ]'))],
      onSubmit: (v) async {
        await repo.setPhone(v);
        if (mounted) setState(() => _changingPhone = false);
      },
      footer: [
        TextButton(
          onPressed: () => _run(context, repo.requestQr),
          child: Text(l10n.authQrButton),
        ),
      ],
    );

    final Widget body;
    if (!ref.watch(envConfiguredProvider)) {
      body = Text(l10n.envMissing);
    } else if (_changingPhone) {
      body = phoneForm;
    } else {
      body = switch (state) {
        AuthWaitPhone() => phoneForm,
        AuthWaitCode() => _CodeStep(
          key: ObjectKey(state),
          state: state,
          repo: repo,
          onChangePhone: () => setState(() => _changingPhone = true),
        ),
        AuthWaitQr(:final link) => _QrStep(link: link, repo: repo),
        AuthWaitEmail() => _StepForm(
          key: const ValueKey('email'),
          title: l10n.authEmailTitle,
          subtitle: l10n.authEmailSubtitle,
          label: l10n.authEmailLabel,
          keyboardType: TextInputType.emailAddress,
          onSubmit: repo.setEmail,
        ),
        AuthWaitEmailCode(:final pattern, :final length) => _StepForm(
          key: const ValueKey('email-code'),
          title: l10n.authEmailCodeTitle,
          subtitle: l10n.authEmailCodeSentTo(pattern),
          label: l10n.authCodeLabel,
          keyboardType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          autoSubmitLength: length,
          onSubmit: repo.checkEmailCode,
          footer: [
            TextButton(
              onPressed: () => _run(context, repo.resendCode),
              child: Text(l10n.authResendEmail),
            ),
          ],
        ),
        AuthWaitRegistration(:final terms) => _RegisterStep(
          terms: terms,
          repo: repo,
        ),
        AuthWaitPassword(:final hint, :final recoveryEmail) => _StepForm(
          key: const ValueKey('password'),
          title: l10n.authPasswordTitle,
          subtitle: [
            if (hint.isNotEmpty) l10n.authPasswordHint(hint),
            if (recoveryEmail.isNotEmpty)
              l10n.authPasswordRecovery(recoveryEmail),
          ].join('\n'),
          label: l10n.authPasswordLabel,
          obscure: true,
          onSubmit: repo.checkPassword,
          footer: [
            TextButton(
              onPressed: () => setState(() => _changingPhone = true),
              child: Text(l10n.authChangePhone),
            ),
          ],
        ),
        AuthUnsupported(:final type) => Text(l10n.authUnsupported(type)),
        _ => const Center(child: CircularProgressIndicator()),
      };
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _run(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } on TdError catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(authErrorText(context.l10n, e))));
  }
}

class _Title extends StatelessWidget {
  const _Title(this.title, [this.subtitle]);

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _CodeStep extends StatefulWidget {
  const _CodeStep({
    super.key,
    required this.state,
    required this.repo,
    required this.onChangePhone,
  });

  final AuthWaitCode state;
  final AuthRepository repo;
  final VoidCallback onChangePhone;

  @override
  State<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends State<_CodeStep> {
  Timer? _timer;
  late int _left = widget.state.timeout;

  @override
  void initState() {
    super.initState();
    if (_left > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _left--);
        if (_left <= 0) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _subtitle(AppLocalizations l10n) {
    final d = widget.state.delivery;
    final phone = maskPhone(widget.state.phone);
    final main = switch (d.kind) {
      CodeKind.telegram => l10n.codeViaTelegram,
      CodeKind.sms => l10n.codeViaSms(phone),
      CodeKind.call => l10n.codeViaCall(phone),
      CodeKind.flashCall => l10n.codeViaFlashCall(phone),
      CodeKind.missedCall => l10n.codeViaMissedCall(d.hint),
      CodeKind.fragment => l10n.codeViaFragment(d.hint),
      _ => l10n.codeViaUnknown(phone),
    };
    if (d.kind == CodeKind.sms && d.hint.isNotEmpty) {
      return '$main\n${l10n.codeSmsHint(d.hint)}';
    }
    return main;
  }

  String _resendLabel(AppLocalizations l10n, CodeDelivery next) =>
      switch (next.kind) {
        CodeKind.sms => l10n.resendSms,
        CodeKind.call ||
        CodeKind.flashCall ||
        CodeKind.missedCall => l10n.resendCall,
        _ => l10n.resendOther,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final next = widget.state.next;
    return _StepForm(
      title: l10n.authCodeTitle,
      subtitle: _subtitle(l10n),
      label: l10n.authCodeLabel,
      keyboardType: TextInputType.number,
      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\w]'))],
      autoSubmitLength: widget.state.delivery.length,
      onSubmit: widget.repo.checkCode,
      footer: [
        if (next != null)
          TextButton(
            onPressed: _left > 0
                ? null
                : () => _run(context, widget.repo.resendCode),
            child: Text(
              _left > 0 ? l10n.resendIn(_left) : _resendLabel(l10n, next),
            ),
          ),
        TextButton(
          onPressed: widget.onChangePhone,
          child: Text(l10n.authChangePhone),
        ),
      ],
    );
  }
}

class _QrStep extends StatelessWidget {
  const _QrStep({required this.link, required this.repo});

  final String link;
  final AuthRepository repo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(l10n.authQrTitle, l10n.authQrSteps),
        const SizedBox(height: 24),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: QrImageView(
              data: link,
              size: 240,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => _run(context, repo.logOut),
          child: Text(l10n.authUsePhone),
        ),
      ],
    );
  }
}

class _RegisterStep extends StatefulWidget {
  const _RegisterStep({required this.terms, required this.repo});

  final String terms;
  final AuthRepository repo;

  @override
  State<_RegisterStep> createState() => _RegisterStepState();
}

class _RegisterStepState extends State<_RegisterStep> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.register(_first.text.trim(), _last.text.trim());
    } on TdError catch (e) {
      if (mounted) setState(() => _error = authErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(l10n.authRegisterTitle),
        const SizedBox(height: 24),
        TextField(
          controller: _first,
          autofocus: true,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: l10n.authFirstName,
            errorText: _error,
          ),
        ),
        TextField(
          controller: _last,
          enabled: !_busy,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(labelText: l10n.authLastName),
        ),
        if (widget.terms.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(l10n.authTerms),
            children: [Text(widget.terms)],
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.actionNext),
        ),
      ],
    );
  }
}

class _StepForm extends StatefulWidget {
  const _StepForm({
    super.key,
    required this.title,
    required this.label,
    required this.onSubmit,
    this.subtitle,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.formatters,
    this.autoSubmitLength = 0,
    this.footer = const [],
  });

  final String title;
  final String? subtitle;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final int autoSubmitLength;
  final List<Widget> footer;
  final Future<void> Function(String value) onSubmit;

  @override
  State<_StepForm> createState() => _StepFormState();
}

class _StepFormState extends State<_StepForm> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(value);
    } on TdError catch (e) {
      if (mounted) setState(() => _error = authErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onChanged(String value) {
    final n = widget.autoSubmitLength;
    if (n > 0 && value.trim().length == n) _submit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(widget.title, widget.subtitle),
        const SizedBox(height: 32),
        TextField(
          controller: _controller,
          autofocus: true,
          obscureText: widget.obscure,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.formatters,
          enabled: !_busy,
          onChanged: _onChanged,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            errorText: _error,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(context.l10n.actionNext),
        ),
        if (widget.footer.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...widget.footer,
        ],
      ],
    );
  }
}
