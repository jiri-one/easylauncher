import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onChooseAction,
    required this.onFavorites,
    required this.run,
  });
  final LauncherController controller;
  final VoidCallback onBack;
  final ValueChanged<LaunchAction> onChooseAction;
  final VoidCallback onFavorites;
  final void Function(Future<void> Function()) run;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double? _fontSize;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final settings = controller.settings;
    final editable = controller.settingsAvailable;
    return Column(
      children: [
        AppBar(
          title: const Text('Nastavení'),
          leading: IconButton(
            tooltip: 'Zpět',
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              ListTile(
                title: const Text('Výchozí domovská obrazovka'),
                subtitle: Text(
                  controller.status.isDefault
                      ? 'EasyLauncher je nastavený'
                      : 'Nastavit EasyLauncher',
                ),
                onTap: () =>
                    widget.run(controller.platform.requestDefaultLauncher),
              ),
              ListTile(
                title: const Text('Oznámení tahem dolů'),
                subtitle: Text(
                  controller.status.notificationsEnabled
                      ? 'Povoleno'
                      : 'Povolit EasyLauncher ve zpřístupnění',
                ),
                onTap: () =>
                    widget.run(controller.platform.openAccessibilitySettings),
              ),
              const Divider(),
              ListTile(
                title: const Text('Oblíbené aplikace'),
                subtitle: const Text('Změnit pořadí nebo odebrat dlaždici'),
                trailing: const Icon(Icons.chevron_right),
                enabled: editable,
                onTap: widget.onFavorites,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Počet sloupců'),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.white
                              : Colors.black,
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.black
                              : Colors.white,
                        ),
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        side: const WidgetStatePropertyAll(
                          BorderSide(color: Colors.black),
                        ),
                        animationDuration: Duration.zero,
                      ),
                      segments: const [
                        ButtonSegment(value: 2, label: Text('2')),
                        ButtonSegment(value: 3, label: Text('3')),
                      ],
                      selected: {settings.columns},
                      showSelectedIcon: false,
                      onSelectionChanged: !editable
                          ? null
                          : (value) => controller.update(
                              settings.copyWith(columns: value.single),
                            ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Velikost názvů na dlaždicích'),
                    Slider(
                      min: 18,
                      max: 36,
                      divisions: 9,
                      label: (_fontSize ?? settings.fontSize)
                          .round()
                          .toString(),
                      value: _fontSize ?? settings.fontSize,
                      onChanged: !editable
                          ? null
                          : (value) => setState(() => _fontSize = value),
                      onChangeEnd: (value) {
                        controller.update(
                          controller.settings.copyWith(fontSize: value),
                        );
                        setState(() => _fontSize = null);
                      },
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                title: const Text('Automaticky otevřít klávesnici'),
                subtitle: const Text('Při otevření seznamu aplikací'),
                value: settings.autoKeyboard,
                onChanged: !editable
                    ? null
                    : (value) => controller.update(
                        settings.copyWith(autoKeyboard: value),
                      ),
              ),
              const Divider(),
              for (final action in LaunchAction.values)
                ListTile(
                  enabled: editable,
                  title: Text(action.title),
                  subtitle: Text(
                    settings.actions[action]?.label ?? action.defaultLabel,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.onChooseAction(action),
                ),
              const Divider(),
              if (!editable)
                ListTile(
                  title: const Text('Znovu načíst nastavení'),
                  onTap: controller.reloadSettings,
                ),
              ListTile(
                title: const Text('Obnovit seznam aplikací'),
                onTap: () => widget.run(controller.refresh),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'EasyLauncher 0.1.1',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FavoritesEditor extends StatelessWidget {
  const FavoritesEditor({super.key, required this.controller});
  final LauncherController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Oblíbené')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final favorites = controller.settings.favorites;
          if (favorites.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aplikaci přidáš dlouhým podržením v seznamu aplikací.',
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: favorites.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final app = favorites[index];
              return Padding(
                key: ValueKey(app.id),
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${index + 1}. ${controller.label(app)}'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Posunout nahoru',
                          onPressed: index == 0
                              ? null
                              : () => controller.moveFavorite(index, index - 1),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'Posunout dolů',
                          onPressed: index == favorites.length - 1
                              ? null
                              : () => controller.moveFavorite(index, index + 1),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          tooltip: 'Odebrat z oblíbených',
                          onPressed: () => controller.removeFavorite(app),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
