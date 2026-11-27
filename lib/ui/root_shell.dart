import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/task_store.dart';
import '../services/sounds.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'theme.dart';

/// Two main areas: Today (day planner) and Tasks (undated master list).
/// There is no bottom bar — the bottom stays clean with just the + button.
/// The Today | Tasks switch sits at the top of both screens ([ShellSwitch]).
class RootShell extends StatefulWidget {
  const RootShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  late int _tab = widget.initialTab;

  void _go(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    Sounds.instance.play(Sfx.tap);
    FocusScope.of(context).unfocus();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final openCount = context.select<TaskStore, int>((s) => s.listOpenCount);
    return ShellScope(
      tab: _tab,
      badge: openCount,
      go: _go,
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            _FadeIn(visible: _tab == 0, child: const HomeScreen()),
            _FadeIn(visible: _tab == 1, child: const TasksScreen()),
          ],
        ),
      ),
    );
  }
}

/// Gives both screens the current tab, the open-task count and the switch.
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.tab,
    required this.badge,
    required this.go,
    required super.child,
  });
  final int tab;
  final int badge;
  final ValueChanged<int> go;

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope old) =>
      old.tab != tab || old.badge != badge;
}

/// Soft fade + slight rise when a tab becomes visible.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: visible ? 1 : 0,
    duration: T.med,
    curve: T.ease,
    child: AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.015),
      duration: T.med,
      curve: T.ease,
      child: child,
    ),
  );
}

/// Compact, centred Today | Tasks switch for the top of each screen.
/// Renders nothing when used outside [RootShell] (e.g. in tests).
class ShellSwitch extends StatelessWidget {
  const ShellSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = ShellScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    final pal = context.pal;
    const items = [
      (Icons.today_rounded, 'Today'),
      (Icons.inbox_rounded, 'Tasks'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Center(
        child: Container(
          width: 264,
          height: 42,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: pal.line),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth / items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeOutBack,
                    left: scope.tab * w,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: Container(
                      decoration: BoxDecoration(
                        color: pal.accent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: pal.accent.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: scope.tab == i,
                            label: items[i].$2,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => scope.go(i),
                              child: _TabLabel(
                                icon: items[i].$1,
                                label: items[i].$2,
                                selected: scope.tab == i,
                                badge: i == 1 ? scope.badge : 0,
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
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.icon,
    required this.label,
    required this.selected,
    required this.badge,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fg = selected ? Colors.white : pal.muted;
    // Scales down instead of overflowing on large system font sizes.
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: T.med,
                curve: Curves.easeOutBack,
                child: Icon(icon, size: 17, color: fg),
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: T.fast,
                style: TextStyle(
                  fontFamily: 'Jakarta',
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: fg,
                ),
                child: Text(label),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 5),
                AnimatedSwitcher(
                  duration: T.fast,
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: c),
                  child: Container(
                    key: ValueKey(badge),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : pal.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        color: selected ? pal.accent : Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
