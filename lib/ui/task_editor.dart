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
import '../util/quick_parse.dart';
import 'focus_screen.dart';
import 'paywall_screen.dart';
import 'theme.dart';

/// Opens the add/edit sheet. Returns the saved task (or null).
Future<Task?> showTaskEditor(
  BuildContext context, {
  Task? task,
  required DateTime day,
  bool anytime = false,
}) {
  return showModalBottomSheet<Task>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TaskEditor(task: task, day: day, anytime: anytime),
  );
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({
    super.key,
    this.task,
    required this.day,
    this.anytime = false,
  });
  final Task? task;
  final DateTime day;

  /// New task goes to the Tasks list (no particular day) by default.
  final bool anytime;

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late final _notes = TextEditingController(text: widget.task?.notes ?? '');
  final _subCtrl = TextEditingController();
  late Priority _priority = widget.task?.priority ?? Priority.none;
  late DateTime _date = widget.task?.date ?? widget.day;
  late bool _anytime = widget.task?.anytime ?? widget.anytime;
  late int? _time = widget.task?.timeMinutes;
  late String? _tag = widget.task?.tag;
  late Repeat _repeat = widget.task?.repeat ?? Repeat.none;
  late bool _remind = widget.task?.remind ?? false;
  late final List<Subtask> _subs = [
    for (final s in widget.task?.subtasks ?? const <Subtask>[])
      Subtask(id: s.id, title: s.title, done: s.done),
  ];
  bool _showMore = false;
  ParsedTask? _parsed;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    _showMore = _editing;
    if (!_editing) _title.addListener(_reparse);
  }

  void _reparse() {
    final p = parseQuickAdd(_title.text);
    setState(() => _parsed = p.hasTokens ? p : null);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _subCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    var title = _title.text.trim();
    var date = _date, time = _time, priority = _priority, tag = _tag;
    var anytime = _anytime;
    final p = _parsed;
    if (!_editing && p != null) {
      title = p.title;
      if (p.anytime) anytime = true;
      if (p.date != null) anytime = false;
      date = p.date ?? date;
      time = p.timeMinutes ?? time;
      priority = p.priority ?? priority;
      tag = p.tag ?? tag;
    }
    if (title.isEmpty) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (_subCtrl.text.trim().isNotEmpty) _addSub();
    final store = context.read<TaskStore>();
    if (anytime) {
      // Tasks-list items have no day, so no time, repeat or reminder.
      time = null;
      _repeat = Repeat.none;
    }
    final remind = !anytime && _remind && time != null;
    if (remind) await Reminders.instance.requestPermission();
    Task t;
    if (_editing) {
      final old = widget.task!;
      if (old.anytime != anytime) old.doneDays.clear();
      t = old
        ..anytime = anytime
        ..title = title
        ..notes = _notes.text.trim()
        ..priority = priority
        ..date = dateOnly(date)
        ..timeMinutes = time
        ..tag = tag
        ..repeat = _repeat
        ..remind = remind;
      t.subtasks
        ..clear()
        ..addAll(_subs);
      store.update(t);
    } else {
      t = store.addTask(
        title: title,
        date: date,
        notes: _notes.text.trim(),
        priority: priority,
        timeMinutes: time,
        tag: tag,
        repeat: _repeat,
        remind: remind,
        anytime: anytime,
        subtasks: _subs,
      );
    }
    await Reminders.instance.scheduleFor(t);
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop(t);
  }

  void _addSub() {
    final s = _subCtrl.text.trim();
    if (s.isEmpty) return;
    setState(() {
      _subs.add(Subtask(id: TaskStore.newId(), title: s));
      _subCtrl.clear();
    });
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.today_rounded),
              title: const Text('Today'),
              onTap: () => Navigator.pop(ctx, 'today'),
            ),
            ListTile(
              leading: const Icon(Icons.wb_twilight_rounded),
              title: const Text('Tomorrow'),
              onTap: () => Navigator.pop(ctx, 'tomorrow'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded),
              title: const Text('Pick a date…'),
              onTap: () => Navigator.pop(ctx, 'pick'),
            ),
            ListTile(
              leading: Icon(Icons.inbox_rounded, color: ctx.pal.accent),
              title: const Text('No date · Tasks list'),
              subtitle: const Text('Stays on your list until it\'s done'),
              onTap: () => Navigator.pop(ctx, 'none'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    HapticFeedback.selectionClick();
    switch (choice) {
      case 'today':
        setState(() {
          _anytime = false;
          _date = today;
        });
      case 'tomorrow':
        setState(() {
          _anytime = false;
          _date = addDays(today, 1);
        });
      case 'none':
        setState(() => _anytime = true);
      case 'pick':
        final d = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (d != null) {
          setState(() {
            _anytime = false;
            _date = d;
          });
        }
    }
  }

  Future<void> _pickTime() async {
    final init = _time ?? 9 * 60;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: init ~/ 60, minute: init % 60),
    );
    if (t != null) {
      setState(() {
        _time = t.hour * 60 + t.minute;
        _remind = true;
      });
    }
  }

  Future<void> _pickRepeat() async {
    final pro = context.read<ProService>();
    if (!pro.isPro) {
      final ok = await showPaywall(
        context,
        reason: 'Repeating tasks are part of Plandot Pro.',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    final r = await showModalBottomSheet<Repeat>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in Repeat.values)
              ListTile(
                title: Text(
                  r == Repeat.weekly
                      ? 'Every ${DateFormat('EEEE').format(_date)}'
                      : r.label,
                ),
                trailing: r == _repeat ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, r),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (r != null) setState(() => _repeat = r);
  }

  String _dateLabel(DateTime d) {
    final diff = dateOnly(d).difference(dateOnly(DateTime.now())).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('EEE, d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final p = _parsed;
    final effPriority = (!_editing ? p?.priority : null) ?? _priority;
    final effDate = (!_editing ? p?.date : null) ?? _date;
    final effAnytime = !_editing && p != null
        ? (p.date != null ? false : (p.anytime || _anytime))
        : _anytime;
    final effTime = (!_editing ? p?.timeMinutes : null) ?? _time;
    final effTag = (!_editing ? p?.tag : null) ?? _tag;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _editing
                  ? 'Edit task'
                  : (_anytime ? 'New task · Tasks list' : 'New task'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: pal.muted,
                letterSpacing: 0.4,
              ),
            ),
            TextField(
              controller: _title,
              autofocus: !_editing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              maxLines: null,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _editing
                    ? 'Task name'
                    : 'Try "Gym tomorrow 7am !high"',
                hintStyle: TextStyle(color: pal.muted.withValues(alpha: 0.6)),
              ),
            ),
            // Live preview of what the quick-add parser understood.
            AnimatedSize(
              duration: T.med,
              curve: T.ease,
              child: p == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            [
                                  if (p.date != null)
                                    _Token('📅 ${_dateLabel(p.date!)}'),
                                  if (p.anytime) const _Token('📥 Tasks list'),
                                  if (p.timeMinutes != null)
                                    _Token(
                                      '⏰ ${formatMinutes(p.timeMinutes!)}',
                                    ),
                                  if (p.priority != null)
                                    _Token(
                                      '● ${p.priority!.label}',
                                      color: priorityColor(p.priority!),
                                    ),
                                  if (p.tag != null)
                                    _Token(
                                      '${tagByName(p.tag)!.emoji} ${p.tag}',
                                    ),
                                ]
                                .animate(interval: 40.ms)
                                .fadeIn(duration: 200.ms)
                                .scaleXY(begin: 0.8, curve: Curves.easeOutBack),
                      ),
                    ),
            ),
            TextField(
              controller: _notes,
              maxLines: null,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                fontSize: 15,
                color: pal.ink.withValues(alpha: 0.85),
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Add notes',
                hintStyle: TextStyle(color: pal.muted.withValues(alpha: 0.6)),
                prefixIcon: Icon(
                  Icons.notes_rounded,
                  size: 18,
                  color: pal.muted,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 28),
              ),
            ),
            const SizedBox(height: 14),
            _PriorityPicker(
              value: effPriority,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() {
                  _priority = v;
                  if (_parsed?.priority != null) {
                    _title.text = _title.text
                        .replaceAll(RegExp(r'(^|\s)!\S*'), '')
                        .trim();
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Pill(
                    icon: effAnytime
                        ? Icons.inbox_rounded
                        : Icons.event_rounded,
                    label: effAnytime ? 'No date' : _dateLabel(effDate),
                    active: true,
                    onTap: _pickDate,
                  ),
                  if (!effAnytime)
                    _Pill(
                      icon: Icons.schedule_rounded,
                      label: effTime == null ? 'Time' : formatMinutes(effTime),
                      active: effTime != null,
                      onTap: _pickTime,
                      onClear: effTime == null
                          ? null
                          : () => setState(() {
                              _time = null;
                              _remind = false;
                            }),
                    ),
                  _Pill(
                    icon: Icons.local_offer_rounded,
                    label: effTag ?? 'Tag',
                    active: effTag != null,
                    onTap: () => setState(() => _showMore = true),
                  ),
                  if (!effAnytime)
                    _Pill(
                      icon: Icons.repeat_rounded,
                      label: _repeat == Repeat.none ? 'Repeat' : _repeat.label,
                      active: _repeat != Repeat.none,
                      onTap: _pickRepeat,
                    ),
                ],
              ),
            ),
            AnimatedSize(
              duration: T.med,
              curve: T.ease,
              alignment: Alignment.topCenter,
              child: !_showMore
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showMore = true),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const Text('More options'),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _Label('TAG'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in builtInTags)
                              ChoiceChip(
                                label: Text('${t.emoji} ${t.name}'),
                                selected: effTag == t.name,
                                showCheckmark: false,
                                selectedColor: tagColors[t.color].withValues(
                                  alpha: 0.2,
                                ),
                                side: BorderSide(
                                  color: effTag == t.name
                                      ? tagColors[t.color]
                                      : pal.line,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                onSelected: (v) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _tag = v ? t.name : null);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _Label('SUBTASKS'),
                        for (final s in _subs)
                          Row(
                                key: ValueKey(s.id),
                                children: [
                                  Checkbox(
                                    value: s.done,
                                    shape: const CircleBorder(),
                                    onChanged: (v) =>
                                        setState(() => s.done = v!),
                                  ),
                                  Expanded(
                                    child: Text(
                                      s.title,
                                      style: TextStyle(
                                        decoration: s.done
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: s.done ? pal.muted : pal.ink,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        setState(() => _subs.remove(s)),
                                  ),
                                ],
                              )
                              .animate()
                              .fadeIn(duration: 200.ms)
                              .slideX(begin: 0.05),
                        TextField(
                          controller: _subCtrl,
                          onSubmitted: (_) => _addSub(),
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Add a step',
                            prefixIcon: Icon(
                              Icons.add_rounded,
                              color: pal.accent,
                            ),
                          ),
                        ),
                        if (_time != null && !effAnytime)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Remind me',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text('At ${formatMinutes(_time!)}'),
                            value: _remind,
                            onChanged: (v) => setState(() => _remind = v),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_editing) ...[
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      minimumSize: const Size(56, 56),
                      foregroundColor: priorityColor(Priority.high),
                    ),
                    onPressed: () async {
                      final store = context.read<TaskStore>();
                      await Reminders.instance.cancelFor(widget.task!);
                      store.delete(widget.task!);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    key: const Key('editor-focus'),
                    tooltip: 'Focus',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(56, 56),
                      foregroundColor: pal.accent,
                    ),
                    onPressed: () {
                      // Close the sheet, then open focus from the navigator.
                      final nav = Navigator.of(context);
                      final task = widget.task!;
                      nav.pop();
                      openFocus(nav.context, task, widget.day);
                    },
                    icon: const Icon(Icons.timer_outlined),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ListenableBuilder(
                    listenable: _title,
                    builder: (context, _) => FilledButton(
                      onPressed: _title.text.trim().isEmpty ? null : _save,
                      child: Text(_editing ? 'Save changes' : 'Add task'),
                    ),
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: context.pal.muted,
      ),
    ),
  );
}

