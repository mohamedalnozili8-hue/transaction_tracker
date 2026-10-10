import '../db/database_helper.dart';
import '../models/transaction_model.dart';

/// يحسب متوسط المدة التي استغرقتها كل خطوة (بالعنوان) في المعاملات
/// المكتملة سابقاً من نفس القالب، ليُقدّر متى ستنتهي معاملة نشطة حالياً.
class EstimationService {
  final _db = DatabaseHelper.instance;

  /// يرجع تقدير الوقت المتبقي بالساعات للمعاملة، أو null إن لم تتوفر بيانات كافية
  Future<Duration?> estimateRemaining({
    required String templateId,
    required int currentStepIndex,
    required int totalSteps,
  }) async {
    final archived = await _db.getArchivedTransactions();
    final sameTemplate = archived
        .where((t) =>
            t.templateId == templateId && t.status == TransactionStatus.completed)
        .toList();

    if (sameTemplate.isEmpty) return null;

    // نجمع متوسط الوقت لكل خطوة بالفهرس (order) عبر كل المعاملات المكتملة المشابهة
    final Map<int, List<Duration>> durationsByOrder = {};

    for (final tx in sameTemplate) {
      final steps = await _db.getTransactionSteps(tx.id);
      steps.sort((a, b) => a.order.compareTo(b.order));
      for (final step in steps) {
        if (step.startedAt != null && step.completedAt != null) {
          final d = step.completedAt!.difference(step.startedAt!);
          durationsByOrder.putIfAbsent(step.order, () => []).add(d);
        }
      }
    }

    if (durationsByOrder.isEmpty) return null;

    // نحسب متوسط عام لكل خطوة بغض النظر عن الفهرس (تبسيط فعّال وكافٍ محلياً)
    final allDurations = durationsByOrder.values.expand((e) => e).toList();
    final avgPerStepMs = allDurations
            .map((d) => d.inMilliseconds)
            .reduce((a, b) => a + b) /
        allDurations.length;

    final remainingSteps = totalSteps - currentStepIndex;
    if (remainingSteps <= 0) return Duration.zero;

    return Duration(milliseconds: (avgPerStepMs * remainingSteps).round());
  }

  String formatDuration(Duration d) {
    if (d.inDays >= 1) {
      final days = d.inDays;
      final hours = d.inHours % 24;
      return hours > 0 ? '$days يوم و $hours ساعة' : '$days يوم';
    } else if (d.inHours >= 1) {
      final hours = d.inHours;
      final minutes = d.inMinutes % 60;
      return minutes > 0 ? '$hours ساعة و $minutes دقيقة' : '$hours ساعة';
    } else {
      return '${d.inMinutes} دقيقة';
    }
  }
}
