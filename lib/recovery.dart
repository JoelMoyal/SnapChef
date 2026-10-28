import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend.dart';

/// Uses an emailed code, avoiding platform-specific deep-link setup.
class RecoveryCodePage extends StatefulWidget {
  const RecoveryCodePage({super.key});
  @override
  State<RecoveryCodePage> createState() => _RecoveryCodePageState();
}
class _RecoveryCodePageState extends State<RecoveryCodePage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  @override
  void dispose() { _email.dispose(); _code.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_busy) return;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim()) ||
        (_sent && _code.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a valid email and, if requested, the emailed code.')));
      return;
    }
    setState(() => _busy = true);
    try {
      if (_sent) {
        await backend.auth.verifyOTP(email: _email.text.trim(),
          token: _code.text.trim(), type: OtpType.recovery);
        // AuthGate handles passwordRecovery and displays NewPasswordPage.
      } else {
        await backend.auth.resetPasswordForEmail(_email.text.trim());
        if (mounted) setState(() => _sent = true);
      }
    } catch (error) {
      if (mounted) showBackendError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(26), children: [
        Text(_sent ? 'If an account exists, a reset code has been sent. Check your inbox and spam folder.'
          : 'Enter your account email to receive a password reset code.'),
        const SizedBox(height: 20),
        TextField(controller: _email, enabled: !_sent && !_busy,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address')),
        if (_sent) TextField(controller: _code, enabled: !_busy,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Email code')),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Please wait…' : _sent ? 'Verify code' : 'Send reset code')),
        if (_sent) TextButton(onPressed: _busy ? null : () => setState(() {
          _sent = false; _code.clear();
        }), child: const Text('Change email or request a new code')),
      ]))),
  );
}

class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({super.key, required this.onComplete});
  final VoidCallback onComplete;
  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}
class _NewPasswordPageState extends State<NewPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  @override
  void dispose() { _password.dispose(); _confirm.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await backend.auth.updateUser(UserAttributes(password: _password.text));
      if (mounted) widget.onComplete();
    } catch (error) {
      if (mounted) showBackendError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose a new password')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500),
      child: Form(key: _form, child: ListView(shrinkWrap: true,
        padding: const EdgeInsets.all(26), children: [
          TextFormField(controller: _password, obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
            validator: (v) => (v?.length ?? 0) < 8 ? 'Use at least 8 characters.' : null),
          TextFormField(controller: _confirm, obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm new password'),
            validator: (v) => v != _password.text ? 'Passwords do not match.' : null),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save new password')),
        ])))),
  );
}
