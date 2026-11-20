import 'package:flutter_test/flutter_test.dart';
import 'package:snapchef/src/features/accounts/application/auth_validation.dart';

void main() {
  group('AuthValidation', () {
    test('required rejects empty and whitespace-only values', () {
      expect(AuthValidation.required(null, 'msg'), 'msg');
      expect(AuthValidation.required('  ', 'msg'), 'msg');
      expect(AuthValidation.required('Ana', 'msg'), isNull);
    });

    test('email requires a value and a valid shape', () {
      expect(AuthValidation.email(''), 'Enter your email');
      expect(AuthValidation.email('ana@'), 'Enter a valid email');
      expect(AuthValidation.email(' ana@example.com '), isNull);
    });

    test('newPassword enforces the minimum length', () {
      expect(AuthValidation.newPassword(''), 'Create a password');
      expect(AuthValidation.newPassword('short'), contains('at least'));
      expect(AuthValidation.newPassword('longenough'), isNull);
    });
  });
}
