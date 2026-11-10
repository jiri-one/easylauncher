import 'dart:convert';

class LaunchTarget {
  const LaunchTarget({
    required this.packageName,
    required this.activityName,
    required this.label,
  });

  factory LaunchTarget.fromJson(Map<String, dynamic> json) {
    final package = json['packageName'];
    final activity = json['activityName'];
    final label = json['label'];
    if (package is! String ||
        !RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$')
            .hasMatch(package) ||
        activity is! String ||
        !RegExp(r'^\.?[a-zA-Z0-9_.$]+$').hasMatch(activity) ||
        label is! String ||
        label.trim().isEmpty) {
      throw const FormatException('Neplatný záznam aplikace.');
    }
    return LaunchTarget(
      packageName: package,
      activityName: activity.startsWith('.') ? '$package$activity' : activity,
      label: label.trim(),
    );
  }

  final String packageName;
  final String activityName;
  final String label;

  String get id => '$packageName/$activityName';

  LaunchTarget renamed(String name) => LaunchTarget(
    packageName: packageName,
    activityName: activityName,
    label: name,
  );

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'activityName': activityName,
    'label': label,
  };
}

enum LaunchAction {
  clock('Hodiny', 'openAlarms'),
  date('Datum', 'openCalendar'),
  right('Tažení doprava', 'openContacts'),
  left('Tažení doleva', 'openCamera');

  const LaunchAction(this.title, this.method);
  final String title;
  final String method;

  String get jsonKey => switch (this) {
    clock => 'clockTap',
    date => 'dateTap',
    right => 'swipeRight',
    left => 'swipeLeft',
  };

  String get defaultLabel => switch (this) {
    clock => 'Systémový budík',
    date => 'Výchozí kalendář',
    right => 'Výchozí kontakty',
    left => 'Výchozí fotoaparát',
  };
}

class LauncherSettings {
  LauncherSettings({
    Iterable<LaunchTarget> favorites = const [],
    this.columns = 2,
    this.autoKeyboard = true,
    this.fontSize = 28,
    Map<LaunchAction, LaunchTarget> actions = const {},
    Map<String, String> labels = const {},
  }) : favorites = List.unmodifiable(favorites),
       actions = Map.unmodifiable(actions),
       labels = Map.unmodifiable(labels);

