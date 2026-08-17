import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../configs/l10n_ext.dart';
import '../configs/text_styles.dart';
import '../models/goal.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';

/// First-run screen: collects a nickname and the first goal, then hands off
/// to Home. Skipped entirely for installs that already have goals (see
/// SplashPage, which also covers the v1-migration case).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _nicknameController = TextEditingController();
  final _goalController = TextEditingController();
  GoalType _type = GoalType.check;
  bool _busy = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final goalName = _goalController.text.trim();
    if (_busy || goalName.isEmpty) return;
    _busy = true;
    try {
      final settings = context.read<SettingsStore>();
      final store = context.read<AppStore>();
      final nickname = _nicknameController.text.trim();
      if (nickname.isNotEmpty) await settings.setNickname(nickname);
      await store.addGoal(goalName, _type);
      await settings.setOnboardingDone(true);
      if (mounted) Navigator.pushReplacementNamed(context, '/manager');
    } finally {
      _busy = false;
    }
  }

  String get _caption => _type == GoalType.check
      ? context.l10n.typeCheckCaption
      : context.l10n.typePercentCaption;

  Widget _heading(BuildContext context, String text) {
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.welcomeTitle,
                  style: context.textStyles.titleText),
              const SizedBox(height: 8),
              Text(
                context.l10n.welcomeSubtitle,
                style: context.textStyles.thinText
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(context.l10n.whatShouldWeCallYou,
                        style: context.textStyles.boldText),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('onboarding-nickname'),
                      controller: _nicknameController,
                      maxLength: 25,
                      style: context.textStyles.normalText,
                      decoration: InputDecoration(
                        hintText: context.l10n.yourName,
                        counterText: '',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _heading(context, context.l10n.yourFirstGoal),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('onboarding-goal-name'),
                controller: _goalController,
                maxLength: 50,
                style: context.textStyles.normalText,
                decoration: InputDecoration(
                  labelText: context.l10n.goalName,
                  hintText: context.l10n.goalNameHint,
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              SegmentedButton<GoalType>(
                segments: [
                  ButtonSegment(
                    value: GoalType.check,
                    label: Text(context.l10n.typeCheck),
                  ),
                  ButtonSegment(
                    value: GoalType.percent,
                    label: Text(context.l10n.typePercent),
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
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _busy || _goalController.text.trim().isEmpty
                    ? null
                    : _start,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                ),
                child: Text(context.l10n.start),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
