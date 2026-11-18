import '../../../core/models/ingredient.dart';
import 'photo_picker.dart';

/// Why ingredient recognition failed.
enum IngredientDetectionError {
  /// No connection: the photo never reached the server.
  offline,

  /// The server didn't answer in time.
  timeout,

  /// The recognition service is over its usage limit for now.
  busy,

  /// The photo is too large or not an image format recognition can read.
  invalidPhoto,

  /// The session expired, so the server refused the request.
  signedOut,

  /// Any other server or recognition failure.
  failed;

  /// Whether sending the same photo again could succeed.
  bool get isRetryable => switch (this) {
    offline || timeout || busy || failed => true,
    invalidPhoto || signedOut => false,
  };
}

class IngredientDetectionException implements Exception {
  const IngredientDetectionException(this.error);

  final IngredientDetectionError error;

  @override
  String toString() => 'IngredientDetectionException($error)';
}

/// Contract for recognizing ingredients. The UI depends on this interface,
/// never on a concrete data source, so the recognition service can change
/// without touching the screens.
abstract interface class IngredientRepository {
  /// Returns the ingredients recognized in [photo], possibly none. Throws
  /// [IngredientDetectionException].
  Future<List<Ingredient>> detectFromPhoto(Photo photo);
}

/// Returns the same few ingredients for any photo, so the flow can be tried
/// without the backend. Run the app with `--dart-define=STUB_DETECTION=true`.
class StubIngredientRepository implements IngredientRepository {
  StubIngredientRepository({this.latency = const Duration(milliseconds: 800)});

  final Duration latency;

  @override
  Future<List<Ingredient>> detectFromPhoto(Photo photo) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return [
      Ingredient.named('tomato'),
      Ingredient.named('egg'),
      Ingredient.named('onion'),
    ];
  }
}