  factory LauncherSettings.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
      throw const FormatException('Nepodporovaný formát nastavení.');
    }
    final favorites = decoded['favorites'];
    final layout = decoded['layout'] ?? <String, dynamic>{};
    final actions = decoded['actions'] ?? <String, dynamic>{};
    final labels = decoded['labels'] ?? <String, dynamic>{};
    if (favorites is! List ||
        layout is! Map<String, dynamic> ||
        actions is! Map<String, dynamic> ||
        labels is! Map<String, dynamic>) {
      throw const FormatException('Neplatné nastavení.');
    }
    final columns = layout['favoriteColumns'] ?? 2;
    final keyboard = decoded['autoKeyboard'] ?? true;
    final font = layout['fontSize'] ?? 28;
    if ((columns != 2 && columns != 3) ||
        columns is! int ||
        keyboard is! bool ||
        font is! num ||
        !font.isFinite ||
        font < 18 ||
        font > 36) {
      throw const FormatException('Neplatné rozložení.');
    }
    final apps = <LaunchTarget>[];
    final ids = <String>{};
    for (final entry in favorites) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Neplatná oblíbená aplikace.');
      }
      final app = LaunchTarget.fromJson(entry);
      if (ids.add(app.id)) apps.add(app);
    }
    final targets = <LaunchAction, LaunchTarget>{};
    for (final action in LaunchAction.values) {
      final entry = actions[action.jsonKey];
      if (entry == null) continue;
      if (entry is! Map<String, dynamic> || entry['type'] != 'launchApp') {
        throw const FormatException('Neplatná akce.');
      }
      targets[action] = LaunchTarget.fromJson(entry);
    }
    final names = <String, String>{for (final app in apps) app.id: app.label};
    for (final entry in labels.entries) {
      if (entry.value is! String || (entry.value as String).trim().isEmpty) {
        throw const FormatException('Neplatný název aplikace.');
      }
      names[entry.key] = (entry.value as String).trim();
    }
    return LauncherSettings(
      favorites: apps,
      columns: columns,
      autoKeyboard: keyboard,
      fontSize: font.toDouble(),
      actions: targets,
      labels: names,
    );
  }

  final List<LaunchTarget> favorites;
  final int columns;
  final bool autoKeyboard;
  final double fontSize;
  final Map<LaunchAction, LaunchTarget> actions;
  final Map<String, String> labels;

  LauncherSettings copyWith({
    Iterable<LaunchTarget>? favorites,
    int? columns,
    bool? autoKeyboard,
    double? fontSize,
    Map<LaunchAction, LaunchTarget>? actions,
    Map<String, String>? labels,
  }) => LauncherSettings(
    favorites: favorites ?? this.favorites,
    columns: columns ?? this.columns,
    autoKeyboard: autoKeyboard ?? this.autoKeyboard,
    fontSize: fontSize ?? this.fontSize,
    actions: actions ?? this.actions,
    labels: labels ?? this.labels,
  );

  String encode() => jsonEncode({
    'schemaVersion': 1,
    'layout': {
      'favoriteColumns': columns,
      'favoriteFillOrder': 'rowMajor',
      'fontSize': fontSize,
    },
    'autoKeyboard': autoKeyboard,
    'favorites': favorites.map((app) => app.toJson()).toList(),
    'labels': labels,
    'actions': {
      for (final entry in actions.entries)
        entry.key.jsonKey: {'type': 'launchApp', ...entry.value.toJson()},
    },
  });
}

String normalizeSearch(String text) {
  const accents = 'áäàâãåčćďéěëèêíïìîľĺňńóöòôõřŕšśťúůüùûýÿžźż';
  const plain = 'aaaaaaccdeeeeeiiiillnnooooorrsstuuuuuyyzzz';
  var result = text.toLowerCase();
  for (var i = 0; i < accents.length; i++) {
    result = result.replaceAll(accents[i], plain[i]);
  }
  return result
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class LabelSortKey implements Comparable<LabelSortKey> {
  LabelSortKey(this.label) : _key = _buildKey(label);

  final String label;
  final List<int> _key;

  static const _alphabet = [
    'a',
    'b',
    'c',
    'č',
    'd',
    'e',
    'f',
    'g',
    'h',
    'ch',
    'i',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'q',
    'r',
    'ř',
    's',
    'š',
    't',
    'u',
    'v',
    'w',
    'x',
    'y',
    'z',
    'ž',
  ];
  static List<int> _buildKey(String label) {
    var text = label.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    for (final char in 'áäàâãåďéěëèêíïìîňóöòôõťúůüùûýÿ'.split('')) {
      text = text.replaceAll(char, normalizeSearch(char));
    }
    final result = <int>[];
    for (var i = 0; i < text.length; i++) {
      final token = text.startsWith('ch', i) ? 'ch' : text[i];
      if (token == 'ch') i++;
      final index = _alphabet.indexOf(token);
      result.add(index < 0 ? text.codeUnitAt(i) - 1000 : index);
    }
    return result;
  }

  @override
  int compareTo(LabelSortKey other) {
    for (var i = 0; i < _key.length && i < other._key.length; i++) {
      final difference = _key[i].compareTo(other._key[i]);
      if (difference != 0) return difference;
    }
    final length = _key.length.compareTo(other._key.length);
    return length != 0 ? length : label.compareTo(other.label);
  }
}

int compareLabels(String a, String b) =>
    LabelSortKey(a).compareTo(LabelSortKey(b));
