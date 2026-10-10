import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import '../db/database_helper.dart';

/// يتعامل مع:
/// 1. تصدير نسخة احتياطية كاملة (قاعدة البيانات + مجلد المرفقات) كملف .zip واحد
///    قابل للإرسال عبر أي تطبيق مشاركة (واتساب، بلوتوث، بريد...).
/// 2. استيراد ملف .zip من جهاز آخر ودمج بياناته مع القاعدة المحلية
///    (دمج فقط، بدون أي حذف لما هو موجود محلياً).
class BackupService {
  final _dbHelper = DatabaseHelper.instance;

  /// يُنشئ ملف ZIP يحتوي على نسخة من قاعدة البيانات ومجلد المرفقات،
  /// ثم يفتح واجهة المشاركة الجاهزة في النظام حتى يختار المستخدم
  /// أين يرسله (واتساب، بلوتوث، بريد، إلخ).
  Future<void> exportAndShareBackup() async {
    final zipFile = await _createBackupZip();
    await Share.shareXFiles(
      [XFile(zipFile.path)],
      text: 'نسخة احتياطية من تطبيق متابعة المعاملات',
      subject: 'نسخة احتياطية - متابعة المعاملات',
    );
  }

  Future<File> _createBackupZip() async {
    final tempDir = await getTemporaryDirectory();
    final dbPath = await _dbHelper.getDbPath();
    final dbFile = File(dbPath);

    final attachmentsDir = await _getAttachmentsDir();

    final archive = Archive();

    // إضافة ملف قاعدة البيانات
    if (await dbFile.exists()) {
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('backup.db', dbBytes.length, dbBytes));
    }

    // إضافة مجلد المرفقات بالكامل إن وجد
    if (await attachmentsDir.exists()) {
      final files = attachmentsDir.listSync(recursive: true);
      for (final entity in files) {
        if (entity is File) {
          final relativePath =
              'attachments/${p.relative(entity.path, from: attachmentsDir.path)}';
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
        }
      }
    }

    final zipData = ZipEncoder().encode(archive);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipFile = File('${tempDir.path}/نسخة_احتياطية_$timestamp.zip');
    await zipFile.writeAsBytes(zipData!);
    return zipFile;
  }

  /// يفتح منتقي الملفات حتى يختار المستخدم ملف .zip مستلَم من جهاز آخر،
  /// يفك ضغطه، يفتح قاعدة البيانات المؤقتة منه، ثم يدمجها مع القاعدة المحلية.
  Future<ImportResult> pickAndImportBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.single.path == null) {
      return ImportResult(success: false, message: 'لم يتم اختيار أي ملف');
    }

    final zipPath = result.files.single.path!;
    return importBackupFromPath(zipPath);
  }

  Future<ImportResult> importBackupFromPath(String zipPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final extractDir =
          Directory('${tempDir.path}/import_${DateTime.now().millisecondsSinceEpoch}');
      await extractDir.create(recursive: true);

      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final outPath = p.join(extractDir.path, file.name);
        if (file.isFile) {
          final outFile = File(outPath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(outPath).create(recursive: true);
        }
      }

      final extractedDbFile = File(p.join(extractDir.path, 'backup.db'));
      if (!await extractedDbFile.exists()) {
        return ImportResult(
            success: false, message: 'الملف المختار لا يحتوي على نسخة بيانات صالحة');
      }

      // نسخ المرفقات المستوردة إلى مجلد المرفقات المحلي (بدون حذف أي شيء موجود)
      final extractedAttachmentsDir =
          Directory(p.join(extractDir.path, 'attachments'));
      if (await extractedAttachmentsDir.exists()) {
        final localAttachmentsDir = await _getAttachmentsDir();
        await localAttachmentsDir.create(recursive: true);
        final files = extractedAttachmentsDir.listSync(recursive: true);
        for (final entity in files) {
          if (entity is File) {
            final relativePath =
                p.relative(entity.path, from: extractedAttachmentsDir.path);
            final destPath = p.join(localAttachmentsDir.path, relativePath);
            await File(destPath).create(recursive: true);
            await entity.copy(destPath);
          }
        }
      }

      // فتح قاعدة البيانات المستوردة كقراءة فقط ثم دمجها
      final externalDb = await openDatabase(extractedDbFile.path, readOnly: true);
      final mergeResult = await _dbHelper.mergeFromExternalDb(externalDb);
      await externalDb.close();

      // تنظيف الملفات المؤقتة
      await extractDir.delete(recursive: true);

      return ImportResult(
        success: true,
        message: 'تم الدمج بنجاح: ${mergeResult.templatesAdded} قالب جديد، '
            '${mergeResult.transactionsAdded} معاملة جديدة، '
            '${mergeResult.stepsAdded} خطوة جديدة أُضيفت. '
            'لم يُحذف أو يُعدَّل أي شيء من بياناتك الحالية.',
      );
    } catch (e) {
      return ImportResult(success: false, message: 'حدث خطأ أثناء الاستيراد: $e');
    }
  }

  Future<Directory> _getAttachmentsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(appDir.path, 'attachments'));
  }
}

class ImportResult {
  final bool success;
  final String message;

  ImportResult({required this.success, required this.message});
}
