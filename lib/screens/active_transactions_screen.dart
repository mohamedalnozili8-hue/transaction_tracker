import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/transaction_model.dart';
import 'transaction_detail_screen.dart';
import 'templates_screen.dart';

class ActiveTransactionsScreen extends StatefulWidget {
  const ActiveTransactionsScreen({super.key});

  @override
  State<ActiveTransactionsScreen> createState() => _ActiveTransactionsScreenState();
}

class _ActiveTransactionsScreenState extends State<ActiveTransactionsScreen> {
  final _db = DatabaseHelper.instance;
  List<_TransactionWithProgress> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final transactions = await _db.getActiveTransactions();
    final items = <_TransactionWithProgress>[];
    for (final t in transactions) {
      final steps = await _db.getTransactionSteps(t.id);
      items.add(_TransactionWithProgress(transaction: t, steps: steps));
    }
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المعاملات النشطة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) => _buildCard(_items[index]),
                  ),
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
            Icon(Icons.dashboard_outlined, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('لا توجد معاملات نشطة حالياً',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('ابدأ معاملة جديدة من قسم "النماذج"',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TemplatesScreen()),
                );
              },
              icon: const Icon(Icons.library_books_outlined),
              label: const Text('اذهب إلى النماذج'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(_TransactionWithProgress item) {
    final t = item.transaction;
    final steps = item.steps;
    final doneCount = steps.where((s) => s.status == StepStatus.done).length;
    final progress = steps.isEmpty ? 0.0 : doneCount / steps.length;

    final currentStep = steps.firstWhere(
      (s) => s.status == StepStatus.inProgress || s.status == StepStatus.blocked,
      orElse: () => steps.isNotEmpty
          ? steps.firstWhere((s) => s.status == StepStatus.pending, orElse: () => steps.last)
          : TransactionStepInstance(
              id: '',
              transactionId: '',
              title: '—',
              order: 0,
              kind: StepKind.standard,
              status: StepStatus.pending),
    );

    final isBlocked = currentStep.status == StepStatus.blocked;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TransactionDetailScreen(transactionId: t.id)),
          );
          _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(t.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  if (isBlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text('متعثرة',
                          style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(t.templateName,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: Colors.grey.shade200,
                  color: isBlocked ? Colors.red : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text('$doneCount من ${steps.length} خطوات مكتملة',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const Divider(height: 20),
              Row(
                children: [
                  Icon(Icons.flag_outlined, size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'الخطوة الحالية: ${currentStep.title}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (currentStep.entity != null && currentStep.entity!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 24),
                  child: Text(currentStep.entity!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'بدأت: ${DateFormat('yyyy/MM/dd', 'ar').format(t.startedAt)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const Spacer(),
                  if (!isBlocked && currentStep.status == StepStatus.inProgress)
                    FilledButton.tonalIcon(
                      onPressed: () => _quickComplete(t, currentStep),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('تمت'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickComplete(
      TransactionModel t, TransactionStepInstance currentStep) async {
    // إتمام سريع من البطاقة مباشرة بدون تفاصيل إضافية؛
    // لإضافة ملاحظة أو مرفق قبل الإتمام، يفتح المستخدم تفاصيل المعاملة.
    final now = DateTime.now();
    final updatedStep = currentStep.copyWith(status: StepStatus.done, completedAt: now);
    await _db.updateTransactionStep(updatedStep);

    final allSteps = await _db.getTransactionSteps(t.id);
    final nextIndex = t.currentStepIndex + 1;

    if (nextIndex < allSteps.length) {
      final nextStep = allSteps[nextIndex];
      final startedNext = nextStep.copyWith(status: StepStatus.inProgress, startedAt: now);
      await _db.updateTransactionStep(startedNext);
      await _db.updateTransaction(t.copyWith(currentStepIndex: nextIndex));
    } else {
      await _db.updateTransaction(t.copyWith(
        status: TransactionStatus.completed,
        completedAt: now,
        currentStepIndex: nextIndex,
      ));
    }
    _load();
  }
}

class _TransactionWithProgress {
  final TransactionModel transaction;
  final List<TransactionStepInstance> steps;
  _TransactionWithProgress({required this.transaction, required this.steps});
}
