import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../data/task_store.dart';
import '../services/pro_service.dart';
import '../services/reminders.dart';
import 'paywall_screen.dart';
import 'theme.dart';
import '../services/sounds.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _export(BuildContext context) async {
    final store = context.read<TaskStore>();
    final dir = await getTemporaryDirectory();
    final f = File(
      '${dir.path}/ticklist-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json',
    );
    await f.writeAsString(store.exportJson());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(f.path, mimeType: 'application/json')],
        subject: 'Plandot backup',
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final store = context.read<TaskStore>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'This replaces all tasks on this device with the backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      final n = await store.importJson(await files.first.xFile.readAsString());
      await Reminders.instance.rescheduleAll(store.allTasks);
      messenger.showSnackBar(SnackBar(content: Text('Restored $n tasks')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is FormatException ? e.message : 'Could not read that file.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final pro = context.watch<ProService>();
    final pal = context.pal;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
      child: Text(
        t,
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w800,
          color: pal.muted,
        ),
      ),
    );

    Widget group(List<Widget> children) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(T.r),
        border: Border.all(color: pal.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: children),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: pro.isPro ? null : () => showPaywall(context),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      pal.accent,
                      Color.lerp(pal.accent, Colors.black, 0.3)!,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      pro.isPro ? '💎' : '✨',
                      style: const TextStyle(fontSize: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pro.isPro ? 'Plandot Pro' : 'Upgrade to Pro',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            pro.isPro
                                ? 'Thanks for supporting indie software!'
                                : 'Repeats, insights & premium themes',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!pro.isPro)
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                      ),
                  ],
                ),
              ),
            ),
          ),
          header('THEME'),
          group([
            Padding(
              padding: const EdgeInsets.all(14),
              child: SegmentedButton<AppThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: AppThemeMode.system,
                    icon: Icon(Icons.brightness_auto_rounded),
                    label: Text('Auto'),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.light,
                    icon: Icon(Icons.light_mode_rounded),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.dark,
                    icon: Icon(Icons.dark_mode_rounded),
                    label: Text('Dark'),
                  ),
                ],
                selected: {store.themeMode},
                onSelectionChanged: (s) => store.setThemeMode(s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < accents.length; i++)
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        if (i > 0 && !pro.isPro) {
                          final ok = await showPaywall(
                            context,
                            reason: 'Premium themes are part of Plandot Pro.',
                          );
                          if (!ok) return;
                        }
                        store.setAccent(i);
                      },
                      child: AnimatedContainer(
                        duration: T.med,
                        curve: T.spring,
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accents[i].$2,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: store.accent == i
                                ? pal.ink
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: store.accent == i
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                              )
                            : (i > 0 && !pro.isPro)
                            ? const Icon(
                                Icons.lock_rounded,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ]),
          header('PREFERENCES'),
          group([
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_rounded),
              title: const Text('Sound effects'),
              value: store.soundsOn,
              onChanged: (v) {
                store.setSoundsOn(v);
                Sounds.instance.enabled = v;
                if (v) Sounds.instance.play(Sfx.complete);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.calendar_view_week_rounded),
              title: const Text('Week starts on Monday'),
              value: store.mondayFirst,
              onChanged: store.setMondayFirst,
            ),
          ]),
          header('PURCHASES'),
          group([
            ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('Restore purchases'),
              onTap: () async {
                final m = ScaffoldMessenger.of(context);
                try {
                  final ok = await pro.restore();
                  m.showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Pro restored 🎉'
                            : 'No active Pro purchase found.',
                      ),
                    ),
                  );
                } catch (e) {
                  m.showSnackBar(SnackBar(content: Text('$e')));
                }
              },
            ),
            if (pro.isPro && !ProService.ownerBuild)
              ListTile(
                leading: const Icon(Icons.credit_card_rounded),
                title: const Text('Manage subscription'),
                onTap: () => openUrl(
                  isIOS
                      ? 'https://apps.apple.com/account/subscriptions'
                      : 'https://play.google.com/store/account/subscriptions',
                ),
              ),
            if (kDebugMode)
              SwitchListTile(
                secondary: const Icon(Icons.bug_report_rounded),
                title: const Text('Debug: Pro unlocked'),
                value: pro.isPro,
                onChanged: (_) => pro.toggleDebugPro(),
              ),
          ]),
          header('YOUR DATA'),
          group([
            ListTile(
              leading: const Icon(Icons.upload_rounded),
              title: const Text('Export backup'),
              onTap: () => _export(context),
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Restore from backup'),
              onTap: () => _import(context),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
            child: Text(
              'Everything stays on this device. No accounts, no servers, no tracking.',
              style: TextStyle(fontSize: 12, color: pal.muted),
            ),
          ),
          header('ABOUT'),
          group([
            ListTile(
              leading: const Icon(Icons.privacy_tip_rounded),
              title: const Text('Privacy policy'),
              onTap: () => openUrl(AppConfig.privacyUrl),
            ),
            ListTile(
              leading: const Icon(Icons.description_rounded),
              title: const Text('Terms of use'),
              onTap: () => openUrl(AppConfig.termsUrl),
            ),
            ListTile(
              leading: const Icon(Icons.mail_rounded),
              title: const Text('Contact support'),
              onTap: () =>
                  openUrl('mailto:${AppConfig.supportEmail}?subject=Plandot'),
            ),
          ]),
        ],
      ),
    );
  }
}
