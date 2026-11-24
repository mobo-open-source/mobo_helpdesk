import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class CustomKanbanBoard<T extends Object> extends StatefulWidget {
  final List<T> data;
  final List<Map<String, dynamic>> stages;

  final String Function(T item) getStageName;
  final int Function(T item) getStageId;
  final Widget Function(T item) itemBuilder;

  final void Function(T item, int newStageId, String newStageName)? onReorder;
  final void Function(T item, int stageId, int newIndex)? onReorderInStage;

  final Widget Function(int stageId, String stageName, List<T> items)?
  headerBuilder;

  final bool isLoading;

  const CustomKanbanBoard({
    super.key,
    required this.data,
    required this.stages,
    required this.getStageName,
    required this.getStageId,
    required this.itemBuilder,
    this.onReorder,
    this.onReorderInStage,
    this.headerBuilder,
    this.isLoading = false,
  });

  @override
  State<CustomKanbanBoard<T>> createState() => _CustomKanbanBoardState<T>();
}

class _CustomKanbanBoardState<T extends Object>
    extends State<CustomKanbanBoard<T>> {
  late Map<int, List<T>> _grouped;

  final ScrollController _hScroll = ScrollController();
  final Map<int, ScrollController> _colScrolls = {};

  T? _dragging;
  int? _ghostInStage;
  int _ghostAt = -1;
  final Map<int, List<GlobalKey>> _keys = {};

  // Auto-scroll: only horizontal, only during drag
  Timer? _scrollTimer;
  double _pointerX = -1;

  static const double _edgePx = 72.0;
  static const double _maxStep = 12.0;
  static const Duration _tick = Duration(milliseconds: 16);

  @override
  void initState() {
    super.initState();
    _group();
    _syncColumnScrollers();
  }

  @override
  void didUpdateWidget(covariant CustomKanbanBoard<T> old) {
    super.didUpdateWidget(old);
    _group();
    _syncColumnScrollers();
  }

  @override
  void dispose() {
    _cancelScroll();
    _hScroll.dispose();
    for (final c in _colScrolls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _group() {
    _grouped = {for (final s in widget.stages) s['id'] as int: <T>[]};
    for (final item in widget.data) {
      _grouped[widget.getStageId(item)]?.add(item);
    }
    for (final s in widget.stages) {
      final id = s['id'] as int;
      final count = _grouped[id]?.length ?? 0;
      if (_keys[id]?.length != count) {
        _keys[id] = List.generate(count, (_) => GlobalKey());
      }
    }
  }

  void _syncColumnScrollers() {
    final newIds = widget.stages.map((s) => s['id'] as int).toSet();
    _colScrolls.keys
        .where((id) => !newIds.contains(id))
        .toList()
        .forEach((id) {
          _colScrolls.remove(id)?.dispose();
        });
    for (final id in newIds) {
      _colScrolls.putIfAbsent(id, ScrollController.new);
    }
  }

  // ── Auto-scroll (horizontal only, drag only) ─────────────────────────────

  void _startScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(_tick, (_) {
      if (_pointerX < 0 || !_hScroll.hasClients) return;
      final width = MediaQuery.of(context).size.width;
      double delta = 0;
      if (_pointerX < _edgePx) {
        delta = -_maxStep * (1 - _pointerX / _edgePx);
      } else if (_pointerX > width - _edgePx) {
        delta = _maxStep * (1 - (width - _pointerX) / _edgePx);
      }
      if (delta != 0) {
        _hScroll.jumpTo(
          (_hScroll.offset + delta)
              .clamp(0.0, _hScroll.position.maxScrollExtent),
        );
      }
    });
  }

  void _cancelScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _pointerX = -1;
  }

  // ── Drag callbacks ────────────────────────────────────────────────────────

  int _slotFor(int stageId, Offset globalPointer) {
    final keys = _keys[stageId] ?? [];
    for (int i = 0; i < keys.length; i++) {
      final ctx = keys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final mid = top + box.size.height / 2;
      if (globalPointer.dy < mid) return i;
    }
    return keys.length;
  }

  void _onDragStarted(T item) {
    setState(() {
      _dragging = item;
      _ghostInStage = null;
      _ghostAt = -1;
    });
    _startScroll();
  }

  void _onDragEnd(DraggableDetails _) {
    _cancelScroll();
    setState(() {
      _dragging = null;
      _ghostInStage = null;
      _ghostAt = -1;
    });
  }

  void _onMove(int stageId, DragTargetDetails<T> d) {
    final slot = _slotFor(stageId, d.offset);
    if (_ghostInStage != stageId || _ghostAt != slot) {
      setState(() {
        _ghostInStage = stageId;
        _ghostAt = slot;
      });
    }
  }

  void _onLeave(int stageId, T? _) {
    if (_ghostInStage == stageId) {
      setState(() {
        _ghostInStage = null;
        _ghostAt = -1;
      });
    }
  }

  void _onAccept(int stageId, String stageName, DragTargetDetails<T> d) {
    _cancelScroll();
    final slot = _slotFor(stageId, d.offset);
    setState(() {
      _ghostInStage = null;
      _ghostAt = -1;
      _dragging = null;
    });

    final item = d.data;
    final fromStage = widget.getStageId(item);

    if (fromStage != stageId) {
      widget.onReorder?.call(item, stageId, stageName);
    } else {
      final items = _grouped[stageId] ?? [];
      final cur = items.indexOf(item);
      if (cur == -1) return;
      int target = slot;
      if (cur < slot) target = slot - 1;
      if (cur != target) {
        widget.onReorderInStage?.call(item, stageId, target);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Track raw pointer position so auto-scroll works even at screen edges
      // where no DragTarget is present.
      onPointerMove: (e) {
        if (_dragging != null) _pointerX = e.position.dx;
      },
      behavior: HitTestBehavior.translucent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight.isFinite
              ? constraints.maxHeight - 20
              : MediaQuery.of(context).size.height - 30;

          return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
            },
          ),
          child: SingleChildScrollView(
            controller: _hScroll,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            dragStartBehavior: DragStartBehavior.down,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.stages.map((s) {
                final id = s['id'] as int;
                final name = s['name'] as String;
                return _buildColumn(id, name, _grouped[id] ?? [], maxH);
              }).toList(),
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _buildColumn(
      int stageId, String stageName, List<T> items, double maxH) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colScroll = _colScrolls[stageId]!;
    final colKeys = _keys[stageId] ?? [];

    final dragging = _dragging;
    final showGhost =
        dragging != null && _ghostInStage == stageId && _ghostAt >= 0;

    final cardWidgets = <Widget>[];
    int displayIndex = 0;
    int itemIndex = 0;

    while (itemIndex <= items.length) {
      if (showGhost && _ghostAt == displayIndex) {
        cardWidgets.add(_ghost(dragging, stageId));
        displayIndex++;
      }
      if (itemIndex == items.length) break;

      final item = items[itemIndex];
      final isBeingDragged = dragging != null && item == dragging;

      cardWidgets.add(
        AnimatedSize(
          key: ValueKey(stageId * 10000 + itemIndex),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: isBeingDragged
              ? const SizedBox.shrink()
              : Padding(
                  key: itemIndex < colKeys.length ? colKeys[itemIndex] : null,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: LongPressDraggable<T>(
                    data: item,
                    hapticFeedbackOnStart: true,
                    onDragStarted: () => _onDragStarted(item),
                    onDragEnd: _onDragEnd,
                    feedback: Material(
                      color: Colors.transparent,
                      elevation: 3,
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 264,
                        child: Opacity(
                          opacity: 0.95,
                          child: widget.itemBuilder(item),
                        ),
                      ),
                    ),
                    childWhenDragging: const SizedBox.shrink(),
                    child: widget.itemBuilder(item),
                  ),
                ),
        ),
      );

      itemIndex++;
      displayIndex++;
    }

    if (showGhost && _ghostAt == displayIndex) {
      cardWidgets.add(_ghost(dragging, stageId));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: DragTarget<T>(
          onMove: (d) => _onMove(stageId, d),
          onLeave: (d) => _onLeave(stageId, d),
          onAcceptWithDetails: (d) => _onAccept(stageId, stageName, d),
          builder: (context, _, __) {
            return Container(
              width: 292,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.headerBuilder != null
                      ? widget.headerBuilder!(stageId, stageName, items)
                      : Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '$stageName (${items.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: SingleChildScrollView(
                      controller: colScroll,
                      physics: const ClampingScrollPhysics(),
                      dragStartBehavior: DragStartBehavior.down,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...cardWidgets,
                          SizedBox(height: items.isEmpty ? 60 : 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _ghost(T item, int stageId) {
    return AnimatedSize(
      key: ValueKey('ghost_${stageId}_${item.hashCode}'),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Opacity(
        opacity: 0.4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: widget.itemBuilder(item),
        ),
      ),
    );
  }
}
