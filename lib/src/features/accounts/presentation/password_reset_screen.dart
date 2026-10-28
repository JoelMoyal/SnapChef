import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../application/auth_validation.dart';
import '../data/auth_repository.dart';
import 'auth_form.dart';

/// Forgot password: email a one-time code, then verify it. Uses a code rather
/// than a link to avoid platform-specific deep-link setup. Originally built by
/// Hetal on the `hetal` branch.
class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  static Route<void> route({String email = ''}) => MaterialPageRoute(
    builder: (_) => PasswordResetScreen(initialEmail: email),
  );

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final auth = ref.read(authRepositoryProvider);
    final recovery = ref.read(passwordRecoveryProvider.notifier);
    setState(() => _submitting = true);
    try {
      if (_codeSent) {
        // Set first: verifying signs the user in, and the auth gate must ask
        // for a new password rather than opening the main app.
        recovery.state = true;
        await auth.verifyPasswordResetCode(
          email: _email.text,
          code: _code.text,
        );
      } else {
        await auth.sendPasswordResetCode(_email.text);
        if (mounted) setState(() => _codeSent = true);
      }
    } on AuthException catch (e) {
      recovery.state = false;
      if (mounted) {
        setState(
          () => _error = e.error == AuthError.invalidCode
              ? 'That code is wrong or has expired. Check it or request a new one.'
              : 'Something went wrong on our side or with your connection. '
                    'Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _restart() => setState(() {
    _codeSent = false;
    _error = null;
    _code.clear();
  });

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: 'Reset your password',
      children: [
        Text(
          _codeSent
              ? 'If an account exists for ${_email.text.trim()}, we sent it a '
                    'reset code. Check your inbox and spam folder.'
              : 'Enter your account email and we’ll send you a reset code.',
        ),
        const SizedBox(height: 16),
        if (_error != null) AuthErrorBanner(message: _error!),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _email,
                enabled: !_codeSent,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                validator: AuthValidation.email,
              ),
              if (_codeSent) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(labelText: 'Code'),
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      AuthValidation.required(v, 'Enter the emailed code'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        SubmitButton(
          label: _codeSent ? 'Verify code' : 'Send reset code',
          loading: _submitting,
          onPressed: _submit,
        ),
        if (_codeSent)
          TextButton(
            onPressed: _submitting ? null : _restart,
            child: const Text('Change email or request a new code'),
          ),
      ],
    );
  }
}

/// Shown by the auth gate after the reset code is verified.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      // Done: the auth gate now opens the main app.
      ref.read(passwordRecoveryProvider.notifier).state = false;
    } on AuthException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.error == AuthError.weakPassword
              ? 'That password is too easy to guess. Try a stronger one.'
              : 'We couldn’t save your new password. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: 'Choose a new password',
      children: [
        if (_error != null) AuthErrorBanner(message: _error!),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New password',
                  helperText:
                      'At least ${AuthValidation.minPasswordLength} characters',
                ),
                autofillHints: const [AutofillHints.newPassword],
                validator: AuthValidation.newPassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                onFieldSubmitted: (_) => _save(),
                validator: (v) =>
                    v != _password.text ? 'Passwords don’t match' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SubmitButton(
          label: 'Save new password',
          loading: _submitting,
          onPressed: _save,
        ),
      ],
    );
  }
}
