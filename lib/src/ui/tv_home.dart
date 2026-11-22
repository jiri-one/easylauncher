import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import 'home.dart';

class TvHomeScreen extends StatelessWidget {
  const TvHomeScreen({super.key, required this.controller});

  final LauncherController controller;

  Future<void> _launch(BuildContext context, LaunchTarget app) async {
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
      return Scaffold(
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
                if (controller.error != null)
                  const Text('Nastavení se nepodařilo načíst nebo uložit.'),
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
      );
    },
  );
}
