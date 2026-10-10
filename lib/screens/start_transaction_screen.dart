import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/database_helper.dart';
import '../models/template_model.dart';
import '../models/transaction_model.dart';
import '../services/pattern_service.dart';
import 'active_transactions_screen.dart';

class StartTransactionScreen extends StatefulWidget {
  final TemplateModel template;
  const StartTransactionScreen({super.key, required this.template});

  @override
  State<StartTransactionScreen> createState() => _StartTransactionScreenState();
}

class _StartTransactionScreenState extends State<StartTransactionScreen> {
  final _db = DatabaseHelper.instance;
  final _patternService = PatternService();
  final _uuid = const Uuid();
  final _titleController = TextEditingController();

  List<TemplateStepModel> _standardSteps = [];
  List<PatternSuggestion> _suggestions = [];
  final Set<String> _acceptedSuggestionIds = {};
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.template.name;
    _load();
  }

  Future<void> _load() async {
    final steps = await _db.getTemplateSteps(widget.template.id);
    final suggestions = await _patternService.getSuggestions(widget.template.id);
    setState(() {
      _standardSteps = steps;
      _suggestions = suggestions;
      _loading = false;
    });
  }

  void _toggleSuggestion(String id, bool accepted) {
    setState(() {
      if (accepted) {
        _acceptedSuggestionIds.add(id);
      } else {
        _acceptedSuggestionIds.remove(id);
      }
    });
  }

  Future<void> _createTransaction() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم للمعاملة')));
      return;
    }

    setState(() => _creating = true);

    final transactionId = _uuid.v4();
    final now = DateTime.now();

    final transaction = TransactionModel(
      id: transactionId,
      templateId: widget.template.id,
      templateName: widget.template.name,
      title: title,
      startedAt: now,
      status: TransactionStatus.active,
      currentStepIndex: 0,
    );
    await _db.insertTransaction(transaction);

    int order = 0;

    // إدراج الخطوات القياسية
    for (final step in _standardSteps) {
      final instance = TransactionStepInstance(
        id: _uuid.v4(),
        transactionId: transactionId,
        title: step.title,
        entity: step.entity,
        order: order,
        kind: StepKind.standard,
        status: order == 0 ? StepStatus.inProgress : StepStatus.pending,
        startedAt: order == 0 ? now : null,
      );
      await _db.insertTransactionStep(instance);
      order++;
    }

    // إدراج الخطوات المقترحة التي وافق عليها المستخدم (تُضاف في نهاية المسار)
    for (final suggestion in _suggestions) {
      if (_acceptedSuggestionIds.contains(suggestion.id)) {
        final instance = TransactionStepInstance(
          id: _uuid.v4(),
          transactionId: transactionId,
          title: suggestion.exceptionTitle,
          entity: suggestion.exceptionEntity,
          order: order,
          kind: StepKind.exceptional,
          status: StepStatus.pending,
        );
        await _db.insertTransactionStep(instance);
        order++;
      }
    }

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ActiveTransactionsScreen()),
        (route) => route.isFirst,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بدء معاملة جديدة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المعاملة',
                    hintText: 'مثال: ترخيص عبور - شركة الفجر',
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                ),
                const SizedBox(height: 20),

                if (_suggestions.isNotEmpty) ...[
                  _buildSuggestionsBanner(),
                  const SizedBox(height: 20),
                ],

                const Text('خطوات المعاملة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                ..._standardSteps.asMap().entries.map((entry) {
                  final i = entry.key;
                  final step = entry.value;
                  return _buildStepPreview(i + 1, step.title, step.entity, false);
                }),
                ..._suggestions.where((s) => _acceptedSuggestionIds.contains(s.id)).map(
                      (s) => _buildStepPreview(
                          _standardSteps.length +
                              _suggestions
                                  .where((x) => _acceptedSuggestionIds.contains(x.id))
                                  .toList()
                                  .indexOf(s) +
                              1,
                          s.exceptionTitle,
                          s.exceptionEntity,
                          true),
                    ),

                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _creating ? null : _createTransaction,
                  icon: _creating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_creating ? 'جارِ الإنشاء...' : 'بدء المعاملة'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSuggestionsBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber.shade700),
            const SizedBox(width: 6),
            const Text('اقتراحات ذكية بناءً على معاملات سابقة',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        ..._suggestions.map((s) => Card(
              color: Colors.amber.shade50,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.promptText),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _toggleSuggestion(s.id, false),
                            child: Text(_acceptedSuggestionIds.contains(s.id)
                                ? 'تراجع عن الإضافة'
                                : 'لا، شكراً'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _toggleSuggestion(s.id, true),
                            child: Text(_acceptedSuggestionIds.contains(s.id)
                                ? 'تمت الإضافة ✓'
                                : 'نعم، أضفها'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildStepPreview(int number, String title, String? entity, bool isException) {
    return Card(
      color: isException ? Colors.amber.shade50 : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(radius: 14, child: Text('$number')),
        title: Text(title),
        subtitle: entity != null && entity.isNotEmpty ? Text(entity) : null,
        trailing: isException
            ? Icon(Icons.auto_awesome, size: 18, color: Colors.amber.shade700)
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}
