import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Animated intro shown once per launch, right after the native splash.
/// The white dot springs in, the tick draws itself, the red dot drops in
/// with a bounce, the name slides up, then the white circle expands to fill
/// the screen and dissolves into the app underneath.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});
  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _done = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        setState(() => _done = true);
      } else {
        _c.forward();
        Future.delayed(
          const Duration(milliseconds: 700),
          () => HapticFeedback.mediumImpact(),
        );
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_done)
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => _SplashFrame(t: _c.value),
          ),
      ],
    );
  }
}

const _indigo = Color(0xFF5B5BF6);
const _deep = Color(0xFF3726B4);
const _coral = Color(0xFFFF4D57);

double _iv(double t, double a, double b, [Curve c = Curves.linear]) =>
    c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

class _SplashFrame extends StatelessWidget {
  const _SplashFrame({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dot = math.min(size.width * 0.34, 150.0);
    final textIn = _iv(t, 0.40, 0.60, Curves.easeOutCubic);
    // Exit: circle grows to cover the screen, then everything fades.
    final grow = _iv(t, 0.74, 0.92, Curves.easeInCubic);
    final fade = _iv(t, 0.88, 1.0, Curves.easeOut);
    final cover = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    final scale = 1 + grow * (cover / dot);

    return Opacity(
      opacity: 1 - fade,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF6E6EFF), _deep],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: SizedBox.square(
                dimension: dot,
                child: Transform.scale(
                  scale: scale,
                  child: CustomPaint(
                    painter: _MarkPainter(t: t, hideMarks: grow > 0.05),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: size.height / 2 + dot / 2 + 40,
              child: Opacity(
                opacity: textIn * (1 - grow),
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - textIn)),
                  child: Column(
                    children: [
                      const Text(
                        'Plandot',
                        style: TextStyle(
                          fontFamily: 'Jakarta',
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Opacity(
                        opacity: _iv(t, 0.50, 0.68),
                        child: Text(
                          'Plan your day. Focus on what matters.',
                          style: TextStyle(
                            fontFamily: 'Jakarta',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.78),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.t, required this.hideMarks});
  final double t;
  final bool hideMarks;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);

    // White dot springs in.
    final pop = _iv(t, 0.0, 0.26, Curves.elasticOut);
    if (pop <= 0) return;
    canvas.drawCircle(
      c + Offset(0, r * 0.06),
      r * pop,
      Paint()
        ..color = const Color(0x55140A3C)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18),
    );
    canvas.drawCircle(c, r * pop, Paint()..color = Colors.white);
    if (hideMarks) return;

    // Tick draws itself.
    final draw = _iv(t, 0.18, 0.40, Curves.easeOutCubic);
    if (draw > 0) {
      final path = Path()
        ..moveTo(c.dx - r * 0.42, c.dy + r * 0.02)
        ..lineTo(c.dx - r * 0.12, c.dy + r * 0.32)
        ..lineTo(c.dx + r * 0.46, c.dy - r * 0.30);
      final m = path.computeMetrics().first;
      canvas.drawPath(
        m.extractPath(0, m.length * draw),
        Paint()
          ..color = _indigo
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.20
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Red dot drops in with a bounce, with a little ring pulse on landing.
    final drop = _iv(t, 0.30, 0.50, Curves.bounceOut);
    if (drop > 0) {
      final end = c + Offset(r * 0.80, -r * 0.80);
      final pos = Offset(end.dx, end.dy - (1 - drop) * r * 1.4);
      final ar = r * 0.24;
      canvas.drawCircle(pos, ar + r * 0.05, Paint()..color = _indigo);
      canvas.drawCircle(pos, ar, Paint()..color = _coral);
      final ring = _iv(t, 0.44, 0.62);
      if (ring > 0 && ring < 1) {
        canvas.drawCircle(
          end,
          ar + r * 0.5 * ring,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.05 * (1 - ring)
            ..color = Colors.white.withValues(alpha: 0.8 * (1 - ring)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MarkPainter o) => o.t != t || o.hideMarks != hideMarks;
}
