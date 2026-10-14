import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';

void main() {
  // ProviderScope makes Riverpod available to the whole app.
  runApp(const ProviderScope(child: SnapChefApp()));
}
