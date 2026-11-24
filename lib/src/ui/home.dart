import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../controller.dart';
import '../models.dart';
import 'apps.dart';

const _tileSpacing = 8.0;

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
    final showAppIcons = controller.settings.showAppIcons;
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
                        // Three columns leave no room for a label beside the icon.
                        final iconBeside = showAppIcons && columns == 2;
                        final rows = (favorites.length / columns).ceil();
                        final tileWidth =
                            (constraints.maxWidth -
                                (columns - 1) * _tileSpacing) /
                            columns;
                        final textWidth = math.max(
                          1.0,
                          tileWidth - 20 - (iconBeside ? appIconSize + 8 : 0),
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
                                16 +
                                (showAppIcons && !iconBeside ? appIconSize : 0),
                          ),
                        );
                        final height = math.max(
                          minimumHeight,
                          ((constraints.maxHeight - (rows - 1) * _tileSpacing) /
                                  rows)
                              .clamp(72.0, 108.0),
                        );
                        final gridHeight =
                            rows * height + (rows - 1) * _tileSpacing;
                        final overflows =
                            gridHeight > constraints.maxHeight + 1;
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            height: math.min(gridHeight, constraints.maxHeight),
                            child: _FavoritesGrid(
                              controller: controller,
                              columns: columns,
                              tileHeight: height,
                              overflows: overflows,
                              onLaunch: widget.onLaunch,
                              onMenu: widget.onMenu,
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

class _FavoriteDrag {
  _FavoriteDrag(this.favorites, this.from, this.pointer) : to = from;

  final List<LaunchTarget> favorites;
  final int from;
  Offset pointer;
  int to;
  bool moved = false;
}

class _FavoritesGrid extends StatefulWidget {
  const _FavoritesGrid({
    required this.controller,
    required this.columns,
    required this.tileHeight,
    required this.overflows,
    required this.onLaunch,
    required this.onMenu,
  });

  final LauncherController controller;
  final int columns;
  final double tileHeight;
  final bool overflows;
  final ValueChanged<LaunchTarget> onLaunch;
  final ValueChanged<LaunchTarget> onMenu;

  @override
  State<_FavoritesGrid> createState() => _FavoritesGridState();
}

class _FavoritesGridState extends State<_FavoritesGrid> {
  final _scroll = ScrollController();
  _FavoriteDrag? _drag;
  Timer? _edgeScroll;

  RenderBox get _viewport => context.findRenderObject()! as RenderBox;
  double get _rowStride => widget.tileHeight + _tileSpacing;

  @override
  void didUpdateWidget(covariant _FavoritesGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _clearDrag(oldWidget.controller);
    }
  }

  @override
  void dispose() {
    _clearDrag(widget.controller);
    _scroll.dispose();
    super.dispose();
  }

  int? _slotAt(Offset local, int count, {bool requireTile = false}) {
    final size = _viewport.size;
    if (count == 0 || requireTile && !(Offset.zero & size).contains(local)) {
      return null;
    }

    final columns = widget.columns;
    final tileWidth =
        math.max(0.0, size.width - (columns - 1) * _tileSpacing) / columns;
    final columnStride = tileWidth + _tileSpacing;
    final x = local.dx;
    final y = local.dy.clamp(0.0, size.height) + _scroll.offset;
    final halfGap = requireTile ? 0.0 : _tileSpacing / 2;
    final column = ((x + halfGap) / columnStride).floor().clamp(0, columns - 1);
    final row = ((y + halfGap) / _rowStride).floor();
    final index = row * columns + column;
    if (requireTile) {
      return index < count &&
              x - column * columnStride < tileWidth &&
              y - row * _rowStride < widget.tileHeight
          ? index
          : null;
    }
    final rows = (count / columns).ceil();
    return y >= rows * _rowStride - _tileSpacing
        ? count - 1
        : math.min(index, count - 1);
  }

  void _startDrag(LongPressStartDetails details) {
    final controller = widget.controller;
    final favorites = controller.settings.favorites;
    final local = _viewport.globalToLocal(details.globalPosition);
    final index = _slotAt(local, favorites.length, requireTile: true);
    if (index == null) return;
    unawaited(Feedback.forLongPress(context));
    if (!controller.settingsAvailable) {
      widget.onMenu(favorites[index]);
      return;
    }

    setState(
      () => _drag = _FavoriteDrag(favorites, index, details.globalPosition),
    );
    controller.addListener(_checkDrag);
  }

  bool _canMove(_FavoriteDrag drag) =>
      widget.controller.settingsAvailable &&
      listEquals(drag.favorites, widget.controller.settings.favorites);

  void _checkDrag() {
    final drag = _drag;
    if (drag != null && !_canMove(drag)) _cancelDrag();
  }

  void _moveDrag(LongPressMoveUpdateDetails details) {
    _checkDrag();
    final drag = _drag;
    if (drag == null) return;
    drag.pointer = details.globalPosition;
    final local = _viewport.globalToLocal(drag.pointer);
    _previewSlot(drag, local);

    // A slight movement near an edge should still allow opening the menu.
    if ((!drag.moved && details.offsetFromOrigin.distance < kTouchSlop) ||
        _edgeOffset(local) == null) {
      _stopEdgeScroll();
      return;
    }
    _edgeScroll ??= Timer.periodic(
      const Duration(milliseconds: 160),
      _scrollAtEdge,
    );
  }

  void _previewSlot(_FavoriteDrag drag, Offset local) {
    final to = _slotAt(local, drag.favorites.length);
    if (to == null || to == drag.to) return;
    setState(() {
      drag.to = to;
      drag.moved = true;
    });
  }

  double? _edgeOffset(Offset local) {
    if (!widget.overflows || !_scroll.hasClients) return null;
    final position = _scroll.position;
    final height = position.viewportDimension;
    final edge = math.min(32.0, height / 4);
    if (local.dy >= edge && local.dy <= height - edge) return null;
    final offset =
        (position.pixels + (local.dy < edge ? -_rowStride : _rowStride)).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    return offset != position.pixels ? offset : null;
  }

  void _scrollAtEdge(Timer _) {
    _checkDrag();
    final drag = _drag;
    if (drag == null) return;
    final local = _viewport.globalToLocal(drag.pointer);
    final offset = _edgeOffset(local);
    if (offset == null) {
      _stopEdgeScroll();
      return;
    }
    _scroll.jumpTo(offset);
    _previewSlot(drag, local);
  }

  void _stopEdgeScroll() {
    _edgeScroll?.cancel();
    _edgeScroll = null;
  }

  void _clearDrag(LauncherController controller) {
    if (_drag == null) return;
    _stopEdgeScroll();
    _drag = null;
    controller.removeListener(_checkDrag);
  }

  void _cancelDrag() {
    if (_drag != null) setState(() => _clearDrag(widget.controller));
  }

  void _finishDrag() {
    _checkDrag();
    final drag = _drag;
    if (drag == null) return;
    _cancelDrag();
    if (drag.from != drag.to) {
      unawaited(widget.controller.moveFavorite(drag.from, drag.to));
    } else if (!drag.moved) {
      widget.onMenu(drag.favorites[drag.from]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final drag = _drag;
    final lifted = drag != null && _canMove(drag) ? drag : null;
    var favorites = widget.controller.settings.favorites;
    if (lifted != null && lifted.from != lifted.to) {
      favorites = [...favorites];
      favorites.insert(lifted.to, favorites.removeAt(lifted.from));
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onLongPressStart: _startDrag,
      onLongPressMoveUpdate: _moveDrag,
      onLongPressUp: _finishDrag,
      onLongPressCancel: _cancelDrag,
      child: GridView.builder(
        key: const PageStorageKey('favorites'),
        controller: _scroll,
        padding: EdgeInsets.zero,
        physics: widget.overflows
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.columns,
          crossAxisSpacing: _tileSpacing,
          mainAxisSpacing: _tileSpacing,
          mainAxisExtent: widget.tileHeight,
        ),
        itemCount: favorites.length,
        itemBuilder: (context, index) =>
            _tile(context, favorites[index], lifted: index == lifted?.to),
      ),
    );
  }

  Widget _tile(BuildContext context, LaunchTarget app, {required bool lifted}) {
    final controller = widget.controller;
    final installed = controller.resolve(app);
    final label = controller.label(app);
    final text = AdaptiveLabel(
      label: label,
      fontSize: controller.settings.fontSize,
    );
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = lifted ? scheme.surface : scheme.onSurface;
    final iconBeside = widget.columns == 2;
    return Semantics(
      label: installed != null ? label : '$label, není nainstalovaná',
      button: true,
      excludeSemantics: true,
      onTap: () => widget.onLaunch(app),
      onLongPress: () => widget.onMenu(app),
      child: Material(
        color: lifted ? scheme.onSurface : null,
        textStyle: lifted
            ? theme.textTheme.bodyMedium!.copyWith(color: foreground)
            : null,
        animationDuration: Duration.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: foreground,
            width: installed != null ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('favorite-${app.packageName}'),
          onTap: () => widget.onLaunch(app),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: controller.settings.showAppIcons && installed != null
                ? Flex(
                    direction: iconBeside ? Axis.horizontal : Axis.vertical,
                    spacing: iconBeside ? 8 : 0,
                    children: [
                      appIcon(controller, installed),
                      Expanded(child: text),
                    ],
                  )
                : text,
          ),
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
      DefaultTextStyle.of(context).style
          .copyWith(fontSize: size, height: 1.04, fontWeight: FontWeight.w600);

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
      double widestWord(double value) {
        final words = TextPainter(
          text: TextSpan(
            text: label.replaceAll(' ', '\n'),
            style: style(value),
          ),
          textDirection: direction,
          textScaler: scaler,
        )..layout();
        final width = words.width;
        words.dispose();
        return width;
      }

      // A word too wide even at the smallest size is split anyway, so it may stay large.
      final keepWords = widestWord(minSize) <= bounds.maxWidth;
      while (size > minSize) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style(size)),
          textDirection: direction,
          textAlign: TextAlign.center,
          textScaler: scaler,
          maxLines: maxLines,
        )..layout(maxWidth: bounds.maxWidth);
        final fits =
            !painter.didExceedMaxLines &&
            painter.height <= bounds.maxHeight &&
            (!keepWords || widestWord(size) <= bounds.maxWidth);
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
  const ClockHeader({super.key, this.onClock, this.onDate});
  final VoidCallback? onClock;
  final VoidCallback? onDate;

  @override
  State<ClockHeader> createState() => _ClockHeaderState();
}

class _ClockHeaderState extends State<ClockHeader> with WidgetsBindingObserver {
  String _time = '';
  String _date = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _update();
  }

  void _update() {
    final now = clock.now();
    final time = DateFormat('HH:mm').format(now);
    final date = DateFormat('EEEE d. MMMM', 'cs_CZ').format(now);
    if (time != _time || date != _date) {
      setState(() {
        _time = time;
        _date = date;
      });
    }
    _timer?.cancel();
    _timer = Timer(
      Duration(milliseconds: 60010 - now.second * 1000 - now.millisecond),
      () {
        if (mounted) _update();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // Home stays visible but inactive under a message popup or the notification shade.
      case AppLifecycleState.resumed || AppLifecycleState.inactive:
        _update();
      case AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
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
          label: widget.onClock == null ? _time : 'Budík, $_time',
          button: widget.onClock != null,
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
                  _time,
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
                _date,
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
