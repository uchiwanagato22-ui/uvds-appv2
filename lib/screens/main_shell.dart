import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'all_screens.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    PostsScreen(),
    ChatListScreen(),
    ProjectsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.article_outlined), label: 'Posts'),
          NavigationDestination(icon: Icon(Icons.chat_outlined), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Projets'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
