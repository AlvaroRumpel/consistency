import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../configs/l10n_ext.dart';
import '../configs/text_styles.dart';
import '../controllers/day_editor_controller.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';
import '../widgets/day_editor.dart';
import '../widgets/goal_sheet.dart';
import '../widgets/progress_ring.dart';
import '../widgets/streak_badge.dart';
import 'goal_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final DayEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DayEditorController(
        context.read<AppStore>(), context.read<SettingsStore>());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back after midnight must roll the day over.
    if (state == AppLifecycleState.resumed) _controller.reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.onDispose();
    super.dispose();
  }

  Widget _header(BuildContext context, DayView view) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                  context.l10n
                      .greeting(view.nickname ?? context.l10n.defaultNickname),
                  style: context.textStyles.titleText),
            ),
            StreakBadge(streak: view.streak),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: ProgressRing(
            average: view.average,
            saved: view.saved,
            dirty: view.dirty,
            onTap: view.editable ? _controller.save : null,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.recordDays(view.best),
          style: context.textStyles.thinText.copyWith(
            fontSize: 12,
            letterSpacing: 1.2,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: DayEditor(
        controller: _controller,
        header: _header,
        onGoalTap: (row) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GoalDetailPage(goalId: row.goalId)),
        ),
        footer: (_, __) => OutlinedButton.icon(
          onPressed: () => showGoalSheet(context),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.newGoal),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: const StadiumBorder(),
          ),
        ),
      ),
    );
  }
}
