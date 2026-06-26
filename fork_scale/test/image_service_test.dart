import 'package:flutter_test/flutter_test.dart';
import 'package:fork_scale/core/services/image_service.dart';

void main() {
  final service = ImageService();

  group('downloadAndSave URL validation', () {
    // These inputs must be rejected *before* any network call, so the futures
    // resolve to null quickly without touching the filesystem or network.
    test('rejects plaintext http URLs', () async {
      expect(
        await service.downloadAndSave('http://example.com/a.jpg',
            filename: 'a.jpg'),
        isNull,
      );
    });

    test('rejects non-https schemes (ftp, file, data)', () async {
      expect(
        await service.downloadAndSave('ftp://example.com/a.jpg',
            filename: 'a.jpg'),
        isNull,
      );
      expect(
        await service.downloadAndSave('file:///etc/passwd', filename: 'a.jpg'),
        isNull,
      );
    });

    test('rejects malformed / schemeless input', () async {
      expect(
        await service.downloadAndSave('not a url', filename: 'a.jpg'),
        isNull,
      );
      expect(
        await service.downloadAndSave('https://', filename: 'a.jpg'),
        isNull,
      );
      expect(
        await service.downloadAndSave('', filename: 'a.jpg'),
        isNull,
      );
    });
  });
}
