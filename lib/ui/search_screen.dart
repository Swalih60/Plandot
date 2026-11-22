import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/task_store.dart';
import '../util/dates.dart';
import 'task_editor.dart';
import 'theme.dart';
import 'widgets/task_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final pal = context.pal;
    final results = store.search(_q.text);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _q,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search tasks, notes, tags…',
              filled: true,
              fillColor: pal.card,
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: pal.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: pal.line),
              ),
            ),
          ),
        ),
      ),
      body: _q.text.trim().isEmpty
          ? Center(
              child: Text('Find anything you planned',
                  style: TextStyle(color: pal.muted, fontWeight: FontWeight.w600)),
            )
          : results.isEmpty
              ? Center(
                  child: Text('No matches',
                      style: TextStyle(color: pal.muted, fontWeight: FontWeight.w600)),
                ).animate().fadeIn()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final t = results[i];
                    final day = dateOnly(t.date);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TaskTile(
                        key: ValueKey(t.id),
                        task: t,
                        day: day,
                        showDate: true,
                        onToggle: () => store.toggleDone(t, day),
                        onOpen: () => showTaskEditor(context, task: t, day: day),
                        onDelete: () => store.delete(t),
                        onTomorrow: () => store.moveTo(
                            t, addDays(dateOnly(DateTime.now()), 1)),
                      ),
                    ).animate().fadeIn(duration: 220.ms, delay: (i * 30).ms);
                  },
                ),
    );
  }
}
