# تطبيق متابعة المعاملات (Transaction Tracker)

تطبيق Flutter لتتبع المعاملات الإدارية بخطوات قياسية قابلة للتخصيص، مع:
- بنك نماذج (قوالب) وخطوات قياسية
- لوحة معاملات نشطة تفاعلية (بطاقات + زر "تمت")
- إدارة خطوات استثنائية وتوثيق أسباب التعثر
- **اكتشاف أنماط ذكي محلي بالكامل** (بدون إنترنت أو سيرفر): إن تكررت خطوة استثنائية
  مرتين أو أكثر لنفس النموذج، يقترحها التطبيق تلقائياً عند بدء معاملة جديدة من نفس النوع
- أرشيف للمعاملات المكتملة/الملغاة
- تصدير تقرير PDF أنيق لكل معاملة
- **نسخ احتياطي ومشاركة بين الأجهزة**: تصدير كل البيانات (قوالب + معاملات + صور) كملف
  `.zip` واحد يُرسل عبر أي تطبيق مشاركة (واتساب، بلوتوث...)، والاستيراد **يدمج فقط**
  دون حذف أي بيانات محلية
- يعمل بالكامل دون إنترنت (Offline-First) عبر SQLite محلي

---

## ⚠️ ملاحظة مهمة حول هذا التسليم

تم كتابة كل أكواد هذا المشروع يدوياً، في بيئة لا تسمح شبكتها بتحميل محرك
Flutter/Dart الثنائي (الوصول إلى `storage.googleapis.com` محجوب بسياسة ثابتة
في بيئة التنفيذ هذه)، لذلك **لم يكن ممكناً تشغيل `flutter pub get` أو
`flutter build apk` فعلياً هنا ولا رؤية نتيجة محلل Dart الحقيقي**.

لهذا السبب أيضاً لا يحتوي هذا المشروع على مجلد `android/` كامل (ملفات Gradle
وغيرها لا يمكن توليدها يدوياً بأمان)، بل على `android_overlay/` يحتوي فقط
الإعدادات المخصصة (الأذونات، مزوّد الملفات)، تُدمَج تلقائياً فوق مجلد `android/`
الذي يولّده أمر `flutter create` نفسه — إما على خادم GitHub Actions تلقائياً
(الطريقة الموصى بها أدناه)، أو يدوياً على جهازك (الطريقة البديلة).

بدلاً من تجربة بناء كاملة، تمت مراجعة الكود ببديل عملي بنفس الدقة:
- قراءة كل ملف `.dart` بالمشروع سطراً بسطر يدوياً.
- التحقق من كل توقيع دالة من حزمة خارجية (pdf, printing, archive, file_picker,
  share_plus, sqflite, image_picker) من **توثيقها الرسمي على pub.dev** وليس
  من الذاكرة، لتفادي استخدام باراميترات أو أنواع غير موجودة في النسخ الحالية.
- تتبّع أي استدعاء لواجهات Flutter الحساسة للنسخة (مثل `CardThemeData`) للتأكد
  أنها متوافقة مع إصدارات Flutter المستقرة الحالية.

**أخطاء حقيقية تم اكتشافها وتصحيحها فعلياً خلال هذه المراجعة:**

1. **عطل تشغيل مؤكد (crash):** كل الشاشات تستخدم
   `DateFormat('yyyy/MM/dd', 'ar')` لعرض التواريخ بالعربي، لكن حزمة `intl`
   تتطلب تهيئة بيانات اللغة أولاً عبر `initializeDateFormatting('ar')` قبل أي
   استخدام — وإلا يرمي استثناء `LocaleDataException` فوراً عند فتح أي شاشة
   فيها تاريخ. تم إصلاحه في `main.dart` بجعل `main()` دالة `async` تستدعي
   `initializeDateFormatting('ar')` قبل `runApp`.
2. **تعارض نسخ محتمل عند `flutter pub get`:** إضافة `flutter_localizations`
   (ضرورية لدعم العربية في ويدجتس Flutter المدمجة) تفرض نسخة `intl` محددة
   بدقة حسب نسخة Flutter SDK نفسها. كان `pubspec.yaml` يثبّت `intl: ^0.19.0`
   يدوياً، وهذا قد يسبب فشل حل النسخ. تم تغييره إلى `intl: any` ليختار
   Flutter النسخة الصحيحة تلقائياً.
3. **استيراد ناقص:** `flutter/services.dart` (لِـ `rootBundle`) لم يكن
   مستورداً في `transaction_detail_screen.dart` رغم استخدامه لتحميل خط PDF
   العربي. تم إضافته.
4. **تبعية غير مستخدمة:** حزمة `provider` كانت في `pubspec.yaml` دون أي
   استخدام فعلي بالكود (كل الشاشات تستخدم `setState` مباشرة). تمت إزالتها.
5. تنظيف ملف `l10n.yaml` غير المستخدم (لم يُفعَّل `generate: true` ولا توجد
   ملفات `.arb` بالمشروع، فهو بقية من تخطيط أولي لم يُنفَّذ).

