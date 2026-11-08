import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';

class AppsScreen extends StatefulWidget {
  const AppsScreen({
    super.key,
    required this.controller,
    required this.onLaunch,
    required this.onMenu,
    required this.onBack,
    this.includeFavorites = false,
    this.autoKeyboard,
    this.title = 'Aplikace',
    this.header,
  });
  final LauncherController controller;
  final ValueChanged<LaunchTarget> onLaunch;
  final ValueChanged<LaunchTarget> onMenu;
  final VoidCallback onBack;
  final bool includeFavorites;
  final bool? autoKeyboard;
  final String title;
  final Widget? header;

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  double _headerPull = 0;
  double _listPull = 0;
  bool _dismissed = false;

  void _dismiss() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    _focus.unfocus();
    widget.onBack();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollStartNotification ||
        notification is ScrollEndNotification) {
      _listPull = 0;
    } else if (notification is ScrollUpdateNotification) {
      if (notification.metrics.extentBefore > 0 ||
          (notification.scrollDelta ?? 0) > 0) {
        _listPull = 0;
      }
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.metrics.extentBefore == 0 &&
        notification.overscroll < 0) {
      _listPull -= notification.overscroll;
      if (_listPull >= 48) _dismiss();
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoKeyboard ?? widget.controller.settings.autoKeyboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final apps = controller.visibleApps(
      query: _query.text,
      includeFavorites: widget.includeFavorites,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _headerPull = 0,
      onVerticalDragUpdate: (details) => _headerPull += details.delta.dy,
      onVerticalDragEnd: (_) {
        if (_headerPull >= 48) _dismiss();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Column(
          children: [
            AppBar(
              leading: IconButton(
                tooltip: 'Zpět',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              title: Text(widget.title),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                key: const ValueKey('app-search'),
                controller: _query,
                focusNode: _focus,
                style: const TextStyle(fontSize: 20),
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Hledat aplikaci',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Vymazat hledání',
                          onPressed: () => setState(_query.clear),
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (apps.length == 1) widget.onLaunch(apps.single);
                },
              ),
            ),
            ?widget.header,
            Expanded(
              child: apps.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _query.text.isEmpty
                              ? 'Žádné další aplikace'
                              : 'Žádná aplikace neodpovídá hledání.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      key: const ValueKey('app-list'),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.paddingOf(context).bottom + 16,
                      ),
                      itemCount: apps.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, thickness: 1),
                      itemBuilder: (context, index) {
                        final app = apps[index];
                        return ListTile(
                          key: ValueKey('app-${app.id}'),
                          title: Text(
                            controller.label(app),
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () => widget.onLaunch(app),
                          onLongPress: () => widget.onMenu(app),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
