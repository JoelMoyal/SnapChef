import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:snapchef/src/features/ingredients/data/photo_picker.dart';

/// Returns [result] from `pickImage`: an [XFile], null, or an exception to
/// throw.
class _FakeImagePicker extends Fake implements ImagePicker {
  _FakeImagePicker(this.result);

  final Object? result;
  ImageSource? source;
  double? maxWidth;
  bool? requestFullMetadata;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    this.maxWidth = maxWidth;
    this.requestFullMetadata = requestFullMetadata;
    final result = this.result;
    if (result is Exception) throw result;
    return result as XFile?;
  }
}

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10]);

Uint8List _bytes(String ascii, [int skip = 0]) =>
    Uint8List.fromList([...List.filled(skip, 0), ...ascii.codeUnits]);

void main() {
  test('returns a resized photo with its detected format', () async {
    final images = _FakeImagePicker(XFile.fromData(_jpeg, name: 'IMG.heic'));

    final photo = await ImagePickerPhotoPicker(images).pick(PhotoSource.camera);

    expect(photo!.bytes, _jpeg);
    expect(photo.mimeType, 'image/jpeg');
    expect(images.source, ImageSource.camera);
    expect(images.maxWidth, 1600);
    expect(images.requestFullMetadata, isFalse);
  });

  test('a cancelled pick returns null', () async {
    final photo = await ImagePickerPhotoPicker(_FakeImagePicker(null))
        .pick(PhotoSource.gallery);

    expect(photo, isNull);
  });

  test('platform errors become picker errors', () async {
    const cases = {
      'camera_access_denied': PhotoPickerError.accessDenied,
      'camera_access_restricted': PhotoPickerError.accessDenied,
      'photo_access_denied': PhotoPickerError.accessDenied,
      'no_available_camera': PhotoPickerError.noCamera,
      'invalid_image': PhotoPickerError.failed,
    };
    for (final MapEntry(key: code, value: error) in cases.entries) {
      final picker = ImagePickerPhotoPicker(
        _FakeImagePicker(PlatformException(code: code)),
      );
      await expectLater(
        picker.pick(PhotoSource.camera),
        throwsA(
          isA<PhotoPickerException>().having((e) => e.error, 'error', error),
        ),
        reason: code,
      );
    }
  });

  test('imageMimeType recognizes formats from their first bytes', () {
    expect(imageMimeType(_jpeg), 'image/jpeg');
    expect(imageMimeType(_bytes('\x89PNG\r\n')), 'image/png');
    expect(imageMimeType(_bytes('GIF89a')), 'image/gif');
    expect(imageMimeType(_bytes('RIFF\x00\x00\x00\x00WEBPVP8 ')), 'image/webp');
    expect(imageMimeType(_bytes('ftypheic', 4)), 'image/heic');
    expect(imageMimeType(_bytes('ftypmif1', 4)), 'image/heif');
    expect(imageMimeType(_bytes('%PDF-1.7')), isNull);
    expect(imageMimeType(Uint8List(0)), isNull);
  });
}
