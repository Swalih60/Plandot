import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../util/dates.dart';
import 'theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _finish() {
    final store = context.read<TaskStore>();
    if (store.allTasks.isEmpty) {
      // Seed a tiny example day so the first screen isn't empty.
      final today = dateOnly(DateTime.now());
      store.addTask(
        title: 'Swipe me right to complete →',
        date: today,
        priority: Priority.high,
      );
      store.addTask(
        title: 'Tap me to add notes & subtasks',
        date: today,
        priority: Priority.medium,
        tag: 'Personal',
      );
      store.addTask(
        title: 'Try typing "Read 20 min tonight !low"',
        date: today,
        priority: Priority.low,
      );
    }
    store.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final pages = [
      _Page(
        art: const _ArtStack(),
        title: 'Plan your day\nin seconds',
        body: 'Type naturally — "Gym tomorrow 7am !high" — and Plandot sorts out the rest.',
      ),
      _Page(
        art: const _ArtPriority(),
        title: 'Focus on what\nmatters most',
        body: 'Give every task a priority. The important stuff always rises to the top.',
      ),
      _Page(
        art: Text('🔒', style: const TextStyle(fontSize: 90))
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(end: 1.08, duration: 1500.ms, curve: Curves.easeInOut),
        title: 'Private.\nOffline. Yours.',
        body: 'No account, no ads, no tracking. Your plans never leave your phone.',
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (p) {
                  HapticFeedback.selectionClick();
                  setState(() => _page = p);
                },
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (i) => AnimatedContainer(
                        duration: T.med,
                        curve: T.ease,
                        margin: const EdgeInsets.all(4),
                        width: i == _page ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? pal.accent : pal.line,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (_page < pages.length - 1) {
                        _pc.nextPage(duration: T.slow, curve: T.ease);
                      } else {
                        _finish();
                      }
                    },
                    child: AnimatedSwitcher(
                      duration: T.fast,
                      child: Text(
                        _page < pages.length - 1 ? 'Continue' : 'Get started',
                        key: ValueKey(_page < pages.length - 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.art, required this.title, required this.body});
  final Widget art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:
            [
                  SizedBox(height: 240, child: Center(child: art)),
                  const SizedBox(height: 36),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: pal.muted,
                    ),
                  ),
                ]
                .animate(interval: 90.ms)
                .fadeIn(duration: 450.ms)
                .slideY(begin: 0.12, curve: T.ease),
      ),
    );
  }
}

class _ArtStack extends StatelessWidget {
  const _ArtStack();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    Widget row(String t, Color c, bool done) => Container(
      width: 260,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pal.line),
        boxShadow: softShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? c : Colors.transparent,
              border: Border.all(color: c, width: 2),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            t,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: done ? pal.muted : pal.ink,
              decoration: done ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children:
          [
                row('Morning run', priorityColor(Priority.medium), true),
                row('Finish slides', priorityColor(Priority.high), false),
                row('Buy groceries', priorityColor(Priority.low), false),
              ]
              .animate(interval: 150.ms)
              .fadeIn(duration: 400.ms)
              .slideX(begin: 0.25, curve: Curves.easeOutBack, duration: 500.ms),
    );
  }
}

class _ArtPriority extends StatelessWidget {
  const _ArtPriority();

  @override
  Widget build(BuildContext context) {
    final items = [Priority.high, Priority.medium, Priority.low];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < items.length; i++)
          Container(
            width: 64,
            height: 170.0 - i * 45,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: priorityColor(items[i]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: priorityColor(items[i]).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              items[i].label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ).animate().scaleY(
            begin: 0,
            alignment: Alignment.bottomCenter,
            delay: (i * 120).ms,
            duration: 600.ms,
            curve: Curves.easeOutBack,
          ),
      ],
    );
  }
}
