import 'package:flutter/material.dart';

/// PLACEHOLDER wordmark. Replace with the real logo from the Figma file
/// (SnapChef · Mobile UI / UX): export it to `assets/images/logo.png`, list it
/// under `flutter: assets:` in pubspec.yaml, and render it here with
/// `Image.asset`.
class SnapChefLogo extends StatelessWidget {
  const SnapChefLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: colors.onSurface,
    );
    return Semantics(
      label: 'SnapChef',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          text: 'Snap',
          style: style,
          children: [
            TextSpan(
              text: 'Chef',
              style: TextStyle(color: colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
