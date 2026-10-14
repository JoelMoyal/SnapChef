import 'package:flutter/material.dart';

import 'features/accounts/presentation/accounts_screen.dart';
import 'features/ingredients/presentation/ingredients_screen.dart';
import 'features/recipes/presentation/recipes_screen.dart';
import 'theme.dart';

/// Root widget of the app.
class SnapChefApp extends StatelessWidget {
  const SnapChefApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapChef',
      debugShowCheckedModeBanner: false,
      theme: snapChefTheme,
      home: const HomeShell(),
    );
  }
}

/// The main navigation shell: one tab per workstream so the three teams can
/// build their areas independently.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<Widget> _screens = [
    IngredientsScreen(),
    RecipesScreen(),
    AccountsScreen(),
  ];

  static const List<String> _titles = ['Ingredients', 'Recipes', 'Account'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('SnapChef · ${_titles[_index]}')),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Ingredients',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Recipes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
