import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';

class BackupService {
  static Future<void> createBackup() async {
    final docs = await getApplicationDocumentsDirectory();
    final tmp = await getTemporaryDirectory();
    final now = DateTime.now();
    final name = 'forkscale_backup_'
        '${now.year}-${_pad(now.month)}-${_pad(now.day)}.zip';
    final zipPath = p.join(tmp.path, name);

    // Flush WAL into the main .db file so the zip contains a self-contained snapshot.
    final db = await AppDatabase.mealsDb;
    await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    final dbFile = File(p.join(docs.path, 'fork_scale.db'));
    if (dbFile.existsSync()) {
      encoder.addFile(dbFile, 'fork_scale.db');
    }

    final photosDir = Directory(p.join(docs.path, 'meal_photos'));
    if (photosDir.existsSync()) {
      await for (final entity in photosDir.list(recursive: true)) {
        if (entity is File) {
          final rel = p.relative(entity.path, from: docs.path);
          encoder.addFile(entity, rel);
        }
      }
    }

    encoder.close();

    await Share.shareXFiles([XFile(zipPath)], subject: 'ForkScale backup');
  }

  static Future<bool> restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return false;

    final zipPath = result.files.single.path!;
    final docs = await getApplicationDocumentsDirectory();

    await AppDatabase.closeAll();

    // Delete stale WAL sidecars so SQLite doesn't replay them against the restored file.
    final dbPath = p.join(docs.path, 'fork_scale.db');
    for (final ext in ['-wal', '-shm']) {
      final sidecar = File('$dbPath$ext');
      if (await sidecar.exists()) await sidecar.delete();
    }

    // Use streaming decode to avoid loading the entire zip into memory at once.
    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);

    for (final file in archive) {
      if (!file.isFile) continue;
      final outPath = p.normalize(p.join(docs.path, file.name));
      if (!p.isWithin(docs.path, outPath)) continue; // block path-traversal entries
      final outFile = File(outPath);
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
    }

    inputStream.close();

    return true;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
