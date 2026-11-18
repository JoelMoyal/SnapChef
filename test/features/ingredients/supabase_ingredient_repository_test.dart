import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snapchef/src/features/ingredients/data/ingredient_repository.dart';
import 'package:snapchef/src/features/ingredients/data/photo_picker.dart';
import 'package:snapchef/src/features/ingredients/data/supabase_ingredient_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionsClient;

import 'fakes.dart';

final _clients = <FunctionsClient>[];

/// A repository whose server answers every request with [handler].
SupabaseIngredientRepository _repository(
  MockClientHandler handler, {
  Duration timeout = const Duration(seconds: 5),
}) {
  final functions = FunctionsClient(
    'https://project.supabase.co/functions/v1',
    {'apikey': 'test-key'},
    httpClient: MockClient(handler),
  );
  _clients.add(functions);
  return SupabaseIngredientRepository(functions, timeout: timeout);
}

MockClientHandler _answer(int status, Object body) =>
    (_) async => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Matcher _failsWith(IngredientDetectionError error) => throwsA(
  isA<IngredientDetectionException>().having((e) => e.error, 'error', error),
);

void main() {
  tearDown(() {
    for (final functions in _clients) {
      functions.dispose();
    }
    _clients.clear();
  });

  test('sends the photo to detect-ingredients and reads the names', () async {
    late http.Request sent;
    final repo = _repository((request) async {
      sent = request;
      return _answer(200, {
        'ingredients': [
          {'name': 'tomato'},
          {'name': '  '},
          {'oops': true},
          'egg',
          {'name': 'green onion'},
        ],
      })(request);
    });

    final found = await repo.detectFromPhoto(testPhoto);

    expect([for (final i in found) i.name], ['Tomato', 'Green onion']);
    expect(sent.method, 'POST');
    expect(sent.url.path, '/functions/v1/detect-ingredients');
    expect(jsonDecode(sent.body), {
      'image': base64Encode(testPhoto.bytes),
      'mimeType': 'image/jpeg',
    });
  });

  test('maps function errors to what the user can do about them', () async {
    const cases = {
      400: IngredientDetectionError.invalidPhoto,
      401: IngredientDetectionError.signedOut,
      404: IngredientDetectionError.failed,
      413: IngredientDetectionError.invalidPhoto,
      415: IngredientDetectionError.invalidPhoto,
      429: IngredientDetectionError.busy,
      500: IngredientDetectionError.failed,
      502: IngredientDetectionError.failed,
      504: IngredientDetectionError.timeout,
    };
    for (final MapEntry(key: status, value: error) in cases.entries) {
      final repo = _repository(_answer(status, {'error': 'x'}));
      await expectLater(
        repo.detectFromPhoto(testPhoto),
        _failsWith(error),
        reason: '$status',
      );
    }
  });

  test('no connection is reported as offline', () async {
    final repo = _repository((_) => throw http.ClientException('no network'));

    await expectLater(
      repo.detectFromPhoto(testPhoto),
      _failsWith(IngredientDetectionError.offline),
    );
  });

  test('a server that never answers times out', () async {
    final repo = _repository(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      repo.detectFromPhoto(testPhoto),
      _failsWith(IngredientDetectionError.timeout),
    );
  });

  test('an unexpected answer is a failure', () async {
    final repo = _repository(_answer(200, {'result': []}));

    await expectLater(
      repo.detectFromPhoto(testPhoto),
      _failsWith(IngredientDetectionError.failed),
    );
  });

  test('unsupported images are rejected without a request', () async {
    final repo = _repository((_) => fail('should not send'));

    for (final mimeType in ['image/gif', null]) {
      await expectLater(
        repo.detectFromPhoto(
          Photo(bytes: Uint8List.fromList([1, 2, 3]), mimeType: mimeType),
        ),
        _failsWith(IngredientDetectionError.invalidPhoto),
      );
    }
  });
}
