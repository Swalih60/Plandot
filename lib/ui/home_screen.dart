import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../services/pro_service.dart';
import '../services/reminders.dart';
import '../util/dates.dart';
import 'focus_screen.dart';
import 'paywall_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'task_editor.dart';
import 'theme.dart';
import 'widgets/confetti.dart';
import 'widgets/day_header.dart';
import 'widgets/task_tile.dart';
import 'widgets/timeline_view.dart';
import '../services/sounds.dart';
import 'root_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _day = dateOnly(DateTime.now());
  TaskFilter _filter = TaskFilter.all;
  bool _showDone = true;
  bool _allOverdue = false;
  final _confetti = ConfettiController();
  final Set<String> _celebrated = {};

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _toggle(Task t, DateTime day) {
    final store = context.read<TaskStore>();
    final before = store.progressOn(day);
    store.toggleDone(t, day);
    final (done, total) = store.progressOn(day);
    final k = dayKey(day);
    if (total > 0 &&
        done == total &&
        before.$1 < total &&
        !_celebrated.contains(k)) {
      _celebrated.add(k);
      HapticFeedback.heavyImpact();
      Sounds.instance.play(Sfx.allDone);
      _confetti.fire();
    }
    // Soft paywall right after the first "aha" moment: a completed task.
    if (t.isDoneOn(day) &&
        !store.paywallSeen &&
        !context.read<ProService>().isPro) {
      store.markPaywallSeen();
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          showPaywall(
            context,
            reason: 'Nice — first task done! Unlock repeating tasks, insights and themes.',
          );
        }
      });
    }
  }

  void _delete(Task t) {
    final store = context.read<TaskStore>();
    Reminders.instance.cancelFor(t);
    store.delete(t);
    Sounds.instance.play(Sfx.delete);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${t.title}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              store.restore(t);
              Reminders.instance.scheduleFor(t);
            },
          ),
        ),
      );
  }

  void _tomorrow(Task t) {
    final store = context.read<TaskStore>();
    final from = t.date;
    store.moveTo(t, addDays(dateOnly(DateTime.now()), 1));
    Reminders.instance.scheduleFor(t);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Moved to tomorrow'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => store.moveTo(t, from),
          ),
        ),
      );
  }

  void _toList(Task t) {
    final store = context.read<TaskStore>();
    final (date, repeat, remind, done) = (
      t.date,
      t.repeat,
      t.remind,
      {...t.doneDays},
    );
    Reminders.instance.cancelFor(t);
    store.moveToList(t);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Moved to your Tasks list'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              store.moveTo(t, date);
              t
                ..repeat = repeat
                ..remind = remind
                ..doneDays.addAll(done);
              store.update(t);
              Reminders.instance.scheduleFor(t);
            },
          ),
        ),
      );
  }

  Future<void> _setTimeline(bool v) async {
    final store = context.read<TaskStore>();
    if (v && !context.read<ProService>().isPro) {
      final ok = await showPaywall(
        context,
        reason: 'See your day as a timeline with Plandot Pro.',
      );
      if (!ok) return;
    }
    HapticFeedback.selectionClick();
    store.setTimelineView(v);
  }

  Widget _tile(Task t, DateTime day, int i, {bool showDate = false}) {
    return Padding(
          key: ValueKey('${dayKey(day)}-${t.id}-${t.isDoneOn(day)}'),
          padding: const EdgeInsets.only(bottom: 10),
          child: TaskTile(
            task: t,
            day: day,
            showDate: showDate,
            onToggle: () => _toggle(t, day),
            onOpen: () => showTaskEditor(context, task: t, day: day),
            onDelete: () => _delete(t),
            onTomorrow: () => _tomorrow(t),
            onToList: () => _toList(t),
            onFocus: () => openFocus(context, t, day),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: (i * 45).ms)
        .slideY(
          begin: 0.12,
          curve: Curves.easeOutCubic,
          duration: 360.ms,
          delay: (i * 45).ms,
        );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final pal = context.pal;
    final today = dateOnly(DateTime.now());
    final isToday = isSameDay(_day, today);
    final open = store.openOn(_day, filter: _filter);
    final done = store.doneOn(_day, filter: _filter);
    final overdue = isToday ? store.overdue(filter: _filter) : const <Task>[];
    final (d, t) = store.progressOn(_day);
    final all = store.tasksOn(_day);
    int count(Priority p) => all.where((x) => x.priority == p).length;
    final note = store.dayNote(_day);
    final timeline = context.watch<ProService>().isPro && store.timelineView;

    return Scaffold(
      // Lifted above the floating Today/Tasks bar.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: ShellScope.fabLift(context)),
        child: _AddButton(onTap: () => showTaskEditor(context, day: _day)),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isToday
                                    ? _greeting
                                    : DateFormat('EEEE').format(_day),
                                style: TextStyle(
                                  color: pal.muted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isToday
                                    ? 'Today, ${DateFormat('d MMM').format(_day)}'
                                    : DateFormat('d MMMM yyyy').format(_day),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: T.fast,
                          child: isToday
                              ? const SizedBox.shrink()
                              : TextButton(
                                  onPressed: () => setState(() => _day = today),
                                  child: const Text('Today'),
                                ),
                        ),
                        _RoundIcon(
                          icon: Icons.search_rounded,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SearchScreen(),
                            ),
                          ),
                        ),
                        _RoundIcon(
                          icon: Icons.bar_chart_rounded,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const StatsScreen(),
                            ),
                          ),
                        ),
                        _RoundIcon(
                          icon: Icons.tune_rounded,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: WeekStrip(
                  selected: _day,
                  mondayFirst: store.mondayFirst,
                  progress: store.progressOn,
                  onSelect: (x) => setState(() => _day = x),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                sliver: SliverToBoxAdapter(
                  child:
                      ProgressCard(
                            done: d,
                            total: t,
                            isToday: isToday,
                            streak: store.perfectDayStreak(),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .scaleXY(
                            begin: 0.96,
                            curve: Curves.easeOutCubic,
                            duration: 400.ms,
                          ),
                ),
              ),
              // Four equal chips: always all visible, even on narrow phones.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: _FilterChip(
                            label: 'All',
                            count: all.length,
                            selected: _filter == TaskFilter.all,
                            color: pal.ink,
                            onTap: () =>
                                setState(() => _filter = TaskFilter.all),
                          ),
                        ),
                        Expanded(
                          flex: 8,
                          child: _FilterChip(
                            label: 'High',
                            count: count(Priority.high),
                            selected: _filter == TaskFilter.high,
                            color: priorityColor(Priority.high),
                            onTap: () =>
                                setState(() => _filter = TaskFilter.high),
                          ),
                        ),
                        Expanded(
                          flex: 10,
                          child: _FilterChip(
                            label: 'Medium',
                            count: count(Priority.medium),
                            selected: _filter == TaskFilter.medium,
                            color: priorityColor(Priority.medium),
                            onTap: () =>
                                setState(() => _filter = TaskFilter.medium),
                          ),
                        ),
                        Expanded(
                          flex: 8,
                          child: _FilterChip(
                            label: 'Low',
                            count: count(Priority.low),
                            selected: _filter == TaskFilter.low,
                            color: priorityColor(Priority.low),
                            onTap: () =>
                                setState(() => _filter = TaskFilter.low),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (overdue.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Overdue',
                  count: overdue.length,
                  color: priorityColor(Priority.high),
                  action: 'Move to today',
                  onAction: () {
                    HapticFeedback.mediumImpact();
                    final n = store.moveOverdueToToday();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Moved $n task${n == 1 ? '' : 's'} to today',
                        ),
                      ),
                    );
                  },
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.list(
                    children: [
                      for (
                        var i = 0;
                        i <
                            (_allOverdue
                                ? overdue.length
                                : overdue.length.clamp(0, 3));
                        i++
                      )
                        _tile(overdue[i], overdue[i].date, i, showDate: true),
                      if (overdue.length > 3)
                        Center(
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => _allOverdue = !_allOverdue),
                            icon: AnimatedRotation(
                              turns: _allOverdue ? 0.5 : 0,
                              duration: T.med,
                              child: const Icon(Icons.expand_more_rounded),
                            ),
                            label: Text(
                              _allOverdue
                                  ? 'Show less'
                                  : 'Show ${overdue.length - 3} more',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (timeline || open.isNotEmpty || done.isNotEmpty)
                _SectionHeader(
                  title: timeline ? 'Schedule' : 'To do',
                  count: timeline ? all.length : open.length,
                  trailing: _ViewToggle(
                    timeline: timeline,
                    onChanged: _setTimeline,
                  ),
                ),
              if (timeline)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  sliver: SliverToBoxAdapter(
                    child: DayTimeline(
                      key: const ValueKey('timeline'),
                      day: _day,
                      tasks: store.tasksOn(_day, filter: _filter),
                      onOpen: (x) =>
                          showTaskEditor(context, task: x, day: _day),
                      onToggle: (x) => _toggle(x, _day),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.list(
                  children: [
                    if (!timeline)
                      for (var i = 0; i < open.length; i++)
                        _tile(open[i], _day, i),
                  ],
                ),
              ),
              if (!timeline && open.isEmpty && done.isEmpty && overdue.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyState(filtered: _filter != TaskFilter.all),
                ),
              if (!timeline && open.isEmpty && done.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(
                      'Everything here is done. Enjoy the calm ✨',
                      style: TextStyle(
                        color: pal.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ).animate().fadeIn(),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _DayNoteCard(
                    note: note,
                    onTap: () => _editNote(store),
                  ),
                ),
              ),
              if (!timeline && done.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Completed',
                  count: done.length,
                  action: _showDone ? 'Hide' : 'Show',
                  onAction: () => setState(() => _showDone = !_showDone),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: AnimatedSize(
                      duration: T.med,
                      curve: T.ease,
                      alignment: Alignment.topCenter,
                      child: _showDone
                          ? Column(
                              children: [
                                for (var i = 0; i < done.length; i++)
                                  _tile(done[i], _day, i),
                              ],
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 190)),
            ],
          ),
          Positioned.fill(
            child: Confetti(
              controller: _confetti,
              colors: [
                pal.accent,
                priorityColor(Priority.high),
                priorityColor(Priority.medium),
                priorityColor(Priority.low),
                const Color(0xFF10B981),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNote(TaskStore store) async {
    final ctrl = TextEditingController(text: store.dayNote(_day));
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(ctx).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Note for ${DateFormat('EEEE, d MMM').format(_day)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 8,
              minLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Thoughts, wins, ideas, reflections…',
                filled: true,
                fillColor: ctx.pal.cardAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Save note'),
            ),
          ],
        ),
      ),
    );
    store.setDayNote(_day, ctrl.text);
    ctrl.dispose();
  }
}

/// List ⇄ timeline switch with a sliding thumb.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.timeline, required this.onChanged});
  final bool timeline;
  final ValueChanged<bool> onChanged;

  static const _s = 34.0;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    Widget seg(bool v, IconData icon, String label) => Semantics(
      key: Key(v ? 'view-timeline' : 'view-list'),
      button: true,
      selected: timeline == v,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (timeline != v) onChanged(v);
        },
        child: SizedBox.square(
          dimension: _s,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: timeline == v ? Colors.white : pal.muted),
            duration: T.med,
            builder: (_, c, _) => Icon(icon, size: 18, color: c),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: pal.line),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            left: timeline ? _s : 0,
            top: 0,
            width: _s,
            height: _s,
            child: Container(
              decoration: BoxDecoration(
                color: pal.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: pal.accent.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              seg(false, Icons.view_agenda_rounded, 'List view'),
              seg(true, Icons.view_timeline_rounded, 'Timeline view'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: pal.card,
        shape: CircleBorder(side: BorderSide(color: pal.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 21, color: pal.ink),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fg = selected ? (color == pal.ink ? pal.bg : Colors.white) : pal.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: T.med,
          curve: T.ease,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? color : pal.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? color : pal.line),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (color != pal.ink) ...[
                  AnimatedContainer(
                    duration: T.med,
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fg,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: fg.withValues(alpha: 0.6),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    this.color,
    this.action,
    this.onAction,
    this.trailing,
  });
  final String title;
  final int count;
  final Color? color;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: color ?? pal.muted,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: (color ?? pal.muted).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: color ?? pal.muted,
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (action != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: color ?? pal.accent,
                ),
                child: Text(
                  action!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            if (trailing != null) ...[const Spacer(), trailing!],
          ],
        ),
      ),
    );
  }
}

