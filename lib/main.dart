import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/controller.dart';
import 'src/platform.dart';
import 'src/ui/launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('cs_CZ');
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    EasyLauncherApp(
      controller: LauncherController(
        platform: AndroidLauncherPlatform(),
        initialProfile: const String.fromEnvironment('INITIAL_PROFILE'),
      ),
    ),
  );
}

class EasyLauncherApp extends StatefulWidget {
  const EasyLauncherApp({super.key, required this.controller});
  final LauncherController controller;

  @override
  State<EasyLauncherApp> createState() => _EasyLauncherAppState();
}

class _EasyLauncherAppState extends State<EasyLauncherApp> {
  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EasyLauncher',
    debugShowCheckedModeBanner: false,
    locale: const Locale('cs', 'CZ'),
    supportedLocales: const [Locale('cs', 'CZ')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Colors.black,
        onPrimary: Colors.white,
        secondary: Colors.black,
        surface: Colors.white,
        onSurface: Colors.black,
        outline: Colors.black,
        surfaceTint: Colors.transparent,
      ),
      scaffoldBackgroundColor: Colors.white,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      dividerColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 19, height: 1.25),
        bodyMedium: TextStyle(fontSize: 17, height: 1.25),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _StillPageTransition(),
          TargetPlatform.iOS: _StillPageTransition(),
        },
      ),
    ),
    home: Launcher(controller: widget.controller),
  );
}

class _StillPageTransition extends PageTransitionsBuilder {
  const _StillPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
