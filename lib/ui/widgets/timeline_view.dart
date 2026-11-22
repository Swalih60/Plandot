import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/task.dart';
import '../../util/dates.dart';
import '../theme.dart';
import 'animated_check.dart';
import 'task_tile.dart' show StrikeText;

/// A vertical hour timeline for one day: timed tasks become blocks placed at
/// their time, untimed tasks sit in an "Anytime" strip on top, and a live
/// "now" line tracks the current time. Scrolls the enclosing scrollable to
/// now (or the first block) when shown.
class DayTimeline extends StatefulWidget {
  const DayTimeline({
    super.key,
    required this.day,
    required this.tasks,
    required this.onOpen,
    required this.onToggle,
  });

  final DateTime day;
  final List<Task> tasks;
  final ValueChanged<Task> onOpen;
  final ValueChanged<Task> onToggle;

  static const hourHeight = 68.0;
  static const endHour = 24;
  static const defaultStartHour = 6;

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  static const _gutter = 54.0;
  static const _topPad = 12.0;
  static const _blockH = 56.0;
  final _anchor = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scheduleScroll();
  }

  @override
  void didUpdateWidget(DayTimeline old) {
    super.didUpdateWidget(old);
    if (!isSameDay(old.day, widget.day)) _scheduleScroll();
  }

  void _scheduleScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _anchor.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(ctx,
          alignment: 0.4, duration: T.slow, curve: T.ease);
    });
  }

  int get _startHour {
    var h = DayTimeline.defaultStartHour;
    for (final t in widget.tasks) {
      final m = t.timeMinutes;
      if (m != null) h = math.min(h, m ~/ 60);
    }
    return h;
  }

  double _y(int minutes, int startHour) =>
      _topPad + (minutes - startHour * 60) / 60 * DayTimeline.hourHeight;

  static String _hourLabel(int h) {
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12 ${h % 24 < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final timed = widget.tasks.where((t) => t.timeMinutes != null).toList()
      ..sort((a, b) => a.timeMinutes!.compareTo(b.timeMinutes!));
    final anytime = widget.tasks.where((t) => t.timeMinutes == null).toList();
    final start = _startHour;
    final hours = DayTimeline.endHour - start;
    final height = _topPad * 2 + hours * DayTimeline.hourHeight;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final showNow = isSameDay(widget.day, now) && nowMin >= start * 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (anytime.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 0, 8),
            child: _Label('Anytime', anytime.length),
          ),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: anytime.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _AnytimeCard(
                key: ValueKey('any-${anytime[i].id}'),
                task: anytime[i],
                day: widget.day,
                onOpen: () => widget.onOpen(anytime[i]),
                onToggle: () => widget.onToggle(anytime[i]),
              )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: (i * 45).ms)
                  .slideX(begin: 0.15, curve: T.ease, duration: 360.ms, delay: (i * 45).ms),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
          child: Row(
            children: [
              _Label('Schedule', timed.length),
              const Spacer(),
              if (timed.isEmpty)
                Text('Add a time to a task to place it here',
                    style: TextStyle(
                        color: pal.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(T.r),
            border: Border.all(color: pal.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(builder: (context, c) {
            final blocks = _layout(timed, start, c.maxWidth);
            return Stack(
              children: [
                for (var h = start; h <= DayTimeline.endHour; h++) ...[
                  Positioned(
                    left: 0,
                    width: _gutter - 10,
                    top: _y(h * 60, start) - 7,
                    child: Text(
                      _hourLabel(h),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: pal.muted.withValues(alpha: 0.85)),
                    ),
                  ),
                  Positioned(
                    left: _gutter,
                    right: 0,
                    top: _y(h * 60, start),
                    child: Container(height: 1, color: pal.line),
                  ),
                  if (h < DayTimeline.endHour)
                    Positioned(
                      left: _gutter + 8,
                      right: 12,
                      top: _y(h * 60 + 30, start),
                      child: Container(
                          height: 1, color: pal.line.withValues(alpha: 0.45)),
                    ),
                ],
                for (var i = 0; i < blocks.length; i++)
                  Positioned(
                    key: ValueKey('block-${blocks[i].task.id}'),
                    left: blocks[i].left,
                    top: blocks[i].top,
                    width: blocks[i].width,
                    height: _blockH,
                    child: KeyedSubtree(
                      key: !showNow && i == 0 ? _anchor : null,
                      child: _Block(
                        task: blocks[i].task,
                        day: widget.day,
                        compact: blocks[i].width < 130,
                        onOpen: () => widget.onOpen(blocks[i].task),
                        onToggle: () => widget.onToggle(blocks[i].task),
                      )
                          .animate()
                          .fadeIn(duration: 320.ms, delay: (80 + i * 50).ms)
                          .slideX(
                              begin: 0.06,
                              curve: T.ease,
                              duration: 380.ms,
                              delay: (80 + i * 50).ms),
                    ),
                  ),
                if (showNow)
                  _NowLine(
                    anchor: _anchor,
                    startHour: start,
                    gutter: _gutter,
                    y: (m) => _y(m, start),
                  ),
              ],
            );
          }),
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, curve: T.ease),
      ],
    );
  }

  /// Places blocks; overlapping ones share the row in columns.
  List<_Placed> _layout(List<Task> timed, int start, double width) {
    final placed = <_Placed>[];
    var cluster = <_Placed>[];
    var colEnds = <double>[];
    var clusterEnd = -1.0;

    void flush() {
      final cols = math.max(1, colEnds.length);
      final avail = width - _gutter - 10;
      final w = avail / cols;
      for (final p in cluster) {
        p.left = _gutter + 4 + p.col * w;
        p.width = w - 6;
      }
      placed.addAll(cluster);
      cluster = [];
      colEnds = [];
    }

    for (final t in timed) {
      final top = _y(t.timeMinutes!, start) + 2;
      final bottom = top + _blockH + 4;
      if (cluster.isNotEmpty && top >= clusterEnd) flush();
      var col = colEnds.indexWhere((e) => e <= top);
      if (col == -1) {
        col = colEnds.length;
        colEnds.add(bottom);
      } else {
        colEnds[col] = bottom;
      }
      cluster.add(_Placed(t, top, col));
      clusterEnd = cluster.length == 1 ? bottom : math.max(clusterEnd, bottom);
    }
    if (cluster.isNotEmpty) flush();
    return placed;
  }
}

