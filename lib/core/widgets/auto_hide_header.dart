import 'package:flutter/material.dart';

/// A [header] above a [body] that, in landscape, slides out of the way while
/// the body scrolls down and returns when it scrolls up, so the body gets the
/// full height of the short screen. In portrait it is a plain column.
class AutoHideHeader extends StatefulWidget {
  final Widget header;
  final Widget body;

  const AutoHideHeader({super.key, required this.header, required this.body});

  @override
  State<AutoHideHeader> createState() => _AutoHideHeaderState();
}

class _AutoHideHeaderState extends State<AutoHideHeader> {
  bool _visible = true;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n is! ScrollUpdateNotification) {
      return false;
    }
    final delta = n.scrollDelta ?? 0;
    if (delta > 2 && n.metrics.pixels > 0 && _visible) {
      setState(() => _visible = false);
    } else if ((delta < -2 || n.metrics.pixels <= 0) && !_visible) {
      setState(() => _visible = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (!landscape) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.header,
          Expanded(child: widget.body),
        ],
      );
    }
    // The whole page scrolls as one, with the body always as tall as the
    // viewport. A tall header (search, active filters, group by) can therefore
    // never squeeze the body to nothing: it just scrolls out of the way.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRect(
                child: AnimatedAlign(
                  alignment: Alignment.topCenter,
                  heightFactor: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: widget.header,
                ),
              ),
              SizedBox(
                height: constraints.maxHeight,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: widget.body,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
