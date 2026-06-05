import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Lightweight helper for picking and uploading images to Firebase Storage.
class ImageUploadService {
  static final _storage = FirebaseStorage.instance;
  static final _picker  = ImagePicker();

  // ── Pick images ────────────────────────────────────────────────────────────

  /// Pick a single image from the gallery.
  static Future<XFile?> pickSingle({ImageSource source = ImageSource.gallery}) =>
      _picker.pickImage(source: source, imageQuality: 80);

  /// Pick up to [limit] images from the gallery.
  static Future<List<XFile>> pickMultiple({int limit = 4}) async {
    final files = await _picker.pickMultiImage(imageQuality: 80, limit: limit);
    return files;
  }

  // ── Upload helpers ─────────────────────────────────────────────────────────

  /// Upload a single [XFile] to [storagePath] and return the download URL.
  static Future<String> uploadXFile(XFile file, String storagePath) async {
    final ref = _storage.ref(storagePath);
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      await ref.putFile(File(file.path));
    }
    return ref.getDownloadURL();
  }

  /// Upload multiple images to `basePath/{index}.jpg` and return their URLs.
  static Future<List<String>> uploadMultiple(
    List<XFile> files,
    String basePath,
  ) async {
    final urls = <String>[];
    for (int i = 0; i < files.length; i++) {
      final url = await uploadXFile(files[i], '$basePath/$i.jpg');
      urls.add(url);
    }
    return urls;
  }

  /// Pick and immediately upload a single image. Returns download URL or null.
  static Future<String?> pickAndUpload({
    required String storagePath,
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await pickSingle(source: source);
    if (file == null) return null;
    return uploadXFile(file, storagePath);
  }
}
