import 'package:image_picker/image_picker.dart';
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

class SupabaseImageUploadResult {
  final String url;
  final String path;

  const SupabaseImageUploadResult({required this.url, required this.path});
}

class SupabaseImageUploadService {
  static const String bucketName = 'work_connect';
  static const String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mlsamssnsvlouxbjnibr.supabase.co',
  );
  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_l9E3-HqAGVkQx17HGfXBdQ_pRQ6ajM-',
  );

  static final SupabaseClient _client = SupabaseClient(
    _supabaseUrl,
    _supabaseAnonKey,
  );
  static final ImagePicker _picker = ImagePicker();
  static const Uuid _uuid = Uuid();

  static bool get isConfigured =>
      _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  static Future<SupabaseImageUploadResult?> pickAndUpload({
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await _picker.pickImage(source: source, imageQuality: 80);
    if (file == null) return null;
    return uploadXFile(file);
  }

  static Future<List<SupabaseImageUploadResult>> pickMultipleAndUpload({
    int limit = 4,
  }) async {
    final files = await _picker.pickMultiImage(imageQuality: 80, limit: limit);
    final uploads = <SupabaseImageUploadResult>[];
    for (final file in files) {
      uploads.add(await uploadXFile(file));
    }
    return uploads;
  }

  static Future<SupabaseImageUploadResult> uploadXFile(XFile file) async {
    _ensureConfigured();

    final bytes = await file.readAsBytes();
    final extension = _extensionFromName(
      file.name.isNotEmpty ? file.name : file.path,
    );
    final objectPath = 'jobs/${_uuid.v4()}$extension';

    await _client.storage
        .from(bucketName)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeForExtension(extension),
            upsert: false,
          ),
        );

    final publicUrl = _client.storage.from(bucketName).getPublicUrl(objectPath);
    return SupabaseImageUploadResult(url: publicUrl, path: objectPath);
  }

  static Future<void> deleteObject(String path) async {
    if (!isConfigured) return;
    await _client.storage.from(bucketName).remove([path]);
  }

  static void _ensureConfigured() {
    if (isConfigured) return;
    throw Exception(
      'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY '
      'using --dart-define, and create a public storage bucket named $bucketName.',
    );
  }

  static String _extensionFromName(String name) {
    final lower = name.toLowerCase();
    for (final ext in const ['.png', '.jpg', '.jpeg', '.webp', '.gif']) {
      if (lower.endsWith(ext)) return ext == '.jpeg' ? '.jpg' : ext;
    }
    return '.jpg';
  }

  static String _contentTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
