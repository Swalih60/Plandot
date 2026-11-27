import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'data/task_store.dart';
import 'services/pro_service.dart';
import 'services/reminders.dart';
import 'ui/focus_screen.dart';
import 'ui/onboarding_screen.dart';
import 'ui/root_shell.dart';
import 'ui/splash.dart';
import 'ui/stats_screen.dart';
import 'ui/task_editor.dart';
import 'ui/theme.dart';
import 'util/dates.dart';

/// Store-screenshot helper: `--dart-define=SHOT=focus|stats|edit` opens that
/// screen directly. Never set for store or personal builds.
const _shot = String.fromEnvironment('SHOT');

Widget? _shotScreen(TaskStore s) {
  final today = dateOnly(DateTime.now());
  final tasks = s.tasksOn(today);
  if (tasks.isEmpty) return null;
  return switch (_shot) {
    'focus' => FocusScreen(task: tasks.first, day: today),
    'stats' => const StatsScreen(),
    'edit' => _EditShot(task: tasks.first, day: today),
    'tasks' => const RootShell(initialTab: 1),
    _ => null,
  };
}

class _EditShot extends StatefulWidget {
  const _EditShot({required this.task, required this.day});
  final dynamic task;
  final DateTime day;
  @override
  State<_EditShot> createState() => _EditShotState();
}

class _EditShotState extends State<_EditShot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => showTaskEditor(context, task: widget.task, day: widget.day),
    );
  }

  @override
  Widget build(BuildContext context) => const RootShell();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final store = TaskStore();
  final pro = ProService();
  await store.load();
  await Reminders.instance.init();
  pro.init(); // Pro status arrives via listener; don't block first frame.
  runApp(TicklistApp(store: store, pro: pro));
}

class TicklistApp extends StatelessWidget {
  const TicklistApp({super.key, required this.store, required this.pro});
  final TaskStore store;
  final ProService pro;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: pro),
      ],
      child: Consumer2<TaskStore, ProService>(
        builder: (context, s, p, _) {
          // Premium themes fall back to the default if Pro lapses.
          final accent =
              accents[p.isPro ? s.accent.clamp(0, accents.length - 1) : 0].$2;
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light, accent),
            darkTheme: buildTheme(Brightness.dark, accent),
            themeMode: switch (s.themeMode) {
              AppThemeMode.system => ThemeMode.system,
              AppThemeMode.light => ThemeMode.light,
              AppThemeMode.dark => ThemeMode.dark,
            },
            home:
                _shotScreen(s) ??
                SplashGate(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: s.onboarded
                        ? const RootShell(key: ValueKey('home'))
                        : const OnboardingScreen(key: ValueKey('onboarding')),
                  ),
                ),
          );
        },
      ),
    );
  }
}