class _Token extends StatelessWidget {
  const _Token(this.text, {this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pal.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: active ? pal.accent.withValues(alpha: 0.12) : pal.cardAlt,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: active ? pal.accent : pal.muted),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: active ? pal.accent : pal.ink,
                  ),
                ),
                if (onClear != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: pal.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.value, required this.onChanged});
  final Priority value;
  final ValueChanged<Priority> onChanged;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    const order = [Priority.high, Priority.medium, Priority.low, Priority.none];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pal.cardAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / order.length;
          final i = order.indexOf(value);
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeOutBack,
                left: i * w,
                top: 0,
                bottom: 0,
                width: w,
                child: AnimatedContainer(
                  duration: T.med,
                  decoration: BoxDecoration(
                    color: value == Priority.none
                        ? pal.card
                        : priorityColor(value),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: softShadow(context),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final p in order)
                    SizedBox(
                      width: w,
                      height: 42,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(p),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (p != Priority.none)
                                AnimatedContainer(
                                  duration: T.med,
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: p == value
                                        ? Colors.white
                                        : priorityColor(p),
                                  ),
                                ),
                              AnimatedDefaultTextStyle(
                                duration: T.fast,
                                style: TextStyle(
                                  fontFamily: 'Jakarta',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: p == value && p != Priority.none
                                      ? Colors.white
                                      : pal.ink,
                                ),
                                child: Text(p.label),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
