import '../db/database_helper.dart';

/// منطق "التعلّم المحلي" البسيط: لا يستخدم أي سيرفر أو نموذج ذكاء اصطناعي خارجي،
/// فقط عدّ تكرار الخطوات الاستثنائية داخل SQLite ومقارنتها بعتبة (threshold).
class PatternService {
  final _db = DatabaseHelper.instance;

  /// يُستدعى كل مرة يضيف فيها المستخدم خطوة استثنائية يدوياً لمعاملة،
  /// حتى يتعلم النظام من هذا التكرار مستقبلاً.
  Future<void> learnFromException({
    required String templateId,
    required String exceptionTitle,
    String? exceptionEntity,
  }) async {
    await _db.recordExceptionOccurrence(
      templateId: templateId,
      exceptionTitle: exceptionTitle,
      exceptionEntity: exceptionEntity,
    );
  }

  /// يُستدعى عند بدء معاملة جديدة من قالب معين؛ يرجع قائمة الاقتراحات
  /// (خطوات استثنائية تكررت مرتين فأكثر في معاملات سابقة من نفس القالب).
  Future<List<PatternSuggestion>> getSuggestions(String templateId) async {
    final rows = await _db.getSuggestionsForTemplate(templateId);
    return rows
        .map((r) => PatternSuggestion(
              id: r['id'] as String,
              templateId: r['templateId'] as String,
              exceptionTitle: r['exceptionTitle'] as String,
              exceptionEntity: r['exceptionEntity'] as String?,
              occurrenceCount: r['occurrenceCount'] as int,
            ))
        .toList();
  }

  Future<void> dismissSuggestion(String suggestionId) async {
    await _db.dismissSuggestion(suggestionId);
  }
}

class PatternSuggestion {
  final String id;
  final String templateId;
  final String exceptionTitle;
  final String? exceptionEntity;
  final int occurrenceCount;

  PatternSuggestion({
    required this.id,
    required this.templateId,
    required this.exceptionTitle,
    this.exceptionEntity,
    required this.occurrenceCount,
  });

  /// نص التنبيه الذكي الجاهز للعرض للمستخدم
  String get promptText {
    final entityPart = exceptionEntity != null && exceptionEntity!.isNotEmpty
        ? ' عند جهة "$exceptionEntity"'
        : '';
    return 'لاحظنا في آخر $occurrenceCount معاملات من هذا النوع أنه تم طلب '
        'إجراء "$exceptionTitle"$entityPart. '
        'هل تريد إضافة هذه الخطوة تلقائياً في مسار هذه المعاملة؟';
  }
}
