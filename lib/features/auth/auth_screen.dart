import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/tdlib/td_client.dart';
import '../../core/util/phone.dart';
import '../../data/auth/auth_state.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final repo = ref.watch(authRepositoryProvider);
    final state = ref.watch(authStateProvider).value ?? const AuthLoading();

    final Widget body;
    if (!Env.isConfigured) {
      body = Text(l10n.envMissing);
    } else {
      body = switch (state) {
        AuthWaitPhone() => _StepForm(
          key: const ValueKey('phone'),
          title: l10n.authPhoneTitle,
          label: l10n.authPhoneLabel,
          hint: l10n.authPhoneHint,
          keyboardType: TextInputType.phone,
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+ ]'))],
          onSubmit: repo.setPhone,
        ),
        AuthWaitCode(:final phone) => _StepForm(
          key: const ValueKey('code'),
          title: l10n.authCodeTitle,
          subtitle: l10n.authCodeSentTo(maskPhone(phone)),
          label: l10n.authCodeLabel,
          keyboardType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmit: repo.checkCode,
        ),
        AuthWaitPassword(:final hint) => _StepForm(
          key: const ValueKey('password'),
          title: l10n.authPasswordTitle,
          subtitle: hint.isEmpty ? null : l10n.authPasswordHint(hint),
          label: l10n.authPasswordLabel,
          obscure: true,
          onSubmit: repo.checkPassword,
        ),
        AuthUnsupported(:final type) => Text(l10n.authUnsupported(type)),
        _ => const CircularProgressIndicator(),
      };
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(padding: const EdgeInsets.all(32), child: body),
        ),
      ),
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
  });

  final String title;
  final String? subtitle;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
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
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(widget.subtitle!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 32),
        TextField(
          controller: _controller,
          autofocus: true,
          obscureText: widget.obscure,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.formatters,
          enabled: !_busy,
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
      ],
    );
  }
}