**ما تبقى غير مؤكد 100%:** لا بديل عن تشغيل `flutter pub get` و
`flutter analyze` فعلياً على جهازك، لأن بعض الأخطاء (أخطاء كتابية صغيرة،
تضارب أنواع دقيق) لا تظهر إلا للمترجم الحقيقي. اتبع "خطوات الإعداد" أدناه،
وإن ظهر أي خطأ من `flutter analyze` أو `flutter run` أرسل لي نصه وأصلحه معك
فوراً.

---

## 🚀 الطريقة الأسهل: بناء APK تلقائياً عبر GitHub (بدون تثبيت أي شيء)

هذا المشروع يتضمن ملف `.github/workflows/build-apk.yml` جاهز يبني الـ APK
تلقائياً على خوادم GitHub نفسها (مجاني) بمجرد رفع الملفات — بدون الحاجة لتثبيت
Flutter على جهازك، وبدون سطر أوامر واحد.

### الخطوات (من المتصفح فقط):

1. **حمّل خط Cairo أولاً** (مطلوب حتى لا يفشل البناء):
   اذهب إلى https://fonts.google.com/specimen/Cairo ← زر "Download family" ←
   فك ضغط الملف وابحث عن `Cairo-Regular.ttf` و `Cairo-Bold.ttf` (أو أقرب وزن
   Bold متوفر وأعد تسميته لهذا الاسم). احتفظ بهما جانباً.

2. **أنشئ مستودعاً جديداً على GitHub**:
   من صفحتك الرئيسية على github.com ← زر الإضافة (+) أعلى الصفحة ←
   "New repository" ← اختر اسماً (مثلاً `transaction-tracker`) ← اجعله
   **Private** إن أردت الخصوصية ← "Create repository".

3. **ارفع كل ملفات هذا المشروع**:
   بصفحة المستودع الفارغ الجديد، اضغط "uploading an existing file"
   (أو "Add file" ← "Upload files"). فك ضغط `transaction_tracker.zip` على
   جهازك أولاً، ثم اسحب **كل محتويات مجلد `transaction_tracker/`** (وليس
   المجلد نفسه) إلى صفحة الرفع — بما فيها المجلد المخفي `.github` (قد يحتاج
   متصفحك يسمح بسحب المجلدات؛ Chrome وEdge يدعمون هذا).

4. **ضع ملفي الخط بمكانهما الصحيح**:
   تأكد أن `Cairo-Regular.ttf` و `Cairo-Bold.ttf` اللي حمّلتها بالخطوة 1
   موجودين ضمن الرفعة داخل مسار `assets/fonts/` بالضبط (احذف ملف
   `.gitkeep` الموجود هناك إن ظهر كملف منفصل).

5. **اضغط "Commit changes"** بأسفل الصفحة لإتمام الرفع.

6. **راقب البناء**: روح لتبويب **Actions** أعلى صفحة المستودع. راح تشوف
   عملية بناء بدأت تلقائياً (اسمها "Build Android APK"). انتظر حوالي
   5-10 دقائق لين تخلص (دائرة خضراء ✓ تعني نجح، X حمراء تعني فشل —
   لو فشل، افتح السجل وابعت لي نص الخطأ).

7. **نزّل الـ APK الجاهز**: بعد نجاح العملية، اضغط عليها، ثم من أسفل
   الصفحة تحت "Artifacts" حمّل `transaction-tracker-apk` (ملف zip صغير
   يحتوي على الـ APK بداخله). فك ضغطه وثبّت الملف على جوالك.

> ملاحظة: يمكنك أيضاً تشغيل البناء يدوياً في أي وقت من تبويب Actions ←
> اختر "Build Android APK" ← زر "Run workflow"، بدون الحاجة لرفع تعديل جديد.

---

## الطريقة البديلة: البناء المحلي على جهازك (يحتاج تثبيت Flutter)

### 1. تثبيت Flutter SDK
إن لم يكن مثبتاً: https://docs.flutter.dev/get-started/install

### 2. إنشاء هيكلية مشروع Flutter قياسية فارغة، ثم دمج ملفاتنا فيها

```bash
# في مجلد جديد منفصل
flutter create --org com.example transaction_tracker_scaffold

# انسخ محتوى مجلدنا (lib, pubspec.yaml, assets) فوق المشروع الجديد
cp -r transaction_tracker/lib/*  transaction_tracker_scaffold/lib/
cp transaction_tracker/pubspec.yaml transaction_tracker_scaffold/pubspec.yaml
cp -r transaction_tracker/assets transaction_tracker_scaffold/

# ادمج محتوى AndroidManifest.xml يدوياً (الأذونات + queries + provider)
# من: transaction_tracker/android_overlay/app/src/main/AndroidManifest.xml
# إلى: transaction_tracker_scaffold/android/app/src/main/AndroidManifest.xml

# انسخ ملف file_paths.xml
cp transaction_tracker/android_overlay/app/src/main/res/xml/file_paths.xml \
   transaction_tracker_scaffold/android/app/src/main/res/xml/file_paths.xml

# أضف مفاتيح الأذونات من ios/Runner/Info-permissions-snippet.plist
# يدوياً داخل: transaction_tracker_scaffold/ios/Runner/Info.plist
```

