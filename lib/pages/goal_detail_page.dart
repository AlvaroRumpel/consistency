import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../configs/app_tokens.dart';
import '../configs/text_styles.dart';
import '../engine/consistency_engine.dart';
import '../models/goal.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';
import '../widgets/goal_sheet.dart';
import '../widgets/goal_stats.dart';

String _days(int n) => '$n ${n == 1 ? 'day' : 'days'}';

String _dmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// One goal: stats, the last 30 days, its type and archive/restore.
class GoalDetailPage extends StatelessWidget {
  final String goalId;

  const GoalDetailPage({super.key, required this.goalId});

  Future<void> _archive(BuildContext context, Goal goal) async {
    if (!await confirmArchiveGoal(context) || !context.mounted) return;
    await context.read<AppStore>().archiveGoal(goal.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final settings = context.watch<SettingsStore>();
    final goal = store.data.goalById(goalId);
    if (goal == null) {
      // The goal vanished under us (cleared data): there is nothing to show.
      final nav = Navigator.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (nav.canPop()) nav.pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final engine = ConsistencyEngine(
        data: store.data, threshold: settings.threshold, today: DateTime.now());
    final streak = engine.goalStreak(goal);
    String rate(int n) => '${(engine.goalRate(goal, n) * 100).round()}%';
    final dim = goal.isArchived ? 0.6 : 1.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text(goal.name,
            style: context.textStyles.boldText.copyWith(fontSize: 24)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => showGoalSheet(context, goal: goal),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (goal.archivedAt != null) _banner(context, goal.archivedAt!),
          Opacity(
            opacity: dim,
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.local_fire_department,
                      iconColor: tokens.flameFor(streak),
                      value: _days(streak),
                      label: 'CURRENT STREAK',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.emoji_events_outlined,
                      iconColor: scheme.onSurfaceVariant,
                      value: _days(engine.goalBest(goal)),
                      label: 'RECORD',
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: StatTile(value: rate(7), label: 'LAST 7 DAYS')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: StatTile(value: rate(30), label: 'LAST 30 DAYS')),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _label(context, 'LAST 30 DAYS'),
          const SizedBox(height: 8),
          DayStrip(goal: goal, data: store.data),
          const SizedBox(height: 10),
          _legend(context, tokens),
          const SizedBox(height: 14),
          Opacity(opacity: dim, child: _typeCard(context, goal)),
          const SizedBox(height: 24),
          if (goal.isArchived) ...[
            FilledButton.icon(
              onPressed: () => store.restoreGoal(goal.id),
              icon: const Icon(Icons.unarchive_outlined),
              label: const Text('Restore goal'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
            ),
            _caption(context, 'It shows up on Home again right away.',
                center: true),
          ] else ...[
            OutlinedButton.icon(
              onPressed: () => _archive(context, goal),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archive goal'),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
            ),
            _caption(context, 'It leaves Home; history and stats stay.',
                center: true),
          ],
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(
        text,
        style: context.textStyles.boldText.copyWith(
          fontSize: 12,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );

  Widget _caption(BuildContext context, String text, {bool center = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          text,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: context.textStyles.thinText.copyWith(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  Widget _banner(BuildContext context, DateTime on) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(Icons.archive_outlined,
              size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('Archived on ${_dmy(on)}',
              style: context.textStyles.normalText.copyWith(fontSize: 13)),
        ]),
      );

  Widget _legend(BuildContext context, AppTokens tokens) => Row(children: [
        _caption(context, 'less'),
        for (final c in tokens.quality)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        const SizedBox(width: 6),
        _caption(context, 'more'),
      ]);

  Widget _typeCard(BuildContext context, Goal goal) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(context, 'TYPE'),
            const SizedBox(height: 8),
            SegmentedButton<GoalType>(
              segments: const [
                ButtonSegment(
                    value: GoalType.check, label: Text('Done / not done')),
                ButtonSegment(
                    value: GoalType.percent, label: Text('Percent 0–100')),
              ],
              selected: {goal.type},
              showSelectedIcon: false,
              onSelectionChanged: null, // read-only: the pencil edits it
            ),
            _caption(context, 'Change it with the edit button'),
          ],
        ),
      );
}
