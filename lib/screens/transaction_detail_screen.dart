import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../db/database_helper.dart';
import '../models/transaction_model.dart';
import '../services/pattern_service.dart';
import '../services/estimation_service.dart';
import '../services/attachment_service.dart';
import '../services/pdf_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _db = DatabaseHelper.instance;
  final _patternService = PatternService();
  final _estimationService = EstimationService();
  final _attachmentService = AttachmentService();
  final _uuid = const Uuid();

  TransactionModel? _transaction;
  List<TransactionStepInstance> _steps = [];
  Duration? _estimatedRemaining;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _db.getActiveTransactions();
    final archived = await _db.getArchivedTransactions();
    final t = [...all, ...archived].firstWhere((x) => x.id == widget.transactionId);
    final steps = await _db.getTransactionSteps(widget.transactionId);

    Duration? estimate;
    if (t.status == TransactionStatus.active) {
      estimate = await _estimationService.estimateRemaining(
        templateId: t.templateId,
        currentStepIndex: t.currentStepIndex,
        totalSteps: steps.length,
      );
    }

    setState(() {
      _transaction = t;
      _steps = steps;
      _estimatedRemaining = estimate;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _transaction == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final t = _transaction!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'تصدير كـ PDF',
            onPressed: _exportPdf,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenu,
            itemBuilder: (context) => [
              if (t.status == TransactionStatus.active)
                const PopupMenuItem(value: 'cancel', child: Text('إلغاء المعاملة')),
              const PopupMenuItem(value: 'delete', child: Text('حذف نهائي')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _buildSummaryCard(t),
          const SizedBox(height: 16),
          if (t.status == TransactionStatus.active) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addExceptionalStep,
                icon: const Icon(Icons.add_alert_outlined),
                label: const Text('إضافة إجراء استثنائي'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Text('مسار المعاملة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          ..._steps.map((s) => _buildStepTile(s)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(TransactionModel t) {
    final dateFormat = DateFormat('yyyy/MM/dd - HH:mm', 'ar');
    final doneCount = _steps.where((s) => s.status == StepStatus.done).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.templateName, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text('بدأت: ${dateFormat.format(t.startedAt)}'),
              ],
            ),
            if (t.completedAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade600),
                  const SizedBox(width: 6),
                  Text('انتهت: ${dateFormat.format(t.completedAt!)}'),
                ],
              ),
            ],
            if (_estimatedRemaining != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.timelapse, size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'الوقت المتوقع للإنجاز: ${_estimationService.formatDuration(_estimatedRemaining!)}',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _steps.isEmpty ? 0 : doneCount / _steps.length,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 4),
            Text('$doneCount من ${_steps.length} خطوات',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTile(TransactionStepInstance step) {
    final isException = step.kind == StepKind.exceptional;
    // قيم ابتدائية افتراضية (StepStatus.pending) حتى يبقى المتغيران معرَّفين
    // دائماً بشكل مؤكد للمترجم، بغض النظر عن تحليل اكتمال الـ switch.
    Color color = Colors.grey;
    IconData icon = Icons.radio_button_unchecked;
    switch (step.status) {
      case StepStatus.done:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case StepStatus.blocked:
        color = Colors.red;
        icon = Icons.error;
        break;
      case StepStatus.inProgress:
        color = Colors.blue;
        icon = Icons.play_circle_fill;
        break;
      case StepStatus.pending:
        color = Colors.grey;
        icon = Icons.radio_button_unchecked;
        break;
    }

    return Card(
      color: isException ? Colors.amber.shade50 : null,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${step.order + 1}. ${step.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isException)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('استثنائية', style: TextStyle(fontSize: 10)),
                  ),
              ],
            ),
            if (step.entity != null && step.entity!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 30, top: 2),
                child: Text(step.entity!, style: TextStyle(color: Colors.grey.shade600)),
              ),
            if (step.note != null && step.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 30, top: 4),
                child: Text('📝 ${step.note}', style: const TextStyle(fontSize: 13)),
              ),
            if (step.referenceNumber != null && step.referenceNumber!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 30, top: 2),
                child: Text('رقم: ${step.referenceNumber}', style: const TextStyle(fontSize: 13)),
              ),
            if (step.blockReason != null && step.blockReason!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 30, top: 4),
                child: Text('⚠️ سبب التعثر: ${step.blockReason}',
                    style: TextStyle(fontSize: 13, color: Colors.red.shade700)),
              ),
            if (step.attachmentPaths.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 30, top: 8),
                child: SizedBox(
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: step.attachmentPaths
                        .map((path) => Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(File(path),
                                    width: 60, height: 60, fit: BoxFit.cover),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            if (step.status == StepStatus.inProgress || step.status == StepStatus.blocked)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openStepActionSheet(step),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('ملاحظة / مرفق'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _completeStep(step),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('تمت'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeStep(TransactionStepInstance step) async {
    final now = DateTime.now();
    final updated = step.copyWith(status: StepStatus.done, completedAt: now);
    await _db.updateTransactionStep(updated);

    final t = _transaction!;
    final nextIndex = t.currentStepIndex + 1;

    if (nextIndex < _steps.length) {
      final nextStep = _steps[nextIndex];
      final started = nextStep.copyWith(status: StepStatus.inProgress, startedAt: now);
      await _db.updateTransactionStep(started);
      await _db.updateTransaction(t.copyWith(currentStepIndex: nextIndex));
    } else {
      await _db.updateTransaction(t.copyWith(
        status: TransactionStatus.completed,
        completedAt: now,
        currentStepIndex: nextIndex,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنجاز جميع خطوات المعاملة 🎉')),
        );
      }
    }
    _load();
  }

  Future<void> _openStepActionSheet(TransactionStepInstance step) async {
    final noteController = TextEditingController(text: step.note ?? '');
    final refController = TextEditingController(text: step.referenceNumber ?? '');
    List<String> attachments = List.from(step.attachmentPaths);
    bool markBlocked = step.status == StepStatus.blocked;
    final blockReasonController = TextEditingController(text: step.blockReason ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'ملاحظة سريعة'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: refController,
                      decoration: const InputDecoration(labelText: 'رقم صادر/وارد'),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text('هذه الخطوة متعثرة حالياً'),
                      value: markBlocked,
                      onChanged: (v) => setModalState(() => markBlocked = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (markBlocked)
                      TextField(
                        controller: blockReasonController,
                        decoration: const InputDecoration(labelText: 'سبب التعثر'),
                        maxLines: 2,
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final path = await _attachmentService.captureFromCamera();
                              if (path != null) {
                                setModalState(() => attachments.add(path));
                              }
                            },
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('كاميرا'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final path = await _attachmentService.pickFromGallery();
                              if (path != null) {
                                setModalState(() => attachments.add(path));
                              }
                            },
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('المعرض'),
                          ),
                        ),
                      ],
                    ),
                    if (attachments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: SizedBox(
                          height: 70,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: attachments
                                .map((path) => Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.file(File(path),
                                                width: 70, height: 70, fit: BoxFit.cover),
                                          ),
                                          Positioned(
                                            top: 0,
                                            left: 0,
                                            child: GestureDetector(
                                              onTap: () => setModalState(
                                                  () => attachments.remove(path)),
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.close,
                                                    size: 16, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final updated = step.copyWith(
                            note: noteController.text.trim(),
                            referenceNumber: refController.text.trim(),
                            attachmentPaths: attachments,
                            status: markBlocked ? StepStatus.blocked : StepStatus.inProgress,
                            blockReason:
                                markBlocked ? blockReasonController.text.trim() : '',
                          );
                          await _db.updateTransactionStep(updated);

                          // تعلّم من حالة التعثر لصالح الأنماط الذكية المستقبلية
                          if (markBlocked && blockReasonController.text.trim().isNotEmpty) {
                            await _patternService.learnFromException(
                              templateId: _transaction!.templateId,
                              exceptionTitle: 'تعثر في: ${step.title}',
                              exceptionEntity: step.entity,
                            );
                          }

                          if (mounted) Navigator.pop(context);
                          _load();
                        },
                        child: const Text('حفظ'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addExceptionalStep() async {
    final titleController = TextEditingController();
    final entityController = TextEditingController();
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة إجراء استثنائي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'عنوان الإجراء'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: entityController,
              decoration: const InputDecoration(labelText: 'الجهة (اختياري)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'سبب الإضافة / التوقف'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة')),
        ],
      ),
    );

    if (result != true || titleController.text.trim().isEmpty) return;

    final newOrder = _steps.length;
    final newStep = TransactionStepInstance(
      id: _uuid.v4(),
      transactionId: widget.transactionId,
      title: titleController.text.trim(),
      entity: entityController.text.trim().isEmpty ? null : entityController.text.trim(),
      order: newOrder,
      kind: StepKind.exceptional,
      status: StepStatus.pending,
      blockReason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
    );
    await _db.insertTransactionStep(newStep);

    // تسجيل هذا الحدث لصالح اكتشاف الأنماط المستقبلي
    await _patternService.learnFromException(
      templateId: _transaction!.templateId,
      exceptionTitle: titleController.text.trim(),
      exceptionEntity: entityController.text.trim().isEmpty
          ? null
          : entityController.text.trim(),
    );

    _load();
  }

  Future<void> _exportPdf() async {
    try {
      // تحميل الخط العربي من assets لضمان عرض النص العربي بشكل صحيح في الـ PDF
      final regularFontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');

      final pdfService = PdfService();
      final file = await pdfService.generateTransactionReport(
        transaction: _transaction!,
        steps: _steps,
        arabicFont: pw.Font.ttf(regularFontData),
        arabicFontBold: pw.Font.ttf(boldFontData),
      );
      await Printing.sharePdf(bytes: await file.readAsBytes(), filename: file.path.split('/').last);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر تصدير PDF: $e')),
        );
      }
    }
  }

  Future<void> _handleMenu(String action) async {
    if (action == 'cancel') {
      await _db.updateTransaction(_transaction!.copyWith(status: TransactionStatus.cancelled));
      if (mounted) Navigator.pop(context);
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد الحذف النهائي'),
          content: const Text('سيتم حذف هذه المعاملة وكل بياناتها نهائياً. هل أنت متأكد؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _db.deleteTransaction(widget.transactionId);
        if (mounted) Navigator.pop(context);
      }
    }
  }
}
