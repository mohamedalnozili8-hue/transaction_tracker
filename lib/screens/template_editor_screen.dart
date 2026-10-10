import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/database_helper.dart';
import '../models/template_model.dart';

class TemplateEditorScreen extends StatefulWidget {
  final TemplateModel? existingTemplate;
  const TemplateEditorScreen({super.key, this.existingTemplate});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _StepDraft {
  String id;
  TextEditingController titleController;
  TextEditingController entityController;
  _StepDraft({required this.id, String title = '', String entity = ''})
      : titleController = TextEditingController(text: title),
        entityController = TextEditingController(text: entity);
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final List<_StepDraft> _steps = [];
  bool _loading = true;
  bool _saving = false;

  bool get _isEditing => widget.existingTemplate != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_isEditing) {
      _nameController.text = widget.existingTemplate!.name;
      _descController.text = widget.existingTemplate!.description ?? '';
      final steps = await _db.getTemplateSteps(widget.existingTemplate!.id);
      for (final s in steps) {
        _steps.add(_StepDraft(id: s.id, title: s.title, entity: s.entity ?? ''));
      }
    }
    if (_steps.isEmpty) {
      _steps.add(_StepDraft(id: _uuid.v4()));
    }
    setState(() => _loading = false);
  }

  void _addStep() {
    setState(() => _steps.add(_StepDraft(id: _uuid.v4())));
  }

  void _removeStep(int index) {
    if (_steps.length <= 1) return;
    setState(() => _steps.removeAt(index));
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, item);
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم النموذج')));
      return;
    }

    final validSteps =
        _steps.where((s) => s.titleController.text.trim().isNotEmpty).toList();
    if (validSteps.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى إضافة خطوة واحدة على الأقل')));
      return;
    }

    setState(() => _saving = true);

    final templateId = widget.existingTemplate?.id ?? _uuid.v4();
    final template = TemplateModel(
      id: templateId,
      name: name,
      description: _descController.text.trim(),
      createdAt: widget.existingTemplate?.createdAt ?? DateTime.now(),
    );
    await _db.insertTemplate(template);

    for (int i = 0; i < validSteps.length; i++) {
      final draft = validSteps[i];
      final step = TemplateStepModel(
        id: draft.id,
        templateId: templateId,
        title: draft.titleController.text.trim(),
        entity: draft.entityController.text.trim().isEmpty
            ? null
            : draft.entityController.text.trim(),
        order: i,
      );
      await _db.insertTemplateStep(step);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل النموذج' : 'نموذج جديد'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(onPressed: _save, child: const Text('حفظ')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'اسم النموذج',
              hintText: 'مثال: إصدار ترخيص عبور',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'وصف مختصر (اختياري)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الخطوات القياسية بالتسلسل',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                onPressed: _addStep,
                icon: const Icon(Icons.add),
                label: const Text('إضافة خطوة'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _steps.length,
            onReorder: _reorderSteps,
            itemBuilder: (context, index) {
              final step = _steps[index];
              return Card(
                key: ValueKey(step.id),
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        child: Text('${index + 1}'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: step.titleController,
                              decoration: const InputDecoration(
                                labelText: 'عنوان الخطوة',
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: step.entityController,
                              decoration: const InputDecoration(
                                labelText: 'الجهة المسؤولة (اختياري)',
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeStep(index),
                      ),
                      const Icon(Icons.drag_handle, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    for (final s in _steps) {
      s.titleController.dispose();
      s.entityController.dispose();
    }
    super.dispose();
  }
}
