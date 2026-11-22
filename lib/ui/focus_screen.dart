import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../services/pro_service.dart';
import '../services/reminders.dart';
import '../util/dates.dart';
import 'paywall_screen.dart';
import 'theme.dart';
import 'widgets/confetti.dart';

/// Opens the focus timer for [task] (Pro). Shows the paywall first if needed.
Future<void> openFocus(BuildContext context, Task task, DateTime day) async {
  if (!context.read<ProService>().isPro) {
    final ok = await showPaywall(context,
        reason: 'Focus timer is part of Plandot Pro. Deep-work sessions on any '
            'task, logged to your insights.');
    if (!ok || !context.mounted) return;
  }
  HapticFeedback.mediumImpact();
  await Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: T.slow,
    reverseTransitionDuration: T.med,
    pageBuilder: (_, _, _) => FocusScreen(task: task, day: day),
    transitionsBuilder: (_, a, _, child) {
      final c = CurvedAnimation(parent: a, curve: T.ease);
      return FadeTransition(
        opacity: c,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(c),
          child: child,
        ),
      );
    },
  ));
}

enum _Phase { focus, rest }

const _restColor = Color(0xFF10B981);

/// Full-screen Pomodoro timer for one task. Time is derived from wall-clock
/// timestamps, so it stays correct while the app is in the background.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, required this.task, required this.day});
  final Task task;

  /// The day the task was opened from (used for "mark done").
  final DateTime day;

  static const presets = [15, 25, 45, 60];

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _minutes = 25;
  _Phase _phase = _Phase.focus;

  /// Start of the current running segment; null while paused or idle.
  DateTime? _startedAt;

  /// Time elapsed in earlier segments of this session (before a pause).
  Duration _banked = Duration.zero;
  bool _finished = false;
  bool _logged = false;
  bool _breakOver = false;

  late final Ticker _ticker = createTicker((_) => _tick());
  final _elapsedN = ValueNotifier<Duration>(Duration.zero);
  late final AnimationController _breath = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 4000));
  final _confetti = ConfettiController();
  late final TaskStore _store;

  bool get _running => _startedAt != null;
  bool get _started => _running || _banked > Duration.zero;
  int get _breakMinutes => _minutes >= 45 ? 10 : 5;
  Duration get _total =>
      Duration(minutes: _phase == _Phase.focus ? _minutes : _breakMinutes);
  Color get _color => _phase == _Phase.rest
      ? _restColor
      : widget.task.priority == Priority.none
          ? context.pal.accent
          : priorityColor(widget.task.priority);

  Duration _elapsed() =>
      _banked +
      (_startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!));

  @override
  void initState() {
    super.initState();
    _store = context.read<TaskStore>();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      if (_running) {
        final end = _startedAt!.add(_total - _banked);
        Reminders.instance.scheduleFocusEnd(
          end,
          _phase == _Phase.focus ? 'Focus session complete 🎉' : 'Break is over',
          _phase == _Phase.focus
              ? '$_minutes minutes on "${widget.task.title}". Nicely done.'
              : 'Ready for another round?',
        );
      }
    } else if (s == AppLifecycleState.resumed) {
      Reminders.instance.cancelFocusEnd();
      if (_running) _tick();
    }
  }

  void _tick() {
    final e = _elapsed();
    if (e >= _total) {
      _complete();
    } else {
      _elapsedN.value = e;
    }
  }

  void _start() {
    HapticFeedback.mediumImpact();
    setState(() {
      _finished = false;
      _breakOver = false;
      if (!_started) _logged = false;
      _startedAt = DateTime.now();
    });
    if (!_ticker.isActive) _ticker.start();
    _breath.repeat(reverse: true);
  }

  void _pause() {
    HapticFeedback.selectionClick();
    setState(() {
      _banked = _elapsed();
      _startedAt = null;
    });
    _ticker.stop();
    _breath.animateTo(0, duration: T.slow, curve: T.ease);
  }

  void _reset({_Phase phase = _Phase.focus}) {
    _ticker.stop();
    _breath.animateTo(0, duration: T.slow, curve: T.ease);
    _startedAt = null;
    _banked = Duration.zero;
    _phase = phase;
    _elapsedN.value = Duration.zero;
  }

  /// Logs whole focus minutes of the current session (once).
  void _logFocus(int minutes) {
    if (_phase != _Phase.focus || _logged) return;
    _logged = true;
    _store.addFocusMinutes(widget.task, dateOnly(DateTime.now()), minutes);
  }

  void _stop() {
    HapticFeedback.mediumImpact();
    _logFocus(_elapsed().inMinutes);
    setState(() => _reset());
  }

  void _complete() {
    _ticker.stop();
    _breath.animateTo(0, duration: T.slow, curve: T.ease);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 180), HapticFeedback.heavyImpact);
    if (_phase == _Phase.focus) {
      _logFocus(_minutes);
      _elapsedN.value = _total;
      setState(() {
        _startedAt = null;
        _banked = _total;
        _finished = true;
      });
      _confetti.fire();
    } else {
      setState(() {
        _reset();
        _breakOver = true;
      });
    }
  }

  void _startBreak() {
    setState(() => _reset(phase: _Phase.rest));
    _start();
  }

  void _markDone() {
    HapticFeedback.mediumImpact();
    if (_started && !_finished) _logFocus(_elapsed().inMinutes);
    if (!widget.task.isDoneOn(widget.day)) {
      _store.toggleDone(widget.task, widget.day);
    }
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Reminders.instance.cancelFocusEnd();
    if (_phase == _Phase.focus && _started && !_logged) {
      // Leaving mid-session still counts. Deferred so listeners don't rebuild
      // while the tree is locked.
      final mins = _elapsed().inMinutes, store = _store, task = widget.task;
      scheduleMicrotask(
          () => store.addFocusMinutes(task, dateOnly(DateTime.now()), mins));
    }
    _ticker.dispose();
    _breath.dispose();
    _elapsedN.dispose();
    _confetti.dispose();
    super.dispose();
  }

  String _status() {
    if (_breakOver) return 'Break over. Ready when you are.';
    if (_phase == _Phase.rest) {
      return _running ? 'Stretch, breathe, hydrate' : 'Break paused';
    }
    return _running ? 'Stay with it. One thing at a time.' : 'Paused';
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = _color;
    final task = widget.task;
    context.watch<TaskStore>();
    final todayFocus = task.focusOn(DateTime.now());
    final tag = tagByName(task.tag);
    final screen = MediaQuery.sizeOf(context);
    final ringSize =
        math.min(300.0, math.min(screen.width - 72, screen.height * 0.36));

    return Scaffold(
      backgroundColor: pal.bg,
      body: Stack(
        children: [
          // Ambient glow that breathes with the timer.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _breath,
              builder: (context, _) {
                final b = Curves.easeInOut.transform(_breath.value);
                return AnimatedContainer(
                  duration: T.slow,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.12),
                      radius: 0.9 + 0.12 * b,
                      colors: [
                        c.withValues(alpha: (pal.dark ? 0.20 : 0.13) + 0.08 * b),
                        pal.bg.withValues(alpha: 0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      _CircleButton(
                        icon: Icons.close_rounded,
                        size: 44,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      _PhasePill(
                          label: _phase == _Phase.focus ? 'FOCUS' : 'BREAK', color: c),
                      const Spacer(),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    task.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 120.ms).slideY(begin: 0.2),
                if (tag != null || task.priority != Priority.none) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (task.priority != Priority.none)
                        _MetaChip(
                            label: '${task.priority.label} priority',
                            color: priorityColor(task.priority),
                            dot: true),
                      if (tag != null && task.priority != Priority.none)
                        const SizedBox(width: 6),
                      if (tag != null)
                        _MetaChip(
                            label: '${tag.emoji} ${tag.name}', color: tagColors[tag.color]),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                ],
                const Spacer(),
                _Ring(
                  size: ringSize,
                  elapsed: _elapsedN,
                  breath: _breath,
                  total: _total,
                  color: c,
                  running: _running,
                  idleKey: _started ? 'run' : 'idle-$_minutes-${_phase.name}',
                  caption: _phase == _Phase.focus
                      ? 'of $_minutes min'
                      : '$_breakMinutes min break',
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 80.ms)
                    .scaleXY(begin: 0.9, curve: Curves.easeOutBack, duration: 600.ms),
                const Spacer(),
                SizedBox(
                  height: 54,
                  child: AnimatedSwitcher(
                    duration: T.med,
                    switchInCurve: T.ease,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
                            .animate(a),
                        child: child,
                      ),
                    ),
                    child: !_started && _phase == _Phase.focus
                        ? _PresetPicker(
                            key: const ValueKey('presets'),
                            value: _minutes,
                            color: c,
                            onChanged: (m) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _minutes = m;
                                _breakOver = false;
                              });
                            },
                          )
                        : Center(
                            key: ValueKey(_status()),
                            child: Text(_status(),
                                style: TextStyle(
                                    color: pal.muted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                          ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedOpacity(
                      duration: T.med,
                      opacity: _started ? 1 : 0.35,
                      child: _CircleButton(
                        key: const Key('focus-stop'),
                        icon: Icons.stop_rounded,
                        size: 58,
                        onTap: _started ? _stop : null,
                      ),
                    ),
                    const SizedBox(width: 26),
                    _PlayButton(
                      key: const Key('focus-play'),
                      running: _running,
                      color: c,
                      onTap: _running ? _pause : _start,
                    ),
                    const SizedBox(width: 26),
                    _CircleButton(
                      icon: Icons.check_rounded,
                      size: 58,
                      color: task.isDoneOn(widget.day) ? c : null,
                      onTap: _markDone,
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms, delay: 260.ms).slideY(begin: 0.3),
                const SizedBox(height: 22),
                AnimatedSwitcher(
                  duration: T.med,
                  child: Text(
                    todayFocus == 0
                        ? 'Your first session today'
                        : '🎯 ${_fmtMinutes(todayFocus)} focused on this today',
                    key: ValueKey(todayFocus),
                    style: TextStyle(
                        color: pal.muted, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Positioned.fill(
            child: Confetti(
              controller: _confetti,
              colors: [
                c,
                pal.accent,
                priorityColor(Priority.medium),
                priorityColor(Priority.low),
                _restColor,
              ],
            ),
          ),
          if (_finished)
            Positioned.fill(
              child: _Celebration(
                minutes: _minutes,
                breakMinutes: _breakMinutes,
                title: task.title,
                color: c,
                taskDone: task.isDoneOn(widget.day),
                onMarkDone: _markDone,
                onBreak: _startBreak,
                onAgain: () {
                  setState(() {
                    _finished = false;
                    _reset();
                  });
                },
                onClose: () => Navigator.of(context).maybePop(),
              ),
            ),
        ],
      ),
    );
  }
}

String _fmtMinutes(int m) {
  if (m < 60) return '$m min';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '${h}h' : '${h}h ${r}m';
}

String _clock(Duration d) {
  final s = d.inSeconds;
  final mm = (s ~/ 60).toString().padLeft(2, '0');
  final ss = (s % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.size,
    required this.elapsed,
    required this.breath,
    required this.total,
    required this.color,
    required this.running,
    required this.idleKey,
    required this.caption,
  });
  final double size;
  final ValueListenable<Duration> elapsed;
  final Animation<double> breath;
  final Duration total;
  final Color color;
  final bool running;
  final String idleKey;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return AnimatedBuilder(
      animation: Listenable.merge([elapsed, breath]),
      builder: (context, _) {
        final b = Curves.easeInOut.transform(breath.value);
        final e = elapsed.value;
        final totalMs = total.inMilliseconds;
        final left = 1 - (e.inMilliseconds / totalMs).clamp(0.0, 1.0);
        // Round up so the clock reads 25:00 at the start and 00:00 at the end.
        final remaining = Duration(
            seconds: ((totalMs - e.inMilliseconds).clamp(0, totalMs) / 1000).ceil());
        return Transform.scale(
          scale: 1 + 0.025 * b,
          child: SizedBox.square(
            dimension: size,
            child: TweenAnimationBuilder<double>(
              // Smoothly refills the ring when the session or preset changes.
              tween: Tween(end: left),
              duration: running ? Duration.zero : T.slow,
              curve: T.ease,
              builder: (context, v, _) => CustomPaint(
                painter: _FocusRingPainter(
                  progress: v,
                  color: color,
                  track: pal.line,
                  tick: pal.muted,
                  glow: b,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: T.med,
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(
                              scale: Tween(begin: 0.85, end: 1.0).animate(a), child: c),
                        ),
                        child: Text(
                          _clock(remaining),
                          key: ValueKey(idleKey),
                          style: TextStyle(
                            fontSize: size * 0.21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -2,
                            height: 1,
                            color: pal.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(caption,
                          style: TextStyle(
                              color: pal.muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.tick,
    required this.glow,
  });
  final double progress, glow;
  final Color color, track, tick;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final c = size.center(Offset.zero);
    final r = size.width / 2 - stroke / 2 - 10;
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track);

    // Minute ticks inside the ring.
    final tp = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final major = i % 5 == 0;
      final a = -math.pi / 2 + i * 2 * math.pi / 60;
      final dir = Offset(math.cos(a), math.sin(a));
      final outer = r - stroke / 2 - 10;
      final inner = outer - (major ? 9 : 4);
      tp
        ..strokeWidth = major ? 2.2 : 1.4
        ..color = tick.withValues(alpha: major ? 0.45 : 0.22);
      canvas.drawLine(c + dir * inner, c + dir * outer, tp);
    }

    if (progress <= 0.0005) return;
    final sweep = 2 * math.pi * progress;
    final shader = SweepGradient(
      startAngle: 0,
      endAngle: math.max(sweep, 0.01),
      colors: [Color.lerp(color, Colors.white, 0.35)!, color],
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);

    // Soft glow under the arc.
    canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke + 6
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.18 + 0.22 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = shader);

    // Leading head.
    final a = -math.pi / 2 + sweep;
    final head = c + Offset(math.cos(a), math.sin(a)) * r;
    canvas.drawCircle(head, stroke / 2 + 3, Paint()..color = color);
    canvas.drawCircle(head, stroke / 2 - 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_FocusRingPainter o) =>
      o.progress != progress ||
      o.color != color ||
      o.glow != glow ||
      o.track != track;
}

class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: T.med,
      curve: T.ease,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: T.med,
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.4)),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color, this.dot = false});
  final String label;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PresetPicker extends StatelessWidget {
  const _PresetPicker({
    super.key,
    required this.value,
    required this.color,
    required this.onChanged,
  });
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    const presets = FocusScreen.presets;
    const w = 66.0;
    final i = presets.indexOf(value);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: pal.cardAlt,
          borderRadius: BorderRadius.circular(18),
        ),
        child: SizedBox(
          width: w * presets.length,
          height: 44,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeOutBack,
                left: i * w,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: pal.card,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: softShadow(context),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final m in presets)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(m),
                      child: SizedBox(
                        width: w,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: T.fast,
                            style: TextStyle(
                              fontFamily: 'Jakarta',
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: m == value ? color : pal.muted,
                            ),
                            child: Text.rich(TextSpan(children: [
                              TextSpan(text: '$m'),
                              const TextSpan(
                                  text: ' min',
                                  style: TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w700)),
                            ])),
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
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    super.key,
    required this.icon,
    required this.size,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Material(
      color: color ?? pal.card,
      shape: CircleBorder(side: BorderSide(color: color ?? pal.line)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon,
              size: size * 0.44, color: color != null ? Colors.white : pal.ink),
        ),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({
    super.key,
    required this.running,
    required this.color,
    required this.onTap,
  });
  final bool running;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = widget.color;
    return Semantics(
      button: true,
      label: widget.running ? 'Pause' : 'Start',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? 0.9 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: T.med,
            curve: T.ease,
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c,
                  Color.lerp(c, pal.dark ? Colors.black : const Color(0xFF1A1033), 0.3)!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: c.withValues(alpha: 0.45),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: T.fast,
              transitionBuilder: (child, a) => RotationTransition(
                turns: Tween(begin: 0.75, end: 1.0).animate(a),
                child: ScaleTransition(scale: a, child: child),
              ),
              child: Icon(
                widget.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(widget.running),
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Celebration extends StatelessWidget {
  const _Celebration({
    required this.minutes,
    required this.breakMinutes,
    required this.title,
    required this.color,
    required this.taskDone,
    required this.onMarkDone,
    required this.onBreak,
    required this.onAgain,
    required this.onClose,
  });
  final int minutes, breakMinutes;
  final String title;
  final Color color;
  final bool taskDone;
  final VoidCallback onMarkDone, onBreak, onAgain, onClose;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        color: pal.bg.withValues(alpha: 0.55),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 14),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: pal.line),
            boxShadow: softShadow(context),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('🎉', style: TextStyle(fontSize: 36)),
              )
                  .animate()
                  .scaleXY(begin: 0.3, duration: 600.ms, curve: Curves.easeOutBack)
                  .then()
                  .shake(hz: 3, rotation: 0.05, duration: 500.ms),
              const SizedBox(height: 14),
              const Text('Session complete',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text(
                '$minutes minutes of deep focus on\n"$title"',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: pal.muted, height: 1.4, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              if (!taskDone) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: onMarkDone,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Mark task done'),
                ),
                const SizedBox(height: 10),
              ],
              Material(
                color: pal.cardAlt,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onBreak,
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: Text('☕  Take a $breakMinutes-min break',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(onPressed: onAgain, child: const Text('Another round')),
                  TextButton(
                    onPressed: onClose,
                    style: TextButton.styleFrom(foregroundColor: pal.muted),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ]
                .animate(interval: 50.ms, delay: 150.ms)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.15, curve: T.ease),
          ),
        )
            .animate()
            .fadeIn(duration: 300.ms)
            .scaleXY(begin: 0.9, duration: 450.ms, curve: Curves.easeOutBack),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}
