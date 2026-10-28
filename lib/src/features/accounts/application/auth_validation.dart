/// Field validators for the auth forms. Each returns an error message, or null
/// when the value is valid, so they plug straight into `TextFormField`.
abstract final class AuthValidation {
  static const minPasswordLength = 8;
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? required(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  static String? email(String? value) {
    final missing = required(value, 'Enter your email');
    if (missing != null) return missing;
    return _emailPattern.hasMatch(value!.trim()) ? null : 'Enter a valid email';
  }

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Create a password';
    if (value.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters';
    }
    return null;
  }
}
