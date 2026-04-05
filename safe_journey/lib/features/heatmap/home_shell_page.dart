import 'package:flutter/material.dart';
import 'heatmap_page.dart';
import 'safe_route_page.dart';
import 'profile_page.dart';

/// Root shell that owns the bottom [NavigationBar] and an [IndexedStack]
/// so every tab preserves its scroll / map state across switches.
class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  int _currentIndex = 0;

  // Pages are created once; IndexedStack keeps them alive.
  static final List<Widget> _pages = [
    const HeatmapPage(),
    const SafeRoutePage(),
    const ProfilePage(),
  ];

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map),
      label: 'Harita',
    ),
    NavigationDestination(
      icon: Icon(Icons.warning_amber_outlined),
      selectedIcon: Icon(Icons.warning_amber_rounded),
      label: 'Olası Suç Noktaları',
    ),
    NavigationDestination(
      icon: Icon(Icons.alt_route_outlined),
      selectedIcon: Icon(Icons.alt_route),
      label: 'Güvenli Rota',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: _destinations,
        // Keep it compact — no labels on unselected items
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        height: 64,
      ),
    );
  }
}