### 3. تحميل خط Cairo العربي (مطلوب لعرض النصوص بشكل صحيح في الواجهة وملفات PDF)

1. اذهب إلى: https://fonts.google.com/specimen/Cairo
2. حمّل الخط، وضع الملفين التاليين داخل `assets/fonts/`:
   - `Cairo-Regular.ttf`
   - `Cairo-Bold.ttf`
   (احذف ملف `.gitkeep` الموجود هناك)

### 4. تثبيت الاعتماديات

```bash
cd transaction_tracker_scaffold
flutter pub get
```

### 5. الحد الأدنى لإصدار أندرويد

في `android/app/build.gradle`، تأكد أن:
```gradle
minSdkVersion 21  // أو أعلى (مطلوب لـ sqflite و image_picker)
```

### 6. التشغيل

```bash
flutter run
```

---

## هيكلية المشروع

```
lib/
  models/              # نماذج البيانات (Template, Transaction, Step)
  db/
    database_helper.dart   # كل منطق SQLite + منطق الدمج بين الأجهزة
  services/
    pattern_service.dart      # اكتشاف الأنماط الذكي المحلي
    estimation_service.dart   # تقدير زمن الإنجاز المتبقي
    pdf_service.dart          # توليد تقرير PDF
    backup_service.dart       # تصدير/استيراد/دمج النسخ الاحتياطية
    attachment_service.dart   # التقاط/حفظ صور المرفقات
  screens/
    home_screen.dart                  # التنقل الرئيسي (4 أقسام)
    templates_screen.dart             # بنك النماذج
    template_editor_screen.dart       # إنشاء/تعديل نموذج وخطواته
    start_transaction_screen.dart     # بدء معاملة + الاقتراحات الذكية
    active_transactions_screen.dart   # لوحة المعاملات النشطة
    transaction_detail_screen.dart    # تفاصيل المعاملة الكاملة
    archive_screen.dart               # الأرشيف
    settings_screen.dart              # الإعدادات + النسخ الاحتياطي
```

## آلية اكتشاف الأنماط (بدون أي AI سيرفر)

كل مرة يُضاف فيها "إجراء استثنائي" لمعاملة، يُسجَّل في جدول `pattern_suggestions`
مع عدّاد تكرار لكل تركيبة (نموذج + عنوان الإجراء + الجهة). عند بدء معاملة جديدة
من نفس النموذج، يُستعلَم الجدول عن أي تركيبة تكررت **مرتين فأكثر**، ويُعرض
كاقتراح تفاعلي (موافقة/رفض) قبل إنشاء المعاملة. هذا منطق عدّ وفلترة بسيط
بالكامل داخل SQLite، دون أي استدعاء شبكة.

## آلية الدمج بين الأجهزة

كل الجداول تستخدم معرّفات UUID نصية بدلاً من أرقام تسلسلية، لذلك عند استيراد
قاعدة بيانات من جهاز آخر، يكفي التحقق: "هل هذا الـ id موجود محلياً؟" — إن لم
يكن موجوداً يُضاف، وإلا يُتجاهل. هذا يضمن أن الدمج **لا يحذف ولا يكرر أي شيء**
محلياً مهما تكرر الاستيراد.

## قيود معروفة في هذه النسخة (MVP)

لم تُنفَّذ بعد (مذكورة في المخطط الأصلي كخطوة تالية):
- التذكيرات الزمنية (local notifications)
- تذكيرات الموقع الجغرافي (Geofencing)
- تحسين جودة صور المستندات تلقائياً
- تصدير Excel

## استكشاف أخطاء شائعة عند أول تشغيل

- **"version solving failed" عند `flutter pub get`**: نفّذ
  `flutter pub add intl` بدل التعديل اليدوي، ليختار Flutter نفسه النسخة
  المتوافقة مع `flutter_localizations` في SDK المثبّت لديك.
- **النصوص العربية تظهر كمربعات (□) داخل ملف PDF المصدَّر**: يعني ملفي خط
  Cairo غير موجودين فعلياً داخل `assets/fonts/` (تحقق أنك حذفت `.gitkeep`
  وضعت الملفين الحقيقيين بنفس الاسم المذكور في `pubspec.yaml`).
- **خطأ متعلق بالكاميرا أو المعرض على أندرويد**: تأكد من ضبط
  `minSdkVersion 21` أو أعلى في `android/app/build.gradle`، ومن أن تطبيق
  الكاميرا الحقيقي على الجهاز يملك صلاحية الكتابة.
- **فشل مشاركة ملف النسخة الاحتياطية (.zip) على أندرويد 11+**: راجع أن
  وسم `<queries>` موجود في `AndroidManifest.xml` كما في الملف المرفق هنا؛
  بدونه لا يستطيع `share_plus` اكتشاف تطبيقات المشاركة المتاحة بالجهاز.
