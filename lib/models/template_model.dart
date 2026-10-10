/// نموذج "القالب" أو النوع القياسي للمعاملة
/// مثال: "إصدار ترخيص عبور" وله خطوات ثابتة مرتبة
class TemplateModel {
  final String id; // UUID فريد عالمياً (مهم جداً للدمج بين الأجهزة)
  final String name;
  final String? description;
  final DateTime createdAt;

  TemplateModel({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TemplateModel.fromMap(Map<String, dynamic> map) {
    return TemplateModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  TemplateModel copyWith({String? name, String? description}) {
    return TemplateModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }
}

/// خطوة قياسية ضمن قالب معين (مثلاً: خطوة 1: الشؤون القانونية)
class TemplateStepModel {
  final String id;
  final String templateId;
  final String title;
  final String? entity; // الجهة المسؤولة عن هذه الخطوة
  final int order; // ترتيب الخطوة ضمن القالب

  TemplateStepModel({
    required this.id,
    required this.templateId,
    required this.title,
    this.entity,
    required this.order,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'templateId': templateId,
      'title': title,
      'entity': entity,
      'stepOrder': order,
    };
  }

  factory TemplateStepModel.fromMap(Map<String, dynamic> map) {
    return TemplateStepModel(
      id: map['id'] as String,
      templateId: map['templateId'] as String,
      title: map['title'] as String,
      entity: map['entity'] as String?,
      order: map['stepOrder'] as int,
    );
  }
}
