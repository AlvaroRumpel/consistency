import 'package:flutter/material.dart';

import '../configs/l10n_ext.dart';
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
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: context.l10n.navCalendar),
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: context.l10n.navHome),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: context.l10n.navSettings),
        ],
      ),
    );
  }
}
