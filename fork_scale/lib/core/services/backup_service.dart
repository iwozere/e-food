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

    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      if (file.isFile) {
        final outFile = File(p.join(docs.path, file.name));
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }

    return true;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
