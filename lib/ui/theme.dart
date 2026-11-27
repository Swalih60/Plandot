import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

import '../models/task.dart';

/// Accent palettes. Index 0 is free; the rest are Pro themes.
const accents = <(String, Color)>[
  ('Indigo', Color(0xFF5B5BF6)),
  ('Violet', Color(0xFF8B5CF6)),
  ('Emerald', Color(0xFF10B981)),
  ('Coral', Color(0xFFFF6B5B)),
  ('Ocean', Color(0xFF0EA5E9)),
  ('Gold', Color(0xFFE0A100)),
  ('Rose', Color(0xFFF43F7E)),
  ('Graphite', Color(0xFF52525B)),
];

Color priorityColor(Priority p) => switch (p) {
  Priority.high => const Color(0xFFFF4D57),
  Priority.medium => const Color(0xFFFFA41B),
  Priority.low => const Color(0xFF3B9CFF),
  Priority.none => const Color(0xFFA1A1AA),
};

const tagColors = <Color>[
  Color(0xFF6366F1),
  Color(0xFF10B981),
  Color(0xFFF97316),
  Color(0xFF8B5CF6),
  Color(0xFFEAB308),
  Color(0xFF06B6D4),
];

/// Spacing and motion tokens used across the app.
class T {
  static const r = 22.0; // card radius
  static const fast = Duration(milliseconds: 180);
  static const med = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);
  static const ease = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
}

class Palette {
  Palette(this.dark, this.accent);
  final bool dark;
  final Color accent;

  Color get bg => dark ? const Color(0xFF0C0D11) : const Color(0xFFF4F3EF);
  Color get card => dark ? const Color(0xFF16181E) : Colors.white;
  Color get cardAlt => dark ? const Color(0xFF1D2027) : const Color(0xFFF0EFEA);
  Color get line => dark ? const Color(0xFF262932) : const Color(0xFFE7E5DF);
  Color get ink => dark ? const Color(0xFFF4F4F6) : const Color(0xFF14151A);
  Color get muted => dark ? const Color(0xFF8C8F9A) : const Color(0xFF7A7B83);
}

extension PaletteX on BuildContext {
  Palette get pal {
    final t = Theme.of(this);
    return Palette(t.brightness == Brightness.dark, t.colorScheme.primary);
  }
}

ThemeData buildTheme(Brightness b, Color accent) {
  final p = Palette(b == Brightness.dark, accent);
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: b,
    primary: accent,
    surface: p.bg,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    fontFamily: 'Jakarta',
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: p.ink,
      titleTextStyle: TextStyle(
        fontFamily: 'Jakarta',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: p.ink,
        letterSpacing: -0.4,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.dark
          ? const Color(0xFF2A2D36)
          : const Color(0xFF14151A),
      contentTextStyle: const TextStyle(
        fontFamily: 'Jakarta',
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
          fontFamily: 'Jakarta',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Soft shadow used for floating surfaces.
List<BoxShadow> softShadow(BuildContext c) => [
  BoxShadow(
    color: Colors.black.withValues(alpha: c.pal.dark ? 0.35 : 0.06),
    blurRadius: 24,
    offset: const Offset(0, 8),
  ),
];
