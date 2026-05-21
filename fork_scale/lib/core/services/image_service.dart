import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageService {
  /// Resizes [source] to max 1536px longest side for Gemini API call.
  /// Runs in a background isolate. Returns JPEG bytes.
  Future<Uint8List> resizeForApi(File source) async {
    final bytes = await source.readAsBytes();
    return Isolate.run(() => _resize(bytes, 1536));
  }

  /// Saves the photo at max 1200px, returns the absolute path.
  Future<String> saveForHistory(File source, {required String filename}) async {
    final bytes = await source.readAsBytes();
    final resized = await Isolate.run(() => _resize(bytes, 1200));
    final dir = await _photoDir();
    final dest = File(p.join(dir.path, filename));
    await dest.writeAsBytes(resized, flush: true);
    return dest.path;
  }

  Future<Directory> _photoDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'meal_photos'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  static Uint8List _resize(Uint8List bytes, int maxDim) {
    final original = img.decodeImage(bytes)!;
    final resized = original.width > original.height
        ? (original.width > maxDim
            ? img.copyResize(original, width: maxDim)
            : original)
        : (original.height > maxDim
            ? img.copyResize(original, height: maxDim)
            : original);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  /// Downloads an image from [url] and saves it to the meal_photos dir.
  /// Returns the absolute path, or null if the download fails.
  Future<String?> downloadAndSave(String url, {required String filename}) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final dir = await _photoDir();
      final dest = File(p.join(dir.path, filename));
      await dest.writeAsBytes(response.bodyBytes, flush: true);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> deletePhoto(String path) async {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }
}
