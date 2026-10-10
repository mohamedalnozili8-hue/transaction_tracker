enum TransactionStatus { active, completed, cancelled }

TransactionStatus statusFromString(String s) {
  switch (s) {
    case 'completed':
      return TransactionStatus.completed;
    case 'cancelled':
      return TransactionStatus.cancelled;
    default:
      return TransactionStatus.active;
  }
}

String statusToString(TransactionStatus s) {
  switch (s) {
    case TransactionStatus.completed:
      return 'completed';
    case TransactionStatus.cancelled:
      return 'cancelled';
    case TransactionStatus.active:
      return 'active';
  }
}

/// معاملة فعلية بدأها المستخدم بناءً على قالب
class TransactionModel {
  final String id;
  final String templateId;
  final String templateName; // نسخة من الاسم وقت الإنشاء (حتى لو تغيّر القالب لاحقاً)
  final String title; // اسم مخصص للمعاملة (مثلاً: ترخيص عبور - شركة الفجر)
  final DateTime startedAt;
  final DateTime? completedAt;
  final TransactionStatus status;
  final int currentStepIndex; // فهرس الخطوة الحالية ضمن قائمة خطوات المعاملة

  TransactionModel({
    required this.id,
    required this.templateId,
    required this.templateName,
    required this.title,
    required this.startedAt,
    this.completedAt,
    required this.status,
    required this.currentStepIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'templateId': templateId,
      'templateName': templateName,
      'title': title,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'status': statusToString(status),
      'currentStepIndex': currentStepIndex,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      templateId: map['templateId'] as String,
      templateName: map['templateName'] as String,
      title: map['title'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
      status: statusFromString(map['status'] as String),
      currentStepIndex: map['currentStepIndex'] as int,
    );
  }

  TransactionModel copyWith({
    DateTime? completedAt,
    TransactionStatus? status,
    int? currentStepIndex,
  }) {
    return TransactionModel(
      id: id,
      templateId: templateId,
      templateName: templateName,
      title: title,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
    );
  }
}

enum StepKind { standard, exceptional }

StepKind stepKindFromString(String s) =>
    s == 'exceptional' ? StepKind.exceptional : StepKind.standard;

String stepKindToString(StepKind k) =>
    k == StepKind.exceptional ? 'exceptional' : 'standard';

enum StepStatus { pending, inProgress, done, blocked }

StepStatus stepStatusFromString(String s) {
  switch (s) {
    case 'inProgress':
      return StepStatus.inProgress;
    case 'done':
      return StepStatus.done;
    case 'blocked':
      return StepStatus.blocked;
    default:
      return StepStatus.pending;
  }
}

String stepStatusToString(StepStatus s) {
  switch (s) {
    case StepStatus.inProgress:
      return 'inProgress';
    case StepStatus.done:
      return 'done';
    case StepStatus.blocked:
      return 'blocked';
    case StepStatus.pending:
      return 'pending';
  }
}

/// خطوة فعلية داخل معاملة (سواء قياسية منسوخة من القالب أو استثنائية أُضيفت لاحقاً)
class TransactionStepInstance {
  final String id;
  final String transactionId;
  final String title;
  final String? entity;
  final int order;
  final StepKind kind;
  final StepStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? note; // ملاحظة لحظية
  final String? referenceNumber; // رقم صادر/وارد
  final String? blockReason; // سبب التوقف/العرقلة (للذكاء الاصطناعي المحلي)
  final List<String> attachmentPaths; // مسارات الصور المرفقة محلياً

  TransactionStepInstance({
    required this.id,
    required this.transactionId,
    required this.title,
    this.entity,
    required this.order,
    required this.kind,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.note,
    this.referenceNumber,
    this.blockReason,
    this.attachmentPaths = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'title': title,
      'entity': entity,
      'stepOrder': order,
      'kind': stepKindToString(kind),
      'status': stepStatusToString(status),
      'startedAt': startedAt?.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'note': note,
      'referenceNumber': referenceNumber,
      'blockReason': blockReason,
      'attachmentPaths': attachmentPaths.join('|'),
    };
  }

  factory TransactionStepInstance.fromMap(Map<String, dynamic> map) {
    final rawPaths = map['attachmentPaths'] as String?;
    return TransactionStepInstance(
      id: map['id'] as String,
      transactionId: map['transactionId'] as String,
      title: map['title'] as String,
      entity: map['entity'] as String?,
      order: map['stepOrder'] as int,
      kind: stepKindFromString(map['kind'] as String),
      status: stepStatusFromString(map['status'] as String),
      startedAt: map['startedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int)
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
      note: map['note'] as String?,
      referenceNumber: map['referenceNumber'] as String?,
      blockReason: map['blockReason'] as String?,
      attachmentPaths:
          (rawPaths == null || rawPaths.isEmpty) ? [] : rawPaths.split('|'),
    );
  }

  TransactionStepInstance copyWith({
    StepStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    String? note,
    String? referenceNumber,
    String? blockReason,
    List<String>? attachmentPaths,
  }) {
    return TransactionStepInstance(
      id: id,
      transactionId: transactionId,
      title: title,
      entity: entity,
      order: order,
      kind: kind,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      note: note ?? this.note,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      blockReason: blockReason ?? this.blockReason,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
    );
  }
}
