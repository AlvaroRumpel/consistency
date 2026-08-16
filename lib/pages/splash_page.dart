import 'dart:developer';

import 'package:flutter/material.dart';

import '../configs/local_data.dart';
import '../configs/text_styles.dart';

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
      // Warm the storage singleton; if it fails, the pages surface the error.
      try {
        await LocalData.i;
      } catch (e, s) {
        log('LocalData init failed', error: e, stackTrace: s);
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
