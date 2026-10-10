import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// يتعامل مع التقاط/اختيار الصور وحفظها في مجلد دائم داخل الجهاز
/// (وليس مجلد مؤقت) حتى تبقى متاحة حتى بعد إغلاق التطبيق، وحتى
/// يمكن تضمينها لاحقاً في النسخة الاحتياطية المصدَّرة.
class AttachmentService {
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  Future<String?> captureFromCamera() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85, // ضغط معتدل لتقليل حجم الملف دون فقدان وضوح يُذكر
      maxWidth: 1920,
    );
    if (xFile == null) return null;
    return _saveToAppStorage(xFile);
  }

  Future<String?> pickFromGallery() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (xFile == null) return null;
    return _saveToAppStorage(xFile);
  }

  Future<String> _saveToAppStorage(XFile xFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final attachmentsDir = Directory(p.join(appDir.path, 'attachments'));
    if (!await attachmentsDir.exists()) {
      await attachmentsDir.create(recursive: true);
    }

    final ext = p.extension(xFile.path);
    final fileName = '${_uuid.v4()}$ext';
    final destPath = p.join(attachmentsDir.path, fileName);

    await File(xFile.path).copy(destPath);
    return destPath;
  }
}
