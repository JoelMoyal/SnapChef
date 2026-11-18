import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Where a photo comes from.
enum PhotoSource { camera, gallery }

/// A photo ready to send for recognition.
class Photo {
  const Photo({required this.bytes, required this.mimeType});

  final Uint8List bytes;

  /// For example `image/jpeg`; null when the format isn't recognized.
  final String? mimeType;
}

/// Why a photo couldn't be taken or opened.
enum PhotoPickerError {
  /// Camera or photo access is turned off for SnapChef.
  accessDenied,

  /// The device has no camera to take a picture with.
  noCamera,

  /// The photo couldn't be loaded.
  failed,
}

class PhotoPickerException implements Exception {
  const PhotoPickerException(this.error);

  final PhotoPickerError error;

  @override
  String toString() => 'PhotoPickerException($error)';
}

/// Takes or chooses a photo. The UI depends on this interface so tests can
/// fake the platform pickers.
abstract interface class PhotoPicker {
  /// Returns null when the user cancels. Throws [PhotoPickerException].
  Future<Photo?> pick(PhotoSource source);
}

/// Uses the system camera and photo picker. Permission prompts appear the
/// first time each source is used, not before.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Photo?> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: switch (source) {
          PhotoSource.camera => ImageSource.camera,
          PhotoSource.gallery => ImageSource.gallery,
        },
        // Enough detail to name small items while keeping uploads near
        // 0.5 MB. Resized photos come back as JPEG (or PNG for PNGs).
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        // Lets iOS show its photo picker without asking for library access.
        requestFullMetadata: false,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return Photo(bytes: bytes, mimeType: imageMimeType(bytes));
    } on PlatformException catch (e) {
      throw PhotoPickerException(switch (e.code) {
        'camera_access_denied' ||
        'camera_access_restricted' ||
        'photo_access_denied' ||
        'photo_access_restricted' => PhotoPickerError.accessDenied,
        'no_available_camera' => PhotoPickerError.noCamera,
        _ => PhotoPickerError.failed,
      });
    } on Exception {
      throw const PhotoPickerException(PhotoPickerError.failed);
    }
  }
}

/// Identifies an image from its first bytes. File names can't be trusted:
/// Android may keep a `.heic` name on a photo it re-encoded as JPEG.
@visibleForTesting
String? imageMimeType(Uint8List bytes) {
  bool startsWith(List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  String ascii(int start, int end) =>
      bytes.length < end ? '' : String.fromCharCodes(bytes.sublist(start, end));

  if (startsWith([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (startsWith([0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (ascii(0, 4) == 'GIF8') return 'image/gif';
  if (ascii(0, 4) == 'RIFF' && ascii(8, 12) == 'WEBP') return 'image/webp';
  if (ascii(4, 8) == 'ftyp') {
    final brand = ascii(8, 12);
    if (const {'heic', 'heix', 'heim', 'heis'}.contains(brand)) {
      return 'image/heic';
    }
    if (const {'mif1', 'msf1'}.contains(brand)) return 'image/heif';
  }
  return null;
}
