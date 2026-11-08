import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller.dart';
import '../models.dart';
import 'apps.dart';
import 'home.dart';
import 'settings.dart';

enum _Screen { home, apps, settings }

class Launcher extends StatefulWidget {
  const Launcher({super.key, required this.controller});
  final LauncherController controller;

  @override
  State<Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<Launcher> with WidgetsBindingObserver {
  _Screen _screen = _Screen.home;
  StreamSubscription<String>? _events;
  DateTime? _lastLaunch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events = widget.controller.platform.events.listen((event) {
      if (event == 'home' && mounted) _home();
    }, onError: (_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.controller.ready) {
      widget.controller.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    super.dispose();
  }

  void _home() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _screen = _Screen.home);
  }

  void _show(_Screen screen) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _screen = screen);
  }

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
    } on PlatformException catch (_) {
      _message(
        'Akci se nepodařilo otevřít. Zkontroluj vybranou aplikaci v nastavení.',
      );
    } catch (_) {
      _message('Akci se nepodařilo dokončit. Zkus ji znovu.');
    }
  }

  void _message(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        action: action,
        duration: const Duration(seconds: 6),
      ),
      snackBarAnimationStyle: AnimationStyle.noAnimation,
    );
  }

  void _launch(LaunchTarget app) {
    final now = DateTime.now();
    if (_lastLaunch != null &&
        now.difference(_lastLaunch!) < const Duration(milliseconds: 600)) {
      return;
    }
    _lastLaunch = now;
    FocusManager.instance.primaryFocus?.unfocus();
    _run(() async {
      await widget.controller.launch(app);
      if (mounted) _home();
    });
  }

  void _notifications() => _run(() async {
    if (!await widget.controller.platform.openNotifications() && mounted) {
      _message(
        'Pro otevření oznámení povol EasyLauncher ve zpřístupnění.',
        action: SnackBarAction(
          label: 'Povolit',
          onPressed: () =>
              _run(widget.controller.platform.openAccessibilitySettings),
        ),
      );
    }
  });

  Future<void> _rename(LaunchTarget app) async {
    final text = TextEditingController(text: widget.controller.label(app));
    final name = await showDialog<String>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Název aplikace'),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: 80,
          minLines: 1,
          maxLines: 3,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: 'Zobrazovaný název',
            helperText: 'Enter vloží nový řádek',
            helperMaxLines: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, text.text),
            child: const Text('Uložit'),
          ),
        ],
      ),
    );
    text.dispose();
    if (name != null) await widget.controller.rename(app, name);
  }

  Future<void> _menu(LaunchTarget app) async {
    final controller = widget.controller;
    final favorite = controller.settings.favorites
        .where(
          (entry) =>
              (controller.resolve(entry)?.id ?? entry.id) ==
              (controller.resolve(app)?.id ?? app.id),
        )
        .firstOrNull;
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      sheetAnimationStyle: AnimationStyle.noAnimation,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    controller.label(app),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ListTile(
                  enabled: controller.settingsAvailable,
                  title: Text(
                    favorite == null
                        ? 'Přidat k oblíbeným'
                        : 'Odebrat z oblíbených',
                  ),
                  onTap: () => Navigator.pop(context, 'favorite'),
                ),
                ListTile(
                  enabled: controller.settingsAvailable,
                  title: const Text('Přejmenovat'),
                  onTap: () => Navigator.pop(context, 'rename'),
                ),
                if (favorite != null)
                  ListTile(
                    enabled: controller.settingsAvailable,
                    title: const Text('Změnit pořadí'),
                    onTap: () => Navigator.pop(context, 'order'),
                  ),
                ListTile(
                  title: const Text('Informace o aplikaci'),
                  onTap: () => Navigator.pop(context, 'details'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (selected) {
      case 'favorite':
        if (favorite == null) {
          await controller.addFavorite(app);
          _message('Přidáno k oblíbeným.');
        } else {
          await controller.removeFavorite(favorite);
        }
      case 'rename':
        await _rename(app);
      case 'order':
        _favorites();
      case 'details':
        await _run(() => controller.platform.openAppDetails(app.packageName));
    }
  }

  void _favorites() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FavoritesEditor(controller: widget.controller),
    ),
  );

  void _chooseAction(LaunchAction action) {
    final controller = widget.controller;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => AppsScreen(
                controller: controller,
                title: action.title,
                includeFavorites: true,
                autoKeyboard: false,
                header: ListTile(
                  title: Text(action.defaultLabel),
                  leading: const Icon(Icons.restore),
                  onTap: () {
                    controller.setAction(action, null);
                    Navigator.pop(context);
                  },
                ),
                onLaunch: (app) {
                  controller.setAction(action, app);
                  Navigator.pop(context);
                },
                onMenu: (_) {},
                onBack: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _home();
    },
    child: Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final controller = widget.controller;
            if (!controller.ready) {
              return const Center(child: Text('Načítám aplikace…'));
            }
            return Column(
              children: [
                if (controller.error != null)
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(controller.error!),
                        ),
                      ),
                      IconButton(
                        tooltip: controller.settingsAvailable
                            ? 'Zavřít upozornění'
                            : 'Znovu načíst nastavení',
                        onPressed: controller.settingsAvailable
                            ? controller.dismissError
                            : controller.reloadSettings,
                        icon: Icon(
                          controller.settingsAvailable
                              ? Icons.close
                              : Icons.refresh,
                        ),
                      ),
                    ],
                  ),
                Expanded(
                  child: switch (_screen) {
                    _Screen.home => HomeScreen(
                      controller: controller,
                      onApps: () => _show(_Screen.apps),
                      onSettings: () => _show(_Screen.settings),
                      onLaunch: _launch,
                      onMenu: _menu,
                      onAction: (action) =>
                          _run(() => controller.perform(action)),
                      onNotifications: _notifications,
                    ),
                    _Screen.apps => AppsScreen(
                      controller: controller,
                      onLaunch: _launch,
                      onMenu: _menu,
                      onBack: _home,
                    ),
                    _Screen.settings => SettingsScreen(
                      controller: controller,
                      onBack: _home,
                      onChooseAction: _chooseAction,
                      onFavorites: _favorites,
                      run: _run,
                    ),
                  },
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
