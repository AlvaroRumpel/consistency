import 'package:consistency/configs/text_styles.dart';
import 'package:flutter/material.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Future.delayed(
      const Duration(milliseconds: 1500),
      () async {
        Navigator.of(context).popAndPushNamed('/skeleton');
      },
    );

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
