import 'package:flutter/material.dart';
import 'package:lexia_app/screens/home/feed_screen.dart';
import 'package:lexia_app/screens/chat/chat_list_screen.dart';
import 'package:lexia_app/screens/professionals/professionals_screen.dart';
import 'package:lexia_app/screens/profile/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:lexia_app/providers/auth_provider.dart';
import 'package:lexia_app/screens/posts/create_post_screen.dart';
import 'package:lexia_app/screens/posts/hidden_posts_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const FeedScreen(),
    const ChatListScreen(),
    const ProfessionalsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Redirect to login if not authenticated
    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }

    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              title: Text(
                'Home',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                // Add this menu to the home feed
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'hidden_posts') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HiddenPostsScreen(),
                        ),
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'hidden_posts',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off),
                          SizedBox(width: 8),
                          Text('Hidden Posts'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Professionals',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              heroTag: 'home_fab', // Add this unique tag
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CreatePostScreen()),
                );
                // Force refresh after returning
                setState(() {});
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
