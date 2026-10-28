import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend.dart';
import 'snapchef_auth.dart';
import 'recovery.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: 'https://wlopsesyhmfcuwxoesja.supabase.co',
      // Public client key. Database policies enforce per-user access.
      anonKey: 'sb_publishable_ndv-zBK_q2aI9s1XqY5u-w_Khm2m-zo',
    );
    runApp(const MyApp());
  } catch (_) {
    runApp(const MaterialApp(home: Scaffold(body: Center(
      child: Padding(padding: EdgeInsets.all(24), child: Text(
        'SnapChef could not start. Check your connection and restart the app.'))))));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SnapChef',
    theme: ThemeData(useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: snapOrange, primary: snapOrange),
      scaffoldBackgroundColor: Colors.white),
    home: const AuthGate(),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _subscription;
  String? _userId;
  bool _recovery = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userId = backend.auth.currentUser?.id;
    _subscription = backend.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      setState(() {
        _userId = state.session?.user.id;
        if (state.event == AuthChangeEvent.passwordRecovery) _recovery = true;
        if (_userId == null) _recovery = false;
        _error = null;
      });
    }, onError: (Object error) {
      if (mounted) setState(() => _error = backendError(error));
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    if (_error != null) MaterialBanner(content: Text(_error!), actions: [
      TextButton(onPressed: () => setState(() => _error = null), child: const Text('Dismiss')),
    ]),
    Expanded(child: Navigator(
      // A change of account discards all screens belonging to the old session.
      key: ValueKey('${_userId ?? 'signed-out'}:$_recovery'),
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) =>
        _recovery ? NewPasswordPage(onComplete: () {
          if (mounted) setState(() => _recovery = false);
        }) : _userId == null ? const LoginPage() : const PreferencesPage()),
    )),
  ]);
}
