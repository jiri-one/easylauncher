import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/controller.dart';
import 'src/platform.dart';
import 'src/ui/launcher.dart';
import 'src/ui/tv_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('cs_CZ');
  runApp(
    EasyLauncherApp(
      controller: LauncherController(
        platform: defaultTargetPlatform == TargetPlatform.linux
            ? LinuxLauncherPlatform()
            : AndroidLauncherPlatform(),
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
  static final _lightTheme = _theme(false);
  static final _darkTheme = _theme(true);

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
  Widget build(BuildContext context) {
    final linux = defaultTargetPlatform == TargetPlatform.linux;
    return ListenableBuilder(
      listenable: widget.controller,
      child: linux
          ? TvHomeScreen(controller: widget.controller)
          : Launcher(controller: widget.controller),
      builder: (context, home) {
        final theme = widget.controller.settings.darkMode
            ? _darkTheme
            : _lightTheme;
        return MaterialApp(
          title: 'EasyLauncher',
          debugShowCheckedModeBanner: false,
          locale: const Locale('cs', 'CZ'),
          supportedLocales: const [Locale('cs', 'CZ')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: theme,
          themeAnimationDuration: Duration.zero,
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: theme.appBarTheme.systemOverlayStyle!,
            child: child!,
          ),
          home: home,
        );
      },
    );
  }

  static ThemeData _theme(bool dark) {
    final background = dark ? Colors.black : Colors.white;
    final foreground = dark ? Colors.white : Colors.black;
    final icons = dark ? Brightness.light : Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: (dark ? ColorScheme.dark : ColorScheme.light)(
        primary: foreground,
        onPrimary: background,
        secondary: foreground,
        surface: background,
        onSurface: foreground,
        outline: foreground,
        error: foreground,
        onError: background,
        surfaceTint: Colors.transparent,
      ),
      scaffoldBackgroundColor: background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      dividerColor: foreground,
      // On black, dialogs and sheets would have no visible edge.
      dialogTheme: dark
          ? DialogThemeData(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: foreground),
                borderRadius: BorderRadius.circular(28),
              ),
            )
          : null,
      bottomSheetTheme: dark
          ? BottomSheetThemeData(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: foreground),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
            )
          : null,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: background,
          statusBarIconBrightness: icons,
          systemNavigationBarColor: background,
          systemNavigationBarIconBrightness: icons,
        ),
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
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: foreground),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: foreground, width: 2),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _StillPageTransition(),
          TargetPlatform.iOS: _StillPageTransition(),
        },
      ),
    );
  }
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
