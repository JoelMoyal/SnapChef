import 'package:flutter/material.dart';

import '../../../core/widgets/snapchef_logo.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SnapChefLogo(size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Snap your ingredients. Get recipes you can cook tonight.',
                      style: text.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              FilledButton(
                style: _bigButton,
                onPressed: () =>
                    Navigator.of(context).push(SignupScreen.route()),
                child: const Text('Create account'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: _bigButton,
                onPressed: () =>
                    Navigator.of(context).push(LoginScreen.route()),
                child: const Text('Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _bigButton = ButtonStyle(
  minimumSize: WidgetStateProperty.all(const Size.fromHeight(52)),
);
