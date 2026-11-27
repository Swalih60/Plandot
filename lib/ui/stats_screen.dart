import 'dart:ui';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../services/pro_service.dart';
import '../util/dates.dart';
import 'paywall_screen.dart';
import 'theme.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final isPro = context.watch<ProService>().isPro;
    final pal = context.pal;
    final today = dateOnly(DateTime.now());

    // Last 7 days
    final week = List.generate(7, (i) => addDays(today, i - 6));
    final weekProg = week.map(store.progressOn).toList();
    final weekDone = weekProg.fold<int>(0, (s, p) => s + p.$1);
    final weekTotal = weekProg.fold<int>(0, (s, p) => s + p.$2);
    final weekFocus = week.map(store.focusMinutesOn).toList();
    final focusTotal = weekFocus.fold<int>(0, (s, m) => s + m);
    final maxFocus = weekFocus.fold<int>(1, (m, x) => x > m ? x : m).toDouble();
    Task? topFocus;
    var topFocusMin = 0;
    for (final t in store.allTasks) {
      final m = week.fold<int>(0, (s, d) => s + t.focusOn(d));
      if (m > topFocusMin) {
        topFocusMin = m;
        topFocus = t;
      }
    }
    final maxDone = weekProg
        .fold<int>(1, (m, p) => p.$1 > m ? p.$1 : m)
        .toDouble();

    // Last 30 days for insights
    var done30 = 0, total30 = 0;
    final byPriority = {for (final p in Priority.values) p: (0, 0)};
    final byWeekday = List.filled(7, 0);
    final byTag = <String, int>{};
    for (var i = 0; i < 30; i++) {
      final d = addDays(today, -i);
      for (final t in store.tasksOn(d)) {
        final ok = t.isDoneOn(d);
        total30++;
        final (a, b) = byPriority[t.priority]!;
        byPriority[t.priority] = (a + (ok ? 1 : 0), b + 1);
        if (ok) {
          done30++;
          byWeekday[d.weekday - 1]++;
          if (t.tag != null) byTag[t.tag!] = (byTag[t.tag!] ?? 0) + 1;
        }
      }
    }
    final bestDay = byWeekday.every((x) => x == 0)
        ? null
        : weekdayShort[byWeekday.indexOf(
            byWeekday.reduce((a, b) => a > b ? a : b),
          )];
    final topTag = byTag.isEmpty
        ? null
        : (byTag.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;

    final insights = Column(
      children: [
        _Card(
          title: 'Priority breakdown · 30 days',
          child: Column(
            children: [
              for (final p in [
                Priority.high,
                Priority.medium,
                Priority.low,
                Priority.none,
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: priorityColor(p),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 64,
                        child: Text(
                          p.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(
                              end: byPriority[p]!.$2 == 0
                                  ? 0
                                  : byPriority[p]!.$1 / byPriority[p]!.$2,
                            ),
                            duration: 800.ms,
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 10,
                              color: priorityColor(p),
                              backgroundColor: pal.cardAlt,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${byPriority[p]!.$1}/${byPriority[p]!.$2}',
                        style: TextStyle(
                          color: pal.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Tile(
              value: total30 == 0
                  ? '–'
                  : '${(done30 * 100 / total30).round()}%',
              label: '30-day completion',
            ),
            const SizedBox(width: 10),
            _Tile(value: bestDay ?? '–', label: 'Most productive day'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Tile(
              value: topTag == null
                  ? '–'
                  : '${tagByName(topTag)!.emoji} $topTag',
              label: 'Top area',
            ),
            const SizedBox(width: 10),
            _Tile(value: '$done30', label: 'Tasks done · 30 days'),
          ],
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Row(
            children: [
              _Tile(value: '$weekDone', label: 'Done this week', big: true),
              const SizedBox(width: 10),
              _Tile(
                value: '🔥 ${store.perfectDayStreak()}',
                label: 'Perfect-day streak',
                big: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Card(
            title: 'Last 7 days',
            trailing: weekTotal == 0
                ? null
                : '${(weekDone * 100 / weekTotal).round()}% complete',
            child: SizedBox(
              height: 164,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${weekProg[i].$1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: pal.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TweenAnimationBuilder<double>(
                            tween: Tween(end: weekProg[i].$1 / maxDone),
                            duration: Duration(milliseconds: 600 + i * 60),
                            curve: Curves.easeOutBack,
                            builder: (_, v, _) => Container(
                              height: 6 + 100 * v.clamp(0.0, 1.0),
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    pal.accent.withValues(alpha: 0.55),
                                    pal.accent,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('E').format(week[i]).substring(0, 1),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: i == 6 ? pal.accent : pal.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            title: 'Focus minutes this week',
            trailing: focusTotal == 0 ? null : _fmtFocus(focusTotal),
            child: focusTotal == 0
                ? Row(
                    children: [
                      Icon(Icons.timer_outlined, color: pal.muted, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Long-press a task and choose Focus to start a session.',
                          style: TextStyle(color: pal.muted, height: 1.4),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 96,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < 7; i++)
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(
                                        end: weekFocus[i] / maxFocus,
                                      ),
                                      duration: Duration(
                                        milliseconds: 600 + i * 60,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      builder: (_, v, _) => Container(
                                        height: 4 + 64 * v.clamp(0.0, 1.0),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: weekFocus[i] == 0
                                              ? pal.cardAlt
                                              : const Color(0xFF10B981)
                                                    .withValues(
                                                      alpha: 0.35 + 0.65 * v,
                                                    ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      DateFormat('E')
                                          .format(week[i])
                                          .substring(0, 1),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: i == 6 ? pal.accent : pal.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (topFocus != null) ...[
                        const SizedBox(height: 14),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: '🎯  Most focus: '),
                              TextSpan(
                                text: topFocus.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: ' · ${_fmtFocus(topFocusMin)}',
                                style: TextStyle(color: pal.muted),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          if (isPro)
            insights
          else
            GestureDetector(
              onTap: () => showPaywall(
                context,
                reason:
                    'See your priority breakdown, best days and focus areas.',
              ),
              child: Stack(
                children: [
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                    child: IgnorePointer(child: insights),
                  ),
                  Positioned.fill(
                    child: Center(
                      child:
                          Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: pal.card,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: softShadow(context),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      color: pal.accent,
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Deeper insights with Pro',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap to unlock',
                                      style: TextStyle(
                                        color: pal.accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scaleXY(
                                end: 1.04,
                                duration: 1200.ms,
                                curve: Curves.easeInOut,
                              ),
                    ),
                  ),
                ],
              ),
            ),
        ].animate(interval: 60.ms).fadeIn(duration: 300.ms).slideY(begin: 0.06),
      ),
    );
  }
}

String _fmtFocus(int m) {
  if (m < 60) return '$m min';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '${h}h' : '${h}h ${r}m';
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label, this.big = false});
  final String value;
  final String label;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(T.r),
          border: Border.all(color: pal.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: big ? 28 : 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: pal.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(T.r),
        border: Border.all(color: pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    color: pal.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