class _Placed {
  _Placed(this.task, this.top, this.col);
  final Task task;
  final double top;
  final int col;
  double left = 0, width = 0;
}

Color _taskColor(BuildContext context, Task t) =>
    t.priority == Priority.none ? context.pal.accent : priorityColor(t.priority);

class _Label extends StatelessWidget {
  const _Label(this.title, this.count);
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: pal.muted)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: pal.muted.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w800, color: pal.muted)),
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.task,
    required this.day,
    required this.compact,
    required this.onOpen,
    required this.onToggle,
  });
  final Task task;
  final DateTime day;
  final bool compact;
  final VoidCallback onOpen, onToggle;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = _taskColor(context, task);
    final done = task.isDoneOn(day);
    final tag = tagByName(task.tag);
    return AnimatedOpacity(
      duration: T.med,
      opacity: done ? 0.55 : 1,
      child: Material(
        color: Color.alphaBlend(c.withValues(alpha: pal.dark ? 0.18 : 0.11), pal.card),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.withValues(alpha: 0.32)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Row(
            children: [
              Container(width: 4, color: c),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StrikeText(
                        text: task.title,
                        struck: done,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: pal.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          formatMinutes(task.timeMinutes!),
                          if (tag != null && !compact) '${tag.emoji} ${tag.name}',
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: c.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ),
              ),
              if (!compact)
                AnimatedCheck(
                  checked: done,
                  color: c,
                  size: 20,
                  onChanged: (_) => onToggle(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnytimeCard extends StatelessWidget {
  const _AnytimeCard({
    super.key,
    required this.task,
    required this.day,
    required this.onOpen,
    required this.onToggle,
  });
  final Task task;
  final DateTime day;
  final VoidCallback onOpen, onToggle;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = _taskColor(context, task);
    final done = task.isDoneOn(day);
    return SizedBox(
      width: 178,
      child: AnimatedOpacity(
        duration: T.med,
        opacity: done ? 0.55 : 1,
        child: Material(
          color: pal.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: pal.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Row(
              children: [
                Container(
                  width: 4,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: task.priority == Priority.none ? Colors.transparent : c,
                    borderRadius:
                        const BorderRadius.horizontal(right: Radius.circular(4)),
                  ),
                ),
                AnimatedCheck(
                  checked: done,
                  color: c,
                  size: 20,
                  onChanged: (_) => onToggle(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: StrikeText(
                      text: task.title,
                      struck: done,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: done ? pal.muted : pal.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The live "now" marker. Refreshes every 30 s.
class _NowLine extends StatefulWidget {
  const _NowLine({
    required this.anchor,
    required this.startHour,
    required this.gutter,
    required this.y,
  });
  final GlobalKey anchor;
  final int startHour;
  final double gutter;
  final double Function(int minutes) y;

  @override
  State<_NowLine> createState() => _NowLineState();
}

class _NowLineState extends State<_NowLine> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final now = DateTime.now();
    final m = now.hour * 60 + now.minute;
    final top = widget.y(m);
    final label = formatMinutes(m).replaceAll(' AM', '').replaceAll(' PM', '');
    return AnimatedPositioned(
      duration: T.slow,
      curve: T.ease,
      left: 0,
      right: 0,
      top: top - 10,
      height: 20,
      child: IgnorePointer(
        child: Row(
          children: [
            SizedBox(
              key: widget.anchor,
              width: widget.gutter - 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: pal.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: pal.accent, shape: BoxShape.circle),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.8, end: 1.25, duration: 1100.ms, curve: Curves.easeInOut),
            Expanded(
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    pal.accent,
                    pal.accent.withValues(alpha: 0.15),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
