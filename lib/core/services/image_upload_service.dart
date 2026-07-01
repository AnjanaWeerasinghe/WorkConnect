import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Saves picked images to the device's local documents directory.
/// Returns local file paths (not Firebase URLs).
class ImageUploadService {
  static final _picker = ImagePicker();
  static const _uuid = Uuid();

  // ── Pick images ────────────────────────────────────────────────────────────

  /// Pick a single image from gallery or camera.
  static Future<XFile?> pickSingle({ImageSource source = ImageSource.gallery}) =>
      _picker.pickImage(source: source, imageQuality: 80);

  /// Pick up to [limit] images from the gallery.
  static Future<List<XFile>> pickMultiple({int limit = 4}) async {
    final files = await _picker.pickMultiImage(imageQuality: 80, limit: limit);
    return files;
  }

  // ── Save helpers ───────────────────────────────────────────────────────────

  /// Copy an [XFile] into the app's local images folder and return the saved path.
  static Future<String> saveXFile(XFile file) async {
    final dir = await _localImagesDir();
    final ext = file.path.endsWith('.png') ? '.png' : '.jpg';
    final dest = File('${dir.path}/${_uuid.v4()}$ext');
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await dest.writeAsBytes(bytes);
    } else {
      await File(file.path).copy(dest.path);
    }
    return dest.path;
  }

  /// Save multiple images and return their local paths.
  static Future<List<String>> saveMultiple(List<XFile> files) async {
    final paths = <String>[];
    for (final f in files) {
      paths.add(await saveXFile(f));
    }
    return paths;
  }

  /// Pick a single image and immediately save it locally. Returns path or null.
  static Future<String?> pickAndSave({ImageSource source = ImageSource.gallery}) async {
    final file = await pickSingle(source: source);
    if (file == null) return null;
    return saveXFile(file);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<Directory> _localImagesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/workconnect_images');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Delete a previously saved local image.
  static Future<void> deleteLocal(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
