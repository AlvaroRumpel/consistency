import 'package:consistency/configs/theme.dart';
import 'package:consistency/pages/skelenton.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consistency',
      debugShowCheckedModeBanner: false,
      darkTheme: theme,
      theme: theme,
      home: const Skelenton(),
    );
  }
}