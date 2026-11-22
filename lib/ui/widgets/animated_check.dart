import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Round checkbox: the fill springs in, the tick draws itself, and a ring
/// ripples outward on completion.
class AnimatedCheck extends StatefulWidget {
  const AnimatedCheck({
    super.key,
    required this.checked,
    required this.color,
    required this.onChanged,
    this.size = 28,
  });

  final bool checked;
  final Color color;
  final ValueChanged<bool> onChanged;
  final double size;

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.checked ? 1 : 0,
  );
  late final AnimationController _ripple = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void didUpdateWidget(AnimatedCheck old) {
    super.didUpdateWidget(old);
    if (old.checked != widget.checked) {
      widget.checked ? _c.forward() : _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _ripple.dispose();
    super.dispose();
  }

  void _tap() {
    final next = !widget.checked;
    if (next) {
      HapticFeedback.mediumImpact();
      _ripple.forward(from: 0);
      _c.forward();
    } else {
      HapticFeedback.selectionClick();
      _c.reverse();
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      checked: widget.checked,
      button: true,
      child: GestureDetector(
        onTap: _tap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: s + 16,
          height: s + 16,
          child: AnimatedBuilder(
            animation: Listenable.merge([_c, _ripple]),
            builder: (context, _) {
              final fill = Curves.easeOutBack.transform(_c.value.clamp(0, 1));
              final tick = Curves.easeOutCubic
                  .transform(((_c.value - 0.25) / 0.75).clamp(0.0, 1.0));
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (_ripple.isAnimating)
                    Container(
                      width: s * (1 + _ripple.value * 0.9),
                      height: s * (1 + _ripple.value * 0.9),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.color
                              .withValues(alpha: (1 - _ripple.value) * 0.6),
                          width: 2.5 * (1 - _ripple.value) + 0.5,
                        ),
                      ),
                    ),
                  Container(
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.color, width: 2.2),
                    ),
                  ),
                  Transform.scale(
                    scale: fill,
                    child: Container(
                      width: s,
                      height: s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color,
                      ),
                    ),
                  ),
                  CustomPaint(
                    size: Size(s, s),
                    painter: _TickPainter(tick),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.28, w * 0.52)
      ..lineTo(w * 0.44, w * 0.67)
      ..lineTo(w * 0.73, w * 0.36);
    final metric = path.computeMetrics().first;
    final partial = metric.extractPath(0, metric.length * t);
    canvas.drawPath(
      partial,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(2.2, w * 0.1),
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.t != t;
}
