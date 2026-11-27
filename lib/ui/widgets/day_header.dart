import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../util/dates.dart';
import '../theme.dart';

/// Swipeable week strip. The selected pill glides between days.
class WeekStrip extends StatefulWidget {
  const WeekStrip({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.progress,
    required this.mondayFirst,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final (int, int) Function(DateTime) progress;
  final bool mondayFirst;

  @override
  State<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<WeekStrip> {
  static const _center = 500;
  late final PageController _pc = PageController(initialPage: _center);
  late DateTime _anchor = startOfWeek(
    DateTime.now(),
    mondayFirst: widget.mondayFirst,
  );

  DateTime _weekStart(int page) => addDays(_anchor, 7 * (page - _center));

  @override
  void didUpdateWidget(WeekStrip old) {
    super.didUpdateWidget(old);
    if (old.mondayFirst != widget.mondayFirst) {
      _anchor = startOfWeek(DateTime.now(), mondayFirst: widget.mondayFirst);
    }
    // Keep the selected day visible (e.g. after "Today" is tapped).
    final page =
        _center +
        (startOfWeek(
                  widget.selected,
                  mondayFirst: widget.mondayFirst,
                ).difference(_anchor).inDays /
                7)
            .round();
    if (_pc.hasClients && _pc.page?.round() != page) {
      _pc.animateToPage(page, duration: T.med, curve: T.ease);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: PageView.builder(
        controller: _pc,
        itemBuilder: (context, page) {
          final start = _weekStart(page);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth / 7;
                final selIndex = widget.selected.difference(start).inDays;
                final pal = context.pal;
                return Stack(
                  children: [
                    if (selIndex >= 0 && selIndex < 7)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutBack,
                        left: selIndex * w + 4,
                        top: 4,
                        width: w - 8,
                        height: 78,
                        child: Container(
                          decoration: BoxDecoration(
                            color: pal.ink,
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    Row(
                      children: List.generate(7, (i) {
                        final d = addDays(start, i);
                        final sel = i == selIndex;
                        final today = isSameDay(d, DateTime.now());
                        final (done, total) = widget.progress(d);
                        return SizedBox(
                          width: w,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onSelect(d);
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('E').format(d).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    letterSpacing: 0.6,
                                    fontWeight: FontWeight.w700,
                                    color: sel
                                        ? pal.bg.withValues(alpha: 0.7)
                                        : pal.muted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${d.day}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: sel
                                        ? pal.bg
                                        : today
                                        ? pal.accent
                                        : pal.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _Dot(done: done, total: total, sel: sel),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done, required this.total, required this.sel});
  final int done, total;
  final bool sel;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    if (total == 0) return const SizedBox(height: 6);
    final all = done == total;
    return AnimatedContainer(
      duration: T.med,
      width: all ? 14 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: all
            ? (sel ? pal.bg : pal.accent)
            : (sel
                  ? pal.bg.withValues(alpha: 0.5)
                  : pal.muted.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// Hero progress card with a sweeping ring and counting numbers.
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.done,
    required this.total,
    required this.streak,
    required this.isToday,
  });
  final int done, total, streak;
  final bool isToday;

  String get _headline {
    if (total == 0) return isToday ? 'A fresh start' : 'Nothing planned';
    if (done == total) return 'All done. Brilliant! 🎉';
    final left = total - done;
    if (done == 0) return '$left task${left == 1 ? '' : 's'} to go';
    if (done / total >= 0.5) return 'Over halfway there';
    return 'Nice momentum';
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final a = pal.accent;
    final frac = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            a,
            Color.lerp(
              a,
              pal.dark ? Colors.black : const Color(0xFF1A1033),
              0.35,
            )!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: a.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            height: 74,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: frac),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CustomPaint(
                painter: _RingPainter(v),
                child: Center(
                  child: Text(
                    '${(v * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: T.med,
                  transitionBuilder: (c, an) => FadeTransition(
                    opacity: an,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(an),
                      child: c,
                    ),
                  ),
                  child: Text(
                    _headline,
                    key: ValueKey(_headline),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0
                      ? 'Tap + to plan your day'
                      : '$done of $total completed',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (streak > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '🔥 $streak-day perfect streak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v);
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 5;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.white.withValues(alpha: 0.2);
    canvas.drawCircle(c, r, base);
    if (v <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * v,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v;
}
