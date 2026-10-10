import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction_model.dart';

/// يولّد تقرير PDF أنيق لمعاملة مكتملة (أو حتى نشطة) يحتوي على:
/// اسم المعاملة، تاريخ البداية/النهاية، التسلسل الزمني للخطوات، والملاحظات.
///
/// ملاحظة هامة حول الخطوط العربية:
/// حزمة pdf الافتراضية لا تدعم الخط العربي من دون تحميل ملف خط يدعم العربية
/// (مثل Amiri أو Cairo أو NotoNaskhArabic) ووضعه في مجلد assets.
/// يجب إضافة ملف الخط (.ttf) إلى مجلد assets/fonts وربطه في pubspec.yaml
/// حتى تظهر النصوص العربية بشكل صحيح داخل ملف الـ PDF الناتج.
class PdfService {
  Future<File> generateTransactionReport({
    required TransactionModel transaction,
    required List<TransactionStepInstance> steps,
    required pw.Font arabicFont,
    required pw.Font arabicFontBold,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('yyyy/MM/dd - HH:mm', 'ar');

    final baseTextStyle = pw.TextStyle(font: arabicFont, fontSize: 11);
    final boldTextStyle =
        pw.TextStyle(font: arabicFontBold, fontSize: 14, color: PdfColors.blue900);
    final titleStyle =
        pw.TextStyle(font: arabicFontBold, fontSize: 20, color: PdfColors.blue900);

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.grey400)),
          ),
          child: pw.Text('تقرير المعاملة', style: titleStyle),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'صفحة ${context.pageNumber} من ${context.pagesCount}',
            style: pw.TextStyle(font: arabicFont, fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          // بيانات المعاملة الأساسية
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(transaction.title, style: boldTextStyle),
                pw.SizedBox(height: 6),
                _infoRow('نوع المعاملة', transaction.templateName, baseTextStyle),
                _infoRow('تاريخ البدء', dateFormat.format(transaction.startedAt),
                    baseTextStyle),
                if (transaction.completedAt != null)
                  _infoRow('تاريخ الانتهاء',
                      dateFormat.format(transaction.completedAt!), baseTextStyle),
                _infoRow(
                    'الحالة',
                    transaction.status == TransactionStatus.completed
                        ? 'مكتملة'
                        : transaction.status == TransactionStatus.cancelled
                            ? 'ملغاة'
                            : 'نشطة',
                    baseTextStyle),
                if (transaction.completedAt != null)
                  _infoRow(
                    'المدة الإجمالية',
                    _formatTotalDuration(
                        transaction.completedAt!.difference(transaction.startedAt)),
                    baseTextStyle,
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          pw.Text('التسلسل الزمني للخطوات', style: boldTextStyle),
          pw.SizedBox(height: 10),

          ...steps.map((step) => _buildStepCard(step, baseTextStyle, arabicFontBold, dateFormat)),
        ],
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final safeTitle = transaction.title.replaceAll(RegExp(r'[^\w\u0600-\u06FF ]'), '_');
    final file = File('${outputDir.path}/تقرير_$safeTitle.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  pw.Widget _infoRow(String label, String value, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(value, style: style),
          pw.Text('$label:', style: style.copyWith(color: PdfColors.grey700)),
        ],
      ),
    );
  }

  pw.Widget _buildStepCard(TransactionStepInstance step, pw.TextStyle baseStyle,
      pw.Font boldFont, DateFormat dateFormat) {
    final isException = step.kind == StepKind.exceptional;
    final statusColor = step.status == StepStatus.done
        ? PdfColors.green700
        : step.status == StepStatus.blocked
            ? PdfColors.red700
            : PdfColors.orange700;

    final statusText = step.status == StepStatus.done
        ? 'تمت'
        : step.status == StepStatus.blocked
            ? 'متعثرة'
            : step.status == StepStatus.inProgress
                ? 'جارية'
                : 'قيد الانتظار';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
            color: isException ? PdfColors.orange300 : PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
        color: isException ? PdfColors.orange50 : PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(statusText,
                    style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.white)),
              ),
              pw.Text(
                '${step.order + 1}. ${step.title}${isException ? " (استثنائية)" : ""}',
                style: pw.TextStyle(font: boldFont, fontSize: 12),
              ),
            ],
          ),
          if (step.entity != null && step.entity!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text('الجهة: ${step.entity}', style: baseStyle),
            ),
          if (step.referenceNumber != null && step.referenceNumber!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text('رقم صادر/وارد: ${step.referenceNumber}', style: baseStyle),
            ),
          if (step.completedAt != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child:
                  pw.Text('تاريخ الإنجاز: ${dateFormat.format(step.completedAt!)}', style: baseStyle),
            ),
          if (step.note != null && step.note!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text('ملاحظة: ${step.note}', style: baseStyle),
            ),
          if (step.blockReason != null && step.blockReason!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text('سبب التعثر: ${step.blockReason}',
                  style: baseStyle.copyWith(color: PdfColors.red700)),
            ),
        ],
      ),
    );
  }

  String _formatTotalDuration(Duration d) {
    if (d.inDays >= 1) {
      return '${d.inDays} يوم و ${d.inHours % 24} ساعة';
    }
    return '${d.inHours} ساعة و ${d.inMinutes % 60} دقيقة';
  }
}
