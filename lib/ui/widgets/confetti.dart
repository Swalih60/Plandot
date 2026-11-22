import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Lightweight confetti burst. Call [ConfettiController.fire] to play.
class ConfettiController extends ChangeNotifier {
  void fire() => notifyListeners();
}

class Confetti extends StatefulWidget {
  const Confetti({super.key, required this.controller, required this.colors});
  final ConfettiController controller;
  final List<Color> colors;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _Particle {
  _Particle(math.Random r, this.color)
      : x = 0.5 + (r.nextDouble() - 0.5) * 0.2,
        vx = (r.nextDouble() - 0.5) * 1.6,
        vy = -(0.9 + r.nextDouble() * 0.9),
        spin = (r.nextDouble() - 0.5) * 14,
        size = 6 + r.nextDouble() * 6,
        circle = r.nextBool();
  final double x, vx, vy, spin, size;
  final bool circle;
  final Color color;
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  List<_Particle> _ps = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_fire);
  }

  void _fire() {
    final r = math.Random();
    _ps = List.generate(
        90, (i) => _Particle(r, widget.colors[i % widget.colors.length]));
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_fire);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => _c.isAnimating
              ? CustomPaint(
                  size: Size.infinite, painter: _Painter(_ps, _c.value))
              : const SizedBox.shrink(),
        ),
      );
}

class _Painter extends CustomPainter {
  _Painter(this.ps, this.t);
  final List<_Particle> ps;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const g = 2.4; // gravity in screen-heights / s^2
    final secs = t * 1.8;
    final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
    for (final p in ps) {
      final x = (p.x + p.vx * secs * 0.35) * size.width;
      final y = size.height * 0.42 +
          (p.vy * secs + 0.5 * g * secs * secs) * size.height * 0.45;
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * secs);
      if (p.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2.4, paint);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset.zero, width: p.size, height: p.size * 0.45),
                const Radius.circular(2)),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Painter o) => o.t != t;
}
