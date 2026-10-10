import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/database_helper.dart';
import '../models/template_model.dart';
import 'template_editor_screen.dart';
import 'start_transaction_screen.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final _db = DatabaseHelper.instance;
  List<TemplateModel> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final templates = await _db.getAllTemplates();
    setState(() {
      _templates = templates;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بنك النماذج')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _templates.length,
                    itemBuilder: (context, index) {
                      final t = _templates[index];
                      return _buildTemplateCard(t);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTemplate,
        icon: const Icon(Icons.add),
        label: const Text('نموذج جديد'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_outlined,
                size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'لا توجد نماذج بعد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'أنشئ نموذجاً قياسياً (مثل: إصدار ترخيص عبور) وحدد خطواته المتسلسلة',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _createTemplate,
              icon: const Icon(Icons.add),
              label: const Text('إنشاء أول نموذج'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(TemplateModel t) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.assignment_outlined),
        ),
        title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: t.description != null && t.description!.isNotEmpty
            ? Text(t.description!, maxLines: 2, overflow: TextOverflow.ellipsis)
            : null,
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, t),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('تعديل خطوات النموذج')),
            const PopupMenuItem(value: 'delete', child: Text('حذف النموذج')),
          ],
        ),
        onTap: () => _startTransactionFromTemplate(t),
      ),
    );
  }

  void _handleMenuAction(String action, TemplateModel t) async {
    if (action == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TemplateEditorScreen(existingTemplate: t)),
      );
      _load();
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل تريد حذف نموذج "${t.name}"؟ هذا لن يؤثر على المعاملات التي بدأت منه سابقاً.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('حذف')),
          ],
        ),
      );
      if (confirmed == true) {
        await _db.deleteTemplate(t.id);
        _load();
      }
    }
  }

  void _createTemplate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TemplateEditorScreen()),
    );
    _load();
  }

  void _startTransactionFromTemplate(TemplateModel t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StartTransactionScreen(template: t)),
    );
  }
}
