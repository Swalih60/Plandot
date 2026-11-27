import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/task_store.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'theme.dart';
import '../services/sounds.dart';

/// Two main areas: Today (day planner) and Tasks (undated master list),
/// switched with a floating pill bar whose highlight glides between tabs.
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
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _FadeIn(visible: _tab == 0, child: const HomeScreen()),
          _FadeIn(visible: _tab == 1, child: const TasksScreen()),
        ],
      ),
      bottomNavigationBar: _NavBar(tab: _tab, onTap: _go, badge: openCount),
    );
  }
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

class _NavBar extends StatelessWidget {
  const _NavBar({required this.tab, required this.onTap, required this.badge});
  final int tab;
  final ValueChanged<int> onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    const items = [
      (Icons.today_rounded, 'Today'),
      (Icons.inbox_rounded, 'Tasks'),
    ];
    // Solid, full-width bar: content ends above it (never hidden behind),
    // the tab switch is centred, and each screen's + button sits above it.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: pal.bg,
        border: Border(top: BorderSide(color: pal.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Container(
            height: 56,
            padding: const EdgeInsets.all(5),
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
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutBack,
                      left: tab * w,
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
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onTap(i),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    scale: tab == i ? 1.1 : 1,
                                    duration: T.med,
                                    curve: Curves.easeOutBack,
                                    child: Icon(
                                      items[i].$1,
                                      size: 21,
                                      color: tab == i
                                          ? Colors.white
                                          : pal.muted,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  AnimatedDefaultTextStyle(
                                    duration: T.fast,
                                    style: TextStyle(
                                      fontFamily: 'Jakarta',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: tab == i
                                          ? Colors.white
                                          : pal.muted,
                                    ),
                                    child: Text(items[i].$2),
                                  ),
                                  if (i == 1 && badge > 0) ...[
                                    const SizedBox(width: 6),
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
                                          color: tab == i
                                              ? Colors.white
                                              : pal.accent,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          '$badge',
                                          style: TextStyle(
                                            color: tab == i
                                                ? pal.accent
                                                : Colors.white,
                                            fontSize: 11,
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
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
