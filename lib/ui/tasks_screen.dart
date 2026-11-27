import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../services/reminders.dart';
import '../util/dates.dart';
import '../util/quick_parse.dart';
import 'focus_screen.dart';
import 'task_editor.dart';
import 'theme.dart';
import 'widgets/confetti.dart';
import 'widgets/task_tile.dart';
import '../services/sounds.dart';

/// The master Tasks list: things to do that don't belong to a particular
/// day. They stay here — never overdue — until they're done.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _quick = TextEditingController();
  final _focus = FocusNode();
  final _confetti = ConfettiController();
  TaskFilter _filter = TaskFilter.all;
  Priority _quickPriority = Priority.none;
  bool _showDone = false;

  @override
  void dispose() {
    _quick.dispose();
    _focus.dispose();
    _confetti.dispose();
    super.dispose();
  }

  DateTime get _today => dateOnly(DateTime.now());

  void _quickAdd() {
    final text = _quick.text.trim();
    if (text.isEmpty) return;
    final store = context.read<TaskStore>();
    final p = parseQuickAdd(text);
    final title = p.title.isEmpty ? text : p.title;
    final planned = p.date != null;
    final t = store.addTask(
      title: title,
      date: p.date ?? _today,
      priority: p.priority ?? _quickPriority,
      tag: p.tag,
      timeMinutes: planned ? p.timeMinutes : null,
      anytime: !planned,
    );
    if (planned) Reminders.instance.scheduleFor(t);
    HapticFeedback.lightImpact();
    Sounds.instance.play(Sfx.add);
    _quick.clear();
    setState(() => _quickPriority = Priority.none);
    if (planned) {
      _snack('Planned for ${_rel(p.date!)} — find it on Today');
    }
  }

  void _toggle(Task t) {
    final store = context.read<TaskStore>();
    final before = store.listOpenCount;
    store.toggleDone(t, _today);
    if (before > 0 && store.listOpenCount == 0) {
      HapticFeedback.heavyImpact();
      Sounds.instance.play(Sfx.allDone);
      _confetti.fire();
    }
  }

  void _plan(Task t, DateTime day) {
    final store = context.read<TaskStore>();
    store.moveTo(t, day);
    Reminders.instance.scheduleFor(t);
    _snack('Planned for ${_rel(day)}', undo: () => store.moveToList(t));
  }

  void _delete(Task t) {
    final store = context.read<TaskStore>();
    Reminders.instance.cancelFor(t);
    store.delete(t);
    Sounds.instance.play(Sfx.delete);
    _snack('Deleted "${t.title}"', undo: () => store.restore(t));
  }

  void _snack(String text, {VoidCallback? undo}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: undo == null
              ? null
              : SnackBarAction(label: 'Undo', onPressed: undo),
        ),
      );
  }

  String _rel(DateTime d) {
    final diff = dateOnly(d).difference(_today).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${m[d.month - 1]}';
  }

  Widget _tile(Task t, int i) =>
      Padding(
            key: ValueKey('list-${t.id}-${t.isComplete}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: TaskTile(
              task: t,
              day: _today,
              onToggle: () => _toggle(t),
              onOpen: () => showTaskEditor(context, task: t, day: _today),
              onDelete: () => _delete(t),
              onTomorrow: () => _plan(t, addDays(_today, 1)),
              onToday: t.isComplete ? null : () => _plan(t, _today),
              onFocus: () => openFocus(context, t, _today),
            ),
          )
          .animate()
          .fadeIn(duration: 300.ms, delay: (i * 40).ms)
          .slideY(
            begin: 0.12,
            curve: Curves.easeOutCubic,
            duration: 360.ms,
            delay: (i * 40).ms,
          );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final pal = context.pal;
    final open = store.listOpen(filter: _filter);
    final done = store.listDone(filter: _filter);
    final allOpen = store.listOpen();
    int count(Priority p) => allOpen.where((t) => t.priority == p).length;

    return Scaffold(
      floatingActionButton: _Fab(
        onTap: () => showTaskEditor(context, day: _today, anytime: true),
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => _focus.unfocus(),
            behavior: HitTestBehavior.translucent,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No date, no pressure',
                            style: TextStyle(
                              color: pal.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'My Tasks',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: AnimatedSwitcher(
                                  duration: T.fast,
                                  transitionBuilder: (c, a) =>
                                      ScaleTransition(scale: a, child: c),
                                  child: Text(
                                    '${allOpen.length} open',
                                    key: ValueKey(allOpen.length),
                                    style: TextStyle(
                                      color: pal.accent,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _QuickAddBar(
                      controller: _quick,
                      focusNode: _focus,
                      priority: _quickPriority,
                      onPriority: (p) {
                        HapticFeedback.selectionClick();
                        setState(
                          () => _quickPriority = _quickPriority == p
                              ? Priority.none
                              : p,
                        );
                      },
                      onSubmit: _quickAdd,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 58,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      children: [
                        _Chip(
                          'All',
                          allOpen.length,
                          pal.ink,
                          _filter == TaskFilter.all,
                          () => setState(() => _filter = TaskFilter.all),
                        ),
                        _Chip(
                          'High',
                          count(Priority.high),
                          priorityColor(Priority.high),
                          _filter == TaskFilter.high,
                          () => setState(() => _filter = TaskFilter.high),
                        ),
                        _Chip(
                          'Medium',
                          count(Priority.medium),
                          priorityColor(Priority.medium),
                          _filter == TaskFilter.medium,
                          () => setState(() => _filter = TaskFilter.medium),
                        ),
                        _Chip(
                          'Low',
                          count(Priority.low),
                          priorityColor(Priority.low),
                          _filter == TaskFilter.low,
                          () => setState(() => _filter = TaskFilter.low),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                if (open.isEmpty)
                  SliverToBoxAdapter(
                    child: _Empty(
                      filtered: _filter != TaskFilter.all,
                      allDone: done.isNotEmpty,
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.list(
                    children: [
                      for (var i = 0; i < open.length; i++) _tile(open[i], i),
                    ],
                  ),
                ),
                if (done.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Text(
                            'COMPLETED',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: pal.muted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${done.length}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: pal.muted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _showDone = !_showDone),
                            icon: AnimatedRotation(
                              turns: _showDone ? 0.5 : 0,
                              duration: T.med,
                              child: const Icon(Icons.expand_more_rounded),
                            ),
                            label: Text(_showDone ? 'Hide' : 'Show'),
                          ),
                          if (_showDone)
                            TextButton(
                              onPressed: () {
                                final removed = [...done];
                                for (final t in removed) {
                                  store.delete(t);
                                }
                                _snack(
                                  'Cleared ${removed.length} completed',
                                  undo: () {
                                    for (final t in removed) {
                                      store.restore(t);
                                    }
                                  },
                                );
                              },
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (done.isNotEmpty)
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
                                    _tile(done[i], i),
                                ],
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
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
}

class _QuickAddBar extends StatelessWidget {
  const _QuickAddBar({
    required this.controller,
    required this.focusNode,
    required this.priority,
    required this.onPriority,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final Priority priority;
  final ValueChanged<Priority> onPriority;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, focusNode]),
      builder: (context, _) {
        final active = focusNode.hasFocus || controller.text.isNotEmpty;
        final pc = priority == Priority.none
            ? pal.accent
            : priorityColor(priority);
        return AnimatedContainer(
          duration: T.med,
          curve: T.ease,
          padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? pc : pal.line,
              width: active ? 2 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: pc.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  AnimatedSwitcher(
                    duration: T.fast,
                    child: Icon(
                      active ? Icons.edit_rounded : Icons.add_rounded,
                      key: ValueKey(active),
                      color: pc,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        onSubmit();
                        focusNode.requestFocus();
                      },
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Add a task…',
                        hintStyle: TextStyle(color: pal.muted),
                      ),
                    ),
                  ),
                  AnimatedScale(
                    scale: controller.text.trim().isEmpty ? 0 : 1,
                    duration: T.med,
                    curve: Curves.easeOutBack,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: pc),
                      onPressed: onSubmit,
                      icon: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: T.med,
                curve: T.ease,
                child: !active
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 8, right: 8),
                        child: Row(
                          children: [
                            for (final p in [
                              Priority.high,
                              Priority.medium,
                              Priority.low,
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => onPriority(p),
                                  child: AnimatedContainer(
                                    duration: T.fast,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: priority == p
                                          ? priorityColor(p)
                                          : priorityColor(p)
                                                .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      p.label,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: priority == p
                                            ? Colors.white
                                            : priorityColor(p),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Text(
                              'Enter to add',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: pal.muted,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 200.ms),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.count, this.color, this.selected, this.onTap);
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fg = selected ? (color == pal.ink ? pal.bg : Colors.white) : pal.ink;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: T.med,
          curve: T.ease,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? color : pal.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? color : pal.line),
          ),
          child: Row(
            children: [
              if (color != pal.ink) ...[
                Container(
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
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filtered, required this.allDone});
  final bool filtered;
  final bool allDone;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final (emoji, title, body) = filtered
        ? ('🔍', 'Nothing with this priority', 'Try another filter.')
        : allDone
        ? ('🏆', 'List cleared!', 'Every task is done. Enjoy the feeling.')
        : (
            '📥',
            'Your list is empty',
            'Add things you need to do — no date needed. They stay here until they\'re done.',
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 16),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 54))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: -4,
                end: 4,
                duration: 2.seconds,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: pal.muted, height: 1.4),
          ),
        ].animate(interval: 80.ms).fadeIn(duration: 350.ms).slideY(begin: 0.15),
      ),
    );
  }
}

class _Fab extends StatefulWidget {
  const _Fab({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_Fab> createState() => _FabState();
}

class _FabState extends State<_Fab> {
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
    );
  }
}
