import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../configs/text_styles.dart';
import '../state/app_store.dart';

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
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/manager', (_) => false);
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
            'Made with ♥ by Álvaro Rumpel',
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
