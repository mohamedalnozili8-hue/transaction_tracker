import 'package:flutter/material.dart';
import '../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _backupService = BackupService();
  bool _exporting = false;
  bool _importing = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await _backupService.exportAndShareBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذّر إنشاء النسخة الاحتياطية: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استيراد ودمج نسخة احتياطية'),
        content: const Text(
          'سيتم إضافة النماذج والمعاملات الموجودة في الملف المستلَم إلى بياناتك الحالية.\n\n'
          'لن يُحذف أو يُعدَّل أي شيء من بياناتك الحالية — هذه عملية دمج آمنة فقط.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true), child: const Text('متابعة')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _importing = true);
    try {
      final result = await _backupService.pickAndImportBackup();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(result.success ? 'تم الدمج بنجاح' : 'حدث خطأ'),
            content: Text(result.message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.backup_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text('النسخ الاحتياطي والمشاركة',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'تطبيق يعمل بالكامل دون إنترنت. يمكنك تصدير جميع بياناتك '
                    '(النماذج، المعاملات، الملاحظات، والصور المرفقة) كملف واحد '
                    'وإرساله لشخص آخر عبر واتساب أو البلوتوث أو أي تطبيق آخر، '
                    'ليفتحه على نفس التطبيق في جهازه فتُدمج البيانات تلقائياً معه.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _exporting ? null : _export,
                      icon: _exporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.ios_share),
                      label: Text(_exporting ? 'جارِ التجهيز...' : 'تصدير ومشاركة نسخة احتياطية'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _importing ? null : _import,
                      icon: _importing
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.file_download_outlined),
                      label: Text(_importing ? 'جارِ الاستيراد...' : 'استيراد ودمج نسخة من جهاز آخر'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('عن التطبيق'),
              subtitle: const Text(
                  'تطبيق متابعة المعاملات الإدارية — يعمل بالكامل محلياً دون إنترنت، '
                  'مع اقتراحات ذكية مبنية على أنماط معاملاتك السابقة.'),
            ),
          ),
        ],
      ),
    );
  }
}
