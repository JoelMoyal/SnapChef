import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../application/auth_validation.dart';
import '../data/auth_repository.dart';
import 'auth_form.dart';
import 'login_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const SignupScreen());

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  bool _submitting = false;
  AuthError? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  // Tap Create Account → "Required fields filled and details valid?" →
  // submit → "Result?"
  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            firstName: _firstName.text,
            lastName: _lastName.text,
            email: _email.text,
            password: _password.text,
          );
      // Account created → the auth gate swaps to the main app.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _correctEmail() {
    setState(() => _error = null);
    _emailFocus.requestFocus();
  }

  Widget? _banner() => switch (_error) {
    null => null,
    AuthError.emailInUse => AuthErrorBanner(
      message: 'An account with this email already exists.',
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(
            context,
          ).pushReplacement(LoginScreen.route(email: _email.text.trim())),
          child: const Text('Log in instead'),
        ),
        TextButton(
          onPressed: _correctEmail,
          child: const Text('Use a different email'),
        ),
      ],
    ),
    AuthError.network || AuthError.invalidCredentials => const AuthErrorBanner(
      message:
          'We couldn’t create your account right now. '
          'Check your connection and try again.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final banner = _banner();
    return AuthFormScaffold(
      title: 'Create your account',
      children: [
        ?banner,
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstName,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                        ),
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.givenName],
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            AuthValidation.required(v, 'Enter your first name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastName,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                        ),
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.familyName],
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            AuthValidation.required(v, 'Enter your last name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  focusNode: _emailFocus,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: AuthValidation.email,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText:
                        'At least ${AuthValidation.minPasswordLength} characters',
                  ),
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: AuthValidation.newPassword,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SubmitButton(
          label: 'Create account',
          loading: _submitting,
          onPressed: _submit,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pushReplacement(LoginScreen.route()),
          child: const Text('Already have an account? Log in'),
        ),
      ],
    );
  }
}
