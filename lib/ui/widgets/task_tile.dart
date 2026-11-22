import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/task.dart';
import '../../util/dates.dart';
import '../theme.dart';
import 'animated_check.dart';

/// A task row: priority accent, animated checkbox, self-drawing
/// strikethrough, metadata chips, and swipe actions
/// (→ complete, ← delete / reschedule).
class TaskTile extends StatefulWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.day,
    required this.onToggle,
    required this.onOpen,
    required this.onDelete,
    required this.onTomorrow,
    this.onFocus,
    this.showDate = false,
  });

  final Task task;
  final DateTime day;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onTomorrow;

  /// Opens the focus timer; the menu item is hidden when null.
  final VoidCallback? onFocus;
  final bool showDate;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  /// Visual state; flips immediately so the animation plays before the
  /// task actually moves to the other section.
  late bool _checked = widget.task.isDoneOn(widget.day);
  bool _pressed = false;
  bool _pending = false;

  @override
  void didUpdateWidget(TaskTile old) {
    super.didUpdateWidget(old);
    if (!_pending) _checked = widget.task.isDoneOn(widget.day);
  }

  void _toggle(bool v) {
    setState(() {
      _checked = v;
      _pending = true;
    });
    // Give the check + strikethrough time to play before the row moves.
    Future.delayed(const Duration(milliseconds: 560), () {
      _pending = false;
      if (widget.task.isDoneOn(widget.day) != v) widget.onToggle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final pal = context.pal;
    final pc = priorityColor(t.priority);
    final tag = tagByName(t.tag);

    final chips = <Widget>[
      if (widget.showDate)
        _Chip(
          icon: Icons.event_rounded,
          label: _relDate(t.date),
          color: t.isOverdue(DateTime.now()) ? priorityColor(Priority.high) : null,
        ),
      if (t.timeMinutes != null)
        _Chip(
          icon: t.remind ? Icons.notifications_active_rounded : Icons.schedule_rounded,
          label: formatMinutes(t.timeMinutes!),
        ),
      if (tag != null) _Chip(emoji: tag.emoji, label: tag.name, color: tagColors[tag.color]),
      if (t.subtasks.isNotEmpty)
        _Chip(
          icon: Icons.checklist_rounded,
          label: '${t.subtasksDone}/${t.subtasks.length}',
        ),
      if (t.focusOn(widget.day) > 0)
        _Chip(
          icon: Icons.timer_outlined,
          label: '${t.focusOn(widget.day)}m',
          color: pc == priorityColor(Priority.none) ? pal.accent : pc,
        ),
      if (t.repeat != Repeat.none) _Chip(icon: Icons.repeat_rounded, label: t.repeat.label),
      if (t.notes.isNotEmpty) const _Chip(icon: Icons.notes_rounded),
    ];

    final card = AnimatedScale(
      scale: _pressed ? 0.975 : 1,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: T.med,
        curve: T.ease,
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(T.r),
          border: Border.all(color: pal.line),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(T.r),
            onTap: widget.onOpen,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedContainer(
                    duration: T.med,
                    width: 4,
                    margin: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: t.priority == Priority.none
                          ? Colors.transparent
                          : pc.withValues(alpha: _checked ? 0.3 : 1),
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(4)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 6),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: AnimatedCheck(
                        checked: _checked,
                        color: t.priority == Priority.none ? pal.accent : pc,
                        onChanged: _toggle,
                        size: 26,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(2, 15, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          StrikeText(
                            text: t.title,
                            struck: _checked,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: _checked ? pal.muted : pal.ink,
                            ),
                          ),
                          if (chips.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            AnimatedOpacity(
                              duration: T.med,
                              opacity: _checked ? 0.55 : 1,
                              child: Wrap(spacing: 6, runSpacing: 6, children: chips),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('dismiss-${t.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.35,
      },
      background: _SwipeBg(
        color: pal.accent,
        icon: _checked ? Icons.undo_rounded : Icons.check_rounded,
        label: _checked ? 'Undo' : 'Done',
        alignLeft: true,
      ),
      secondaryBackground: _SwipeBg(
        color: priorityColor(Priority.high),
        icon: Icons.delete_rounded,
        label: 'Delete',
        alignLeft: false,
      ),
      confirmDismiss: (dir) async {
        HapticFeedback.mediumImpact();
        if (dir == DismissDirection.startToEnd) {
          _toggle(!_checked);
          return false;
        }
        return true;
      },
      onDismissed: (_) => widget.onDelete(),
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.heavyImpact();
          _quickMenu(context);
        },
        child: card,
      ),
    );
  }

  void _quickMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onOpen();
              },
            ),
            if (widget.onFocus != null)
              ListTile(
                leading: Icon(Icons.timer_outlined, color: context.pal.accent),
                title: const Text('Focus'),
                subtitle: const Text('Start a focus session on this task'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onFocus!();
                },
              ),
            ListTile(
              leading: const Icon(Icons.wb_twilight_rounded),
              title: const Text('Move to tomorrow'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onTomorrow();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: priorityColor(Priority.high)),
              title: Text('Delete', style: TextStyle(color: priorityColor(Priority.high))),
              onTap: () {
                Navigator.pop(ctx);
                widget.onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

String _relDate(DateTime d) {
  final today = dateOnly(DateTime.now());
  final diff = dateOnly(d).difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]}';
}

/// Text with a strikethrough line that draws itself left → right.
class StrikeText extends StatelessWidget {
  const StrikeText({
    super.key,
    required this.text,
    required this.struck,
    required this.style,
  });
  final String text;
  final bool struck;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: struck ? 1 : 0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => CustomPaint(
        foregroundPainter: _StrikePainter(
          progress: v,
          text: text,
          style: style,
          color: style.color ?? Colors.grey,
        ),
        child: AnimatedDefaultTextStyle(
          duration: T.med,
          style: style,
          child: Text(text),
        ),
      ),
    );
  }
}

class _StrikePainter extends CustomPainter {
  _StrikePainter({
    required this.progress,
    required this.text,
    required this.style,
    required this.color,
  });
  final double progress;
  final String text;
  final TextStyle style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    final lines = tp.computeLineMetrics();
    final total = lines.fold<double>(0, (s, l) => s + l.width);
    var remaining = total * progress;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final l in lines) {
      if (remaining <= 0) break;
      final w = remaining.clamp(0, l.width).toDouble();
      final y = l.baseline - l.ascent * 0.32;
      canvas.drawLine(Offset(l.left, y), Offset(l.left + w, y), paint);
      remaining -= l.width;
    }
  }

  @override
  bool shouldRepaint(_StrikePainter o) =>
      o.progress != progress || o.text != text || o.color != color;
}

class _Chip extends StatelessWidget {
  const _Chip({this.icon, this.emoji, this.label, this.color});
  final IconData? icon;
  final String? emoji;
  final String? label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = color ?? pal.muted;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: label == null ? 6 : 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? pal.muted).withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 11)),
          if (icon != null) Icon(icon, size: 13, color: c),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(label!,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c)),
          ],
        ],
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignLeft,
  });
  final Color color;
  final IconData icon;
  final String label;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(T.r),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
