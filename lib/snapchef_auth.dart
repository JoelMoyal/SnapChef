import 'package:flutter/material.dart';
import 'backend.dart';
import 'recovery.dart';

const snapOrange = Color(0xFFB8430D);

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final Set<String> _preferences = {};
  bool _busy = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final response = await backend.auth.signUp(
        email: _email.text.trim(), password: _password.text,
        data: {'full_name': _name.text.trim(),
          'dietary_preferences': _preferences.toList()},
      );
      if (!mounted) return;
      if (response.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          duration: Duration(seconds: 8),
          content: Text('Check your email to confirm your account, then return here and log in. If already registered, use Log in.'),
        ));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (mounted) showBackendError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon,
      {Widget? suffix, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: snapOrange, size: 21),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFFFFAF7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7D9D1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: snapOrange, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: snapOrange,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.restaurant_menu_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Text('SnapChef',
                          style: TextStyle(
                              color: snapOrange,
                              fontSize: 28,
                              fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 30),
                    const Text('A little inspiration.\nA delicious beginning.',
                        style: TextStyle(
                            fontSize: 30,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF392319))),
                    const SizedBox(height: 10),
                    const Text('Create an account. Turn what you have into something you love.',
                        style: TextStyle(
                            fontSize: 15, height: 1.5, color: Color(0xFF746258))),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _name,
                      maxLength: 120,
                      autofillHints: const [AutofillHints.name],
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration('Full name', Icons.person_outline),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter your name.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration('Email address', Icons.mail_outline),
                      validator: (v) => v == null ||
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                          ? 'Please enter a valid email address.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      decoration: _decoration('Password', Icons.lock_outline,
                          hint: 'At least 8 characters',
                          suffix: IconButton(
                            tooltip: _hidePassword ? 'Show password' : 'Hide password',
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                            icon: Icon(_hidePassword
                                ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          )),
                      validator: (v) => v == null || v.length < 8
                          ? 'Use at least 8 characters.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _hideConfirm,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      decoration: _decoration('Confirm password', Icons.lock_outline,
                          suffix: IconButton(
                            tooltip: _hideConfirm ? 'Show confirmation' : 'Hide confirmation',
                            onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                            icon: Icon(_hideConfirm
                                ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          )),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Please confirm your password.'
                          : v != _password.text ? 'Passwords do not match.' : null,
                    ),
                    const SizedBox(height: 26),
                    const Text('What’s your cooking style?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('Choose any dietary preferences (optional).',
                        style: TextStyle(color: Color(0xFF746258))),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Vegetarian', 'Vegan', 'Gluten-free', 'Dairy-free']
                          .map((preference) => FilterChip(
                                label: Text(preference),
                                selected: _preferences.contains(preference),
                                selectedColor: const Color(0xFFFFE8DA),
                                checkmarkColor: snapOrange,
                                backgroundColor: Colors.white,
                                onSelected: (selected) => setState(() {
                                  if (selected) {
                                    _preferences.add(preference);
                                  } else {
                                    _preferences.remove(preference);
                                  }
                                }),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _register,
                        style: FilledButton.styleFrom(
                          backgroundColor: snapOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(_busy ? 'Creating account…' : 'Create account',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(child: TextButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Already have an account? Log in'),
                    )),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text('Snap ingredients. Discover possibilities.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF746258), fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-user preferences loaded from Supabase before editing.
class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});
  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  final Set<String> _cuisines = {};
  final Set<String> _allergens = {};
  final _other = TextEditingController();
  final _name = TextEditingController();
  final Set<String> _dietary = {};
  final Set<String> _meals = {};
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final row = await loadProfile();
      if (!mounted) return;
      setState(() {
        _name.text = row['full_name'] as String? ?? '';
        _other.text = row['other_allergens'] as String? ?? '';
        for (final entry in {
          'cuisines': _cuisines, 'allergens': _allergens,
          'dietary_preferences': _dietary, 'meal_types': _meals,
        }.entries) {
          entry.value..clear()..addAll(List<String>.from(row[entry.key] as List? ?? []));
        }
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = backendError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await backend.auth.signOut();
    } catch (error) {
      if (mounted) showBackendError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _other.dispose();
    _name.dispose();
    super.dispose();
  }

  Widget _choices(List<String> items, Set<String> selected) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) => FilterChip(
          label: Text(item),
          selected: selected.contains(item),
          selectedColor: const Color(0xFFFFE8DA),
          backgroundColor: Colors.white,
          checkmarkColor: snapOrange,
          onSelected: (value) => setState(() {
            value ? selected.add(item) : selected.remove(item);
          }),
        )).toList(),
      );

  Future<void> _finish() async {
    if (_saving || _loading || _loadError != null) return;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name.')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await saveProfile({
        'full_name': _name.text.trim(), 'dietary_preferences': _dietary.toList(),
        'cuisines': _cuisines.toList(), 'allergens': _allergens.toList(),
        'meal_types': _meals.toList(), 'other_allergens': _other.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your preferences have been saved.')));
    } catch (error) {
      if (mounted) showBackendError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your food preferences'),
      actions: [TextButton(onPressed: _saving ? null : _logout, child: const Text('Log out'))],
      backgroundColor: Colors.white,
      foregroundColor: snapOrange,
      surfaceTintColor: Colors.transparent,
    ),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _loadError != null ? Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ])))
      : AbsorbPointer(absorbing: _saving, child: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(26),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('YOUR SNAPCHEF PROFILE', style: TextStyle(
            color: snapOrange, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          const LinearProgressIndicator(value: 1, color: snapOrange),
          const SizedBox(height: 24),
          const Text('Make it your kind\nof delicious.', style: TextStyle(
            fontSize: 30, height: 1.15, fontWeight: FontWeight.w800,
            color: Color(0xFF392319))),
          const SizedBox(height: 10),
          const Text('Choose the flavors you love and ingredients you avoid.',
            style: TextStyle(color: Color(0xFF746258), height: 1.5)),
          const SizedBox(height: 28),
          TextField(controller: _name, maxLength: 120,
            decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 20),
          const Text('Dietary preferences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _choices(['Vegetarian', 'Vegan', 'Gluten-free', 'Dairy-free'], _dietary),
          const SizedBox(height: 20),
          const Text('Meal types', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _choices(['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Dessert'], _meals),
          const SizedBox(height: 20),
          const Text('Favorite cuisines', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Pick as many as you like, or leave blank.',
            style: TextStyle(color: Color(0xFF746258))),
          const SizedBox(height: 12),
          _choices(['Indian', 'Italian', 'Mexican', 'Chinese', 'Thai',
            'Japanese', 'Korean', 'Mediterranean', 'Middle Eastern',
            'American'], _cuisines),
          const SizedBox(height: 28),
          const Text('Allergens to avoid', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Select all that apply (optional).',
            style: TextStyle(color: Color(0xFF746258))),
          const SizedBox(height: 12),
          _choices(['Milk', 'Eggs', 'Peanuts', 'Tree nuts', 'Wheat',
            'Soy', 'Fish', 'Shellfish', 'Sesame'], _allergens),
          const SizedBox(height: 16),
          TextField(
            controller: _other,
            maxLength: 200,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Other ingredients to avoid',
              hintText: 'For example: mustard',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Preferences do not guarantee allergen-free meals. '
              'Always check ingredients and cross-contact information.',
              style: TextStyle(color: Color(0xFF70330F), height: 1.4)),
          ),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: snapOrange, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18)),
            onPressed: _saving ? null : _finish,
            child: Text(_saving ? 'Saving…' : 'Save preferences'),
          )),
        ]),
      ),
    )))),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await backend.auth.signInWithPassword(
        email: _email.text.trim(), password: _password.text);
    } catch (error) {
      if (mounted) showBackendError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(26),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.restaurant_menu_rounded, size: 60, color: snapOrange),
            const SizedBox(height: 12),
            const Text('SnapChef', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, color: snapOrange,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 40),
            const Text('Welcome back.', style: TextStyle(
              fontSize: 32, color: Color(0xFF392319), fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Your next favorite meal starts here.',
              style: TextStyle(color: Color(0xFF746258), fontSize: 16)),
            const SizedBox(height: 28),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Email address',
                prefixIcon: const Icon(Icons.mail_outline, color: snapOrange),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              validator: (v) => v == null ||
                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                ? 'Please enter a valid email address.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _hidden,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline, color: snapOrange),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                suffixIcon: IconButton(
                  tooltip: _hidden ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _hidden = !_hidden),
                  icon: Icon(_hidden ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Enter your password.' : null,
            ),
            Align(alignment: Alignment.centerRight, child: TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RecoveryCodePage())),
              child: const Text('Forgot password?'),
            )),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _login,
              style: FilledButton.styleFrom(
                backgroundColor: snapOrange, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text(_busy ? 'Logging in…' : 'Log in', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const RegistrationPage())),
              child: const Text('New to SnapChef? Create an account'),
            ),
          ]),
        ),
      ),
    ))),
  );
}