import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'platform.dart';

class LauncherController extends ChangeNotifier {
  LauncherController({required this.platform, this.initialProfile = ''});

  final LauncherPlatform platform;
  final String initialProfile;
  LauncherSettings settings = LauncherSettings();
  List<LaunchTarget> apps = [];
  LauncherStatus status = const LauncherStatus();
  String? get error => _settingsError ?? _appListError;
  bool ready = false;
  bool settingsAvailable = false;
  String? _settingsError;
  String? _appListError;
  bool _disposed = false;
  Future<void> _saving = Future.value();
  StreamSubscription<String>? _events;
  Timer? _refreshTimer;
  int _refreshVersion = 0;
  LauncherSettings? _indexedSettings;
  List<LaunchTarget>? _indexedApps;
  List<_IndexedApp> _appIndex = [];
  List<LaunchTarget> _allApps = [];
  List<LaunchTarget> _otherApps = [];
  final _appIcons = <String, Future<Uint8List?>>{};
  final _appIconBytes = <String, Uint8List?>{};

  Future<void> initialize() async {
    await reloadSettings();
    await refresh();
    if (_disposed) return;
    ready = true;
    _events = platform.events.listen((event) {
      // An updated app may bring a new icon, and a reinstalled one may have one again.
      if (event == 'appsChanged') {
        _appIcons.clear();
        _appIconBytes.clear();
      }
      if (event == 'appsChanged' || event == 'resume') {
        _refreshTimer?.cancel();
        _refreshTimer = Timer(const Duration(milliseconds: 200), refresh);
      }
    }, onError: (_) {});
    _notify();
  }

  Future<void> reloadSettings() async {
    try {
      final saved = await platform.loadSettings();
      final source = saved ?? initialProfile;
      final loaded = source.isEmpty
          ? LauncherSettings()
          : LauncherSettings.decode(source);
      if (_disposed) return;
      settings = loaded;
      settingsAvailable = true;
      _settingsError = null;
      final migrated = _reconcileAliases();
      if (saved == null || migrated) await _persist();
    } catch (_) {
      settingsAvailable = false;
      _settingsError =
          'Nastavení se nepodařilo načíst. Původní data zůstávají uložená. Zkus načtení znovu.';
    }
    _notify();
  }

  Future<void> refresh() async {
    final version = ++_refreshVersion;
    final List<LaunchTarget> fetched;
    try {
      fetched = await platform.getApps();
    } catch (_) {
      if (_disposed || version != _refreshVersion) return;
      _appListError =
          'Seznam aplikací se nepodařilo načíst. Zkus jej obnovit v nastavení.';
      _notify();
      return;
    }
    if (_disposed || version != _refreshVersion) return;
    LauncherStatus? currentStatus;
    try {
      currentStatus = await platform.getStatus();
    } catch (_) {}
    if (_disposed || version != _refreshVersion) return;
    apps = List.unmodifiable(fetched);
    status = currentStatus ?? status;
    _appListError = null;
    if (settingsAvailable && _reconcileAliases()) await _persist();
    _notify();
  }

  bool _reconcileAliases() {
    var changed = false;
    final ids = apps.map((app) => app.id).toSet();
    final byPackage = <String, List<LaunchTarget>>{};
    for (final app in apps) {
      byPackage.putIfAbsent(app.packageName, () => []).add(app);
    }
    final labels = {...settings.labels};
    for (final entry in settings.labels.entries) {
      if (ids.contains(entry.key)) continue;
      final candidates = byPackage[entry.key.split('/').first];
      if (candidates == null || candidates.length != 1) continue;
      final id = candidates.single.id;
      labels.putIfAbsent(id, () => entry.value);
      labels.remove(entry.key);
      changed = true;
    }
    LaunchTarget migrate(LaunchTarget target) {
      final installed = resolve(target);
      if (installed == null || installed.id == target.id) return target;
      changed = true;
      return installed.renamed(labels[installed.id] ?? target.label);
    }

    final seen = <String>{};
    // Two aliases of one package can migrate to the same activity.
    final favorites = [
      for (final favorite in settings.favorites.map(migrate))
        if (seen.add(favorite.id)) favorite,
    ];
    final actions = {
      for (final entry in settings.actions.entries)
        entry.key: migrate(entry.value),
    };
    if (changed) {
      settings = settings.copyWith(
        favorites: favorites,
        actions: actions,
        labels: labels,
      );
    }
    return changed;
  }

  LaunchTarget? resolve(LaunchTarget target) {
    for (final app in apps) {
      if (app.id == target.id) return app;
    }
    final candidates = apps.where(
      (app) => app.packageName == target.packageName,
    );
    return candidates.length == 1 ? candidates.first : null;
  }

  bool isFavorite(LaunchTarget app) => settings.favorites.any(
    (favorite) => (resolve(favorite)?.id ?? favorite.id) == app.id,
  );

  String label(LaunchTarget app) {
    final renamed = settings.labels[app.id];
    if (renamed != null) return renamed;
    for (final favorite in settings.favorites) {
      if ((resolve(favorite)?.id ?? favorite.id) == app.id) {
        return settings.labels[favorite.id] ?? favorite.label;
      }
    }
    return app.label;
  }

  List<LaunchTarget> visibleApps({
    String query = '',
    bool includeFavorites = false,
  }) {
    _indexApps();
    final search = normalizeSearch(query);
    if (search.isEmpty) return includeFavorites ? _allApps : _otherApps;
    return [
      for (final entry in _appIndex)
        if ((includeFavorites || !entry.favorite) &&
            (entry.searchLabel.contains(search) ||
                entry.originalLabel.contains(search)))
          entry.app,
    ];
  }

  void _indexApps() {
    if (identical(settings, _indexedSettings) &&
        identical(apps, _indexedApps)) {
      return;
    }
    final favoriteLabels = <String, String>{};
    for (final favorite in settings.favorites) {
      final id = resolve(favorite)?.id ?? favorite.id;
      favoriteLabels.putIfAbsent(
        id,
        () => settings.labels[favorite.id] ?? favorite.label,
      );
    }
    final entries = [
      for (final app in apps)
        _IndexedApp(
          app: app,
          label: settings.labels[app.id] ?? favoriteLabels[app.id] ?? app.label,
          favorite: favoriteLabels.containsKey(app.id),
        ),
    ];
    entries.sort((a, b) {
      final order = a.order.compareTo(b.order);
      return order == 0 ? a.app.id.compareTo(b.app.id) : order;
    });
    _appIndex = entries;
    _allApps = List.unmodifiable(entries.map((entry) => entry.app));
    _otherApps = List.unmodifiable(
      entries.where((entry) => !entry.favorite).map((entry) => entry.app),
    );
    _indexedSettings = settings;
    _indexedApps = apps;
  }

  Future<void> update(LauncherSettings updated) async {
    if (!settingsAvailable) return;
    settings = updated;
    _notify();
    await _persist();
  }

  Future<void> _persist() {
    if (!settingsAvailable) return Future.value();
    final snapshot = settings.encode();
    _saving = _saving.then((_) => platform.saveSettings(snapshot)).catchError((
      Object _,
    ) {
      if (_disposed) return;
      _settingsError = 'Změnu se nepodařilo uložit. Zkus ji provést znovu.';
      _notify();
    });
    return _saving;
  }

  Future<void> addFavorite(LaunchTarget app) async {
    if (isFavorite(app)) return;
    await update(
      settings.copyWith(
        favorites: [...settings.favorites, app.renamed(label(app))],
      ),
    );
  }

  Future<void> removeFavorite(LaunchTarget app) => update(
    settings.copyWith(
      favorites: settings.favorites.where(
        (favorite) =>
            (resolve(favorite)?.id ?? favorite.id) !=
            (resolve(app)?.id ?? app.id),
      ),
    ),
  );

  Future<void> rename(LaunchTarget target, String name) {
    final app = resolve(target) ?? target;
    final value = name.trim().isEmpty ? app.label : name.trim();
    final labels = {...settings.labels, target.id: value, app.id: value};
    return update(
      settings.copyWith(
        labels: labels,
        favorites: settings.favorites.map(
          (favorite) => (resolve(favorite)?.id ?? favorite.id) == app.id
              ? favorite.renamed(value)
              : favorite,
        ),
      ),
    );
  }

  Future<void> moveFavorite(int from, int to) {
    if (from < 0 ||
        to < 0 ||
        from >= settings.favorites.length ||
        to >= settings.favorites.length ||
        from == to) {
      return Future.value();
    }
    final favorites = [...settings.favorites];
    final app = favorites.removeAt(from);
    favorites.insert(to, app);
    return update(settings.copyWith(favorites: favorites));
  }

  Future<void> setAction(LaunchAction action, LaunchTarget? app) {
    final actions = {...settings.actions};
    if (app == null) {
      actions.remove(action);
    } else {
      actions[action] = app.renamed(label(app));
    }
    return update(settings.copyWith(actions: actions));
  }

  Future<void> launch(LaunchTarget target) =>
      platform.launchApp(resolve(target) ?? target);

  Future<Uint8List?> appIcon(LaunchTarget app) => _appIcons.putIfAbsent(
    app.id,
    () =>
        platform.getAppIcon(app).then((bytes) => _appIconBytes[app.id] = bytes),
  );

  // Lets a rebuilt tile paint a loaded icon in its first frame instead of one frame later.
  Uint8List? loadedAppIcon(LaunchTarget app) => _appIconBytes[app.id];

  Future<void> perform(LaunchAction action) {
    final target = settings.actions[action];
    return target == null ? platform.openAction(action) : launch(target);
  }

  void dismissError() {
    if (!settingsAvailable) return;
    if (_settingsError != null) {
      _settingsError = null;
    } else {
      _appListError = null;
    }
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    _indexApps();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _events?.cancel();
    super.dispose();
  }
}

class _IndexedApp {
  _IndexedApp({
    required this.app,
    required String label,
    required this.favorite,
  }) : order = LabelSortKey(label),
       searchLabel = normalizeSearch(label),
       originalLabel = normalizeSearch(app.label);

  final LaunchTarget app;
  final LabelSortKey order;
  final String searchLabel;
  final String originalLabel;
  final bool favorite;
}
