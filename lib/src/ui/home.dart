import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controller.dart';
import '../models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onApps,
    required this.onSettings,
    required this.onLaunch,
    required this.onMenu,
    required this.onAction,
    required this.onNotifications,
  });
  final LauncherController controller;
  final VoidCallback onApps;
  final VoidCallback onSettings;
  final ValueChanged<LaunchTarget> onLaunch;
  final ValueChanged<LaunchTarget> onMenu;
  final ValueChanged<LaunchAction> onAction;
  final VoidCallback onNotifications;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _horizontal = 0;
  double _vertical = 0;
  bool _appsOpened = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final favorites = controller.settings.favorites;
    return GestureDetector(
      key: const ValueKey('home-gestures'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _horizontal = 0,
      onHorizontalDragUpdate: (details) => _horizontal += details.delta.dx,
      onHorizontalDragEnd: (details) {
        if (_horizontal.abs() < 48 &&
            !(_horizontal.abs() > 20 &&
                (details.primaryVelocity ?? 0).abs() > 350)) {
          return;
        }
        widget.onAction(
          _horizontal > 0 ? LaunchAction.right : LaunchAction.left,
        );
      },
      onVerticalDragStart: (_) {
        _vertical = 0;
        _appsOpened = false;
      },
      onVerticalDragUpdate: (details) {
        _vertical += details.delta.dy;
        if (_vertical <= -48 && !_appsOpened) {
          _appsOpened = true;
          widget.onApps();
        }
      },
      onVerticalDragEnd: (details) {
        if (_appsOpened) return;
        if (_vertical.abs() < 48 &&
            !(_vertical.abs() > 20 &&
                (details.primaryVelocity ?? 0).abs() > 350)) {
          return;
        }
        if (_vertical < 0) {
          widget.onApps();
        } else {
          widget.onNotifications();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(
          children: [
            ClockHeader(
              onClock: () => widget.onAction(LaunchAction.clock),
              onDate: () => widget.onAction(LaunchAction.date),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: favorites.isEmpty
                  ? Center(
                      child: OutlinedButton(
                        onPressed: widget.onApps,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Vyber si oblíbené aplikace',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = controller.settings.columns;
                        final rows = (favorites.length / columns).ceil();
                        final textWidth = math.max(
                          1.0,
                          (constraints.maxWidth - (columns - 1) * 8) / columns -
                              20,
                        );
                        final minimumHeight = favorites.fold<double>(
                          72,
                          (height, app) => math.max(
                            height,
                            AdaptiveLabel.minimumHeight(
                                  context,
                                  controller.label(app),
                                  textWidth,
                                ) +
                                16,
                          ),
                        );
                        final height = math.max(
                          minimumHeight,
                          ((constraints.maxHeight - (rows - 1) * 8) / rows)
                              .clamp(72.0, 108.0),
                        );
                        final gridHeight = rows * height + (rows - 1) * 8;
                        final overflows =
                            gridHeight > constraints.maxHeight + 1;
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            height: math.min(gridHeight, constraints.maxHeight),
                            child: GridView.builder(
                              key: const PageStorageKey('favorites'),
                              padding: EdgeInsets.zero,
                              physics: overflows
                                  ? const ClampingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    mainAxisExtent: height,
                                  ),
                              itemCount: favorites.length,
                              itemBuilder: (context, index) {
                                final app = favorites[index];
                                final installed =
                                    controller.resolve(app) != null;
                                final label = controller.label(app);
                                return Semantics(
                                  label: installed
                                      ? label
                                      : '$label, není nainstalovaná',
                                  button: true,
                                  excludeSemantics: true,
                                  onTap: () => widget.onLaunch(app),
                                  onLongPress: () => widget.onMenu(app),
                                  child: Material(
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        width: installed ? 1.5 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      key: ValueKey(
                                        'favorite-${app.packageName}',
                                      ),
                                      onTap: () => widget.onLaunch(app),
                                      onLongPress: () => widget.onMenu(app),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        child: AdaptiveLabel(
                                          label: label,
                                          fontSize:
                                              controller.settings.fontSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    key: const ValueKey('open-apps'),
                    onPressed: widget.onApps,
                    icon: const Icon(Icons.keyboard_arrow_up),
                    label: const Text(
                      'Aplikace',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('open-settings'),
                  tooltip: 'Nastavení',
                  onPressed: widget.onSettings,
                  icon: const Icon(Icons.settings_outlined),
                  constraints: const BoxConstraints(
                    minHeight: 52,
                    minWidth: 56,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AdaptiveLabel extends StatelessWidget {
  const AdaptiveLabel({super.key, required this.label, required this.fontSize});
  final String label;
  final double fontSize;

  static TextStyle _style(BuildContext context, double size) =>
      DefaultTextStyle.of(context).style.copyWith(
        fontSize: size,
        height: 1.04,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      );

  static double minimumHeight(
    BuildContext context,
    String label,
    double width,
  ) {
    final lines = math.max(2, label.split('\n').length);
    final painter = TextPainter(
      text: TextSpan(text: label, style: _style(context, lines > 2 ? 8 : 12)),
      textDirection: Directionality.of(context),
      textAlign: TextAlign.center,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: lines,
    )..layout(maxWidth: width);
    final height = painter.height.ceilToDouble();
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final maxLines = math.max(2, label.split('\n').length);
      final minSize = maxLines > 2 ? 8.0 : 12.0;
      var size = fontSize;
      TextStyle style(double value) => _style(context, value);
      while (size > minSize) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style(size)),
          textDirection: direction,
          textAlign: TextAlign.center,
          textScaler: scaler,
          maxLines: maxLines,
        )..layout(maxWidth: bounds.maxWidth);
        final fits =
            !painter.didExceedMaxLines && painter.height <= bounds.maxHeight;
        painter.dispose();
        if (fits) break;
        size = math.max(minSize, size - 0.5);
      }
      return Center(
        child: Text(
          label,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: style(size),
        ),
      );
    },
  );
}

class ClockHeader extends StatefulWidget {
  const ClockHeader({super.key, required this.onClock, required this.onDate});
  final VoidCallback onClock;
  final VoidCallback onDate;

  @override
  State<ClockHeader> createState() => _ClockHeaderState();
}

class _ClockHeaderState extends State<ClockHeader> with WidgetsBindingObserver {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    _timer = Timer(
      Duration(milliseconds: 60010 - now.second * 1000 - now.millisecond),
      () {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
        _schedule();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _now = DateTime.now());
      _schedule();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Budík, ${DateFormat('HH:mm').format(_now)}',
          button: true,
          excludeSemantics: true,
          onTap: widget.onClock,
          child: InkWell(
            key: const ValueKey('clock'),
            onTap: widget.onClock,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  DateFormat('HH:mm').format(_now),
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    letterSpacing: -2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
        InkWell(
          key: const ValueKey('date'),
          onTap: widget.onDate,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                DateFormat('EEEE d. MMMM', 'cs_CZ').format(_now),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
