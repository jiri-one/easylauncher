import 'package:clock/clock.dart';
import 'package:material_ui/material_ui.dart';

import '../controller.dart';
import '../models.dart';
import 'home.dart';

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key, required this.controller});

  final LauncherController controller;

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  // An app needs a moment to show its window; until then a held or repeated Enter must not start it again.
  static const _launchPause = Duration(seconds: 3);
  // Laid out for 720p and scaled to the screen, so the tiles have the same size on a 4K TV at any output scale.
  static const _canvas = Size(1280, 720);
  DateTime? _launchedAt;

  LauncherController get controller => widget.controller;

  Future<void> _launch(BuildContext context, LaunchTarget app) async {
    final now = clock.now();
    final last = _launchedAt;
    if (last != null && now.difference(last) < _launchPause) return;
    _launchedAt = now;
    try {
      await controller.launch(app);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nepodařilo se spustit ${app.label}.')),
        snackBarAnimationStyle: AnimationStyle.noAnimation,
      );
    }
  }

  static final _tileStyle = ButtonStyle(
    animationDuration: Duration.zero,
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.focused) ? Colors.black : Colors.white,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.focused) ? Colors.white : Colors.black,
    ),
    side: const WidgetStatePropertyAll(
      BorderSide(color: Colors.black, width: 2),
    ),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontSize: 42, fontWeight: FontWeight.w600),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final favorites = controller.apps;
      return FittedBox(
        child: SizedBox.fromSize(
          size: _canvas,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const ClockHeader(),
                  const SizedBox(height: 24),
                  if (!controller.ready || favorites.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          !controller.ready
                              ? 'Načítám aplikace…'
                              : 'Zkontroluj seznam oblíbených v easylauncher/apps.json '
                                    'v konfigurační složce a spusť EasyLauncher znovu.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context)
                            .copyWith(scrollbars: false),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisExtent: 140,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: favorites.length,
                          itemBuilder: (context, index) {
                            final app = favorites[index];
                            return TextButton(
                              autofocus: index == 0,
                              style: _tileStyle,
                              onPressed: () => _launch(context, app),
                              child: Text(
                                app.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
