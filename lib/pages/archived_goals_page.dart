import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../configs/date_format.dart';
import '../configs/l10n_ext.dart';
import '../configs/text_styles.dart';
import '../engine/consistency_engine.dart';
import '../models/goal.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';

/// Archived goals: card per goal with a Restore button, or an empty state.
class ArchivedGoalsPage extends StatelessWidget {
  const ArchivedGoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final settings = context.watch<SettingsStore>();
    final scheme = Theme.of(context).colorScheme;
    final archived = [
      for (final g in store.data.goals)
        if (g.isArchived) g
    ];
    final engine = ConsistencyEngine(
        data: store.data, threshold: settings.threshold, today: DateTime.now());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text(context.l10n.archivedGoalsTitle,
            style: context.textStyles.boldText.copyWith(fontSize: 24)),
      ),
      body: archived.isEmpty
          ? _empty(context)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: archived.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _card(context, store, engine, archived[i]),
            ),
    );
  }

  Widget _card(BuildContext context, AppStore store, ConsistencyEngine engine,
      Goal goal) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.name,
                    style: context.textStyles.boldText.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  context.l10n.archivedOn(
                    formatDayMonthYear(goal.archivedAt!),
                    engine.goalBest(goal),
                  ),
                  style: context.textStyles.thinText.copyWith(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => store.restoreGoal(goal.id),
            child: Text(context.l10n.restore),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(context.l10n.noArchivedGoals,
                style: context.textStyles.boldText.copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              context.l10n.noArchivedGoalsCaption,
              textAlign: TextAlign.center,
              style: context.textStyles.thinText.copyWith(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
