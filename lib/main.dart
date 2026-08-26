import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'controllers/login_controller.dart';
import 'services/odoo_client.dart';
import 'services/preferences_service.dart';
import 'views/login_page.dart';
import 'views/update_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final client = OdooClient();
  runApp(
    GuilminApp(
      loginController: LoginController(client, PreferencesService()),
    ),
  );
}

class GuilminApp extends StatelessWidget {
  final LoginController loginController;
  const GuilminApp({super.key, required this.loginController});
  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF12345B);
    const blue = Color(0xFF587CA8);
    const green = Color(0xFF65A56F);
    const page = Color(0xFFF3F6FA);
    const border = Color(0xFFD9E3EF);
    final scheme = const ColorScheme.light(
      primary: blue,
      onPrimary: Colors.white,
      secondary: green,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: navy,
      surfaceContainerHighest: page,
      outline: border,
    );
    return MaterialApp(
      title: 'Guilmin',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'BE'),
      supportedLocales: const <Locale>[
        Locale('fr', 'BE'),
        Locale('fr'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: page,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: navy,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: navy,
            fontSize: 21,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            side: BorderSide(color: border),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF8FAFD),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: border),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
        searchBarTheme: SearchBarThemeData(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          
          elevation: const WidgetStatePropertyAll(0),
          side: const WidgetStatePropertyAll(BorderSide(color: border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: navy,
            side: const BorderSide(color: Color(0xFFAFC0D5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
        dividerColor: border,
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: green),
      ),
      home: UpdateChecker(child: LoginPage(controller: loginController)),
    );
  }
}
