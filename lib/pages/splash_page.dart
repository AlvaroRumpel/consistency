import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../configs/l10n_ext.dart';
import '../configs/text_styles.dart';
import '../state/app_store.dart';
import '../state/settings_store.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = context.read<AppStore>();
      // Already loaded (widget tests seed it) — nothing to wait for.
      if (!store.loaded && store.loadError == null) {
        final completer = Completer<void>();
        void onStoreChanged() {
          if ((store.loaded || store.loadError != null) &&
              !completer.isCompleted) {
            completer.complete();
          }
        }

        store.addListener(onStoreChanged);
        try {
          await completer.future;
        } finally {
          store.removeListener(onStoreChanged);
        }
      }
      if (!mounted) return;
      final settings = context.read<SettingsStore>();
      final hasGoals = store.data.goals.isNotEmpty;
      // A user who already has goals (e.g. the v1 migration) must never see
      // onboarding, even if the flag was never set.
      if (!settings.onboardingDone && hasGoals) {
        await settings.setOnboardingDone(true);
      }
      if (mounted) {
        // An empty store after a failed load is not a fresh install: sending
        // that user to onboarding would have them create a goal on top of
        // data we simply could not read. Home shows the error instead, and
        // onboardingDone stays false so a later good load still routes right.
        final target =
            (!settings.onboardingDone && !hasGoals && store.loadError == null)
                ? '/onboarding'
                : '/manager';
        Navigator.pushNamedAndRemoveUntil(context, target, (_) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset('assets/images/Consistency.png', scale: 2),
                  const SizedBox(
                    height: 280,
                    width: 280,
                    child: CircularProgressIndicator(),
                  ),
                ],
              ),
            ),
          ),
          Text(
            context.l10n.madeWithLove,
            style: context.textStyles.normalText,
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 16,
          ),
        ],
      ),
    );
  }
}
