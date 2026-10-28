import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../application/auth_validation.dart';
import '../data/auth_repository.dart';
import 'auth_form.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  static Route<void> route({String email = ''}) =>
      MaterialPageRoute(builder: (_) => LoginScreen(initialEmail: email));

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // Tap Log In → "Email and password entered?" → submit → "Result?"
  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .logIn(email: _email.text, password: _password.text);
      // On success the auth gate swaps to the main app.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e.error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static String _messageFor(AuthError error) => switch (error) {
    AuthError.invalidCredentials =>
      'That email and password don’t match. Check them and try again.',
    AuthError.emailNotConfirmed =>
      'Confirm your email first. We sent you a link when you signed up.',
    AuthError.network =>
      'Something went wrong on our side or with your connection. '
          'Please try again.',
    AuthError.emailInUse => 'Something went wrong. Please try again.',
  };

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: 'Welcome back',
      children: [
        if (_error != null) AuthErrorBanner(message: _error!),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      AuthValidation.required(v, 'Enter your email'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password' : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SubmitButton(label: 'Log in', loading: _submitting, onPressed: _submit),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pushReplacement(SignupScreen.route()),
          child: const Text('Need an account? Sign up'),
        ),
      ],
    );
  }
}
