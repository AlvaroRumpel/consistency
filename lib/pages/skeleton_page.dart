import 'package:flutter/material.dart';

import 'calendar_page.dart';
import 'home_page.dart';
import 'settings_page.dart';

class SkelentonPage extends StatefulWidget {
  const SkelentonPage({super.key});
  @override
  State<SkelentonPage> createState() => _SkelentonPageState();
}

class _SkelentonPageState extends State<SkelentonPage> {
  int _index = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: const [CalendarPage(), HomePage(), SettingsPage()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendar'),
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}
