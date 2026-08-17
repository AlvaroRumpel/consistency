import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../configs/text_styles.dart';
import '../models/goal.dart';
import '../state/app_store.dart';

/// Create/edit a goal: name, type, and (when editing) archive.
Future<void> showGoalSheet(BuildContext context, {Goal? goal}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: scheme.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _GoalSheet(goal: goal),
  );
}

class _GoalSheet extends StatefulWidget {
  final Goal? goal;

  const _GoalSheet({this.goal});

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late GoalType _type;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal?.name ?? '');
    _type = widget.goal?.type ?? GoalType.check;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final store = context.read<AppStore>();
    final name = _nameController.text.trim();
    final goal = widget.goal;
    if (goal == null) {
      await store.addGoal(name, _type);
    } else {
      if (name != goal.name) await store.renameGoal(goal.id, name);
      if (_type != goal.type) await store.setGoalType(goal.id, _type);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _archive() async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive this goal?'),
        content: const Text('It will no longer appear in your daily list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Archive', style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final goal = widget.goal;
    if (goal == null) return;
    await context.read<AppStore>().archiveGoal(goal.id);
    if (mounted) Navigator.pop(context);
  }

  String get _caption => _type == GoalType.check
      ? 'Marked done or not done each day.'
      : 'Track progress from 0 to 100 percent.';

  Widget _label(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: context.textStyles.boldText.copyWith(
        fontSize: 12,
        letterSpacing: 1.2,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              _isEditing ? 'Edit goal' : 'New goal',
              style: context.textStyles.titleText.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 24),
            _label(context, 'NAME'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              maxLength: 50,
              style: context.textStyles.normalText,
              decoration: const InputDecoration(counterText: ''),
              validator: (v) {
                final trimmed = v?.trim() ?? '';
                if (trimmed.isEmpty) return 'Name is required';
                if (trimmed.length > 50) return 'Keep it under 50 characters';
                return null;
              },
            ),
            const SizedBox(height: 24),
            _label(context, 'TYPE'),
            const SizedBox(height: 8),
            SegmentedButton<GoalType>(
              segments: const [
                ButtonSegment(
                  value: GoalType.check,
                  label: Text('Done / not done'),
                ),
                ButtonSegment(
                  value: GoalType.percent,
                  label: Text('Percent 0–100'),
                ),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              _caption,
              style: context.textStyles.thinText.copyWith(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
              ),
              child: Text(_isEditing ? 'Save changes' : 'Add goal'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _archive,
                child: Text(
                  'Archive goal',
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