class _DayNoteCard extends StatelessWidget {
  const _DayNoteCard({required this.note, required this.onTap});
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Material(
      color: pal.dark ? const Color(0xFF1E1B14) : const Color(0xFFFFF8E6),
      borderRadius: BorderRadius.circular(T.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(T.r),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📝', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Note for the day',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: pal.dark
                            ? const Color(0xFFF5D88A)
                            : const Color(0xFF8A6100),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note.isEmpty
                          ? 'Tap to jot down thoughts, wins or ideas'
                          : note,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: note.isEmpty ? pal.muted : pal.ink,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
      child: Column(
        children: [
          Text(filtered ? '🔍' : '☀️', style: const TextStyle(fontSize: 54))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: -4,
                end: 4,
                duration: 2.seconds,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 12),
          Text(
            filtered ? 'No tasks with this priority' : 'Your day is wide open',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            filtered
                ? 'Try another filter.'
                : 'Add a task — try typing "Gym tomorrow 7am !high"',
            textAlign: TextAlign.center,
            style: TextStyle(color: pal.muted, height: 1.4),
          ),
        ].animate(interval: 80.ms).fadeIn(duration: 350.ms).slideY(begin: 0.15),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.9 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: pal.accent,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: pal.accent.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
        ),
      ),
    ).animate().scaleXY(
      begin: 0,
      duration: 450.ms,
      curve: Curves.easeOutBack,
      delay: 200.ms,
    );
  }
}
