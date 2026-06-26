import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fork_scale/core/services/backup_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('BackupService.extractArchive', () {
    late Directory tmpRoot;
    late Directory docsDir;

    setUp(() async {
      tmpRoot = await Directory.systemTemp.createTemp('fs_backup_test_');
      docsDir = Directory(p.join(tmpRoot.path, 'docs'));
      await docsDir.create();
    });

    tearDown(() async {
      if (await tmpRoot.exists()) await tmpRoot.delete(recursive: true);
    });

    ArchiveFile fileEntry(String name, String content) {
      final bytes = Uint8List.fromList(content.codeUnits);
      return ArchiveFile(name, bytes.length, bytes);
    }

    test('restores legitimate entries under docsPath', () async {
      final archive = Archive()
        ..addFile(fileEntry('fork_scale.db', 'DBDATA'))
        ..addFile(fileEntry('meal_photos/a.jpg', 'JPEG'));

      final written = await BackupService.extractArchive(archive, docsDir.path);

      expect(written, hasLength(2));
      expect(File(p.join(docsDir.path, 'fork_scale.db')).existsSync(), isTrue);
      expect(
        File(p.join(docsDir.path, 'meal_photos', 'a.jpg')).existsSync(),
        isTrue,
      );
    });

    test('drops path-traversal entries and writes nothing outside docsPath',
        () async {
      final evilTarget = p.normalize(p.join(docsDir.path, '..', 'evil.txt'));
      final archive = Archive()
        ..addFile(fileEntry('../evil.txt', 'PWNED'))
        ..addFile(fileEntry('../../evil2.txt', 'PWNED'))
        ..addFile(fileEntry('meal_photos/ok.jpg', 'OK'));

      final written = await BackupService.extractArchive(archive, docsDir.path);

      // Only the safe entry is written.
      expect(written, hasLength(1));
      expect(
        File(p.join(docsDir.path, 'meal_photos', 'ok.jpg')).existsSync(),
        isTrue,
      );
      // The traversal targets must not exist.
      expect(File(evilTarget).existsSync(), isFalse);
      expect(
        File(p.normalize(p.join(docsDir.path, '..', '..', 'evil2.txt')))
            .existsSync(),
        isFalse,
      );
    });
  });
}
