import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  // ضروري قبل أي استخدام لـ DateFormat بصيغة عربية (مثل DateFormat('yyyy/MM/dd', 'ar'))
  // في أي شاشة بالتطبيق، وإلا يرمي التطبيق استثناء عند أول محاولة تنسيق تاريخ.
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  runApp(const TransactionTrackerApp());
}

class TransactionTrackerApp extends StatelessWidget {
  const TransactionTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'متابعة المعاملات',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      // مطلوبة حتى تُترجم نصوص ويدجتس Flutter المدمجة (مثل أزرار التقويم
      // الافتراضية إن استُخدمت لاحقاً) للعربية، ولضمان أن "ar" لغة مدعومة فعلياً
      // بدل أن يتجاهلها Flutter ويرجع للإنجليزية تلقائياً.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar')],
      // دعم اتجاه RTL يتم تلقائياً من Flutter بناءً على اللغة،
      // لكن نضبطه صراحة هنا لضمان ظهور كل الواجهة من اليمين لليسار.
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        fontFamily: 'Cairo',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
