import 'package:flutter/material.dart';
import 'package:lexia_app/screens/chat/chat_list_screen.dart';
import 'package:lexia_app/screens/appointments/appointments_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatAndAppointmentsScreen extends StatefulWidget {
  const ChatAndAppointmentsScreen({super.key});

  @override
  State<ChatAndAppointmentsScreen> createState() =>
      _ChatAndAppointmentsScreenState();
}

class _ChatAndAppointmentsScreenState extends State<ChatAndAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Communication',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Only show these actions when on the Chats tab
          if (_tabController.index == 0) ...[
            // Notes to Self button
            IconButton(
              icon: const Icon(Icons.note_add),
              tooltip: 'Notes to Self',
              onPressed: () {
                // Since we're in a different class, we need to delegate to ChatListScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatListScreen(
                      // Removed undefined key
                      showAppBar: true,
                      initialAction: 'self_notes',
                    ),
                  ),
                );
              },
            ),
            // Find User menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.person_add),
              tooltip: 'Find User',
              onSelected: (value) {
                // Navigate to ChatListScreen with the selected action
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatListScreen(
                      showAppBar: true,
                      initialAction: value,
                    ),
                  ),
                );
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'find_parent',
                  child: Text(
                    'Find Parent',
                    style: GoogleFonts.poppins(),
                  ),
                ),
                PopupMenuItem(
                  value: 'find_professional',
                  child: Text(
                    'Find Professional',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Appointments'),
          ],
          onTap: (_) => setState(() {}), // Refresh to update action buttons
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ChatListContent(),
          AppointmentsContent(),
        ],
      ),
    );
  }
}

// Extract just the content part of ChatListScreen without the AppBar
class ChatListContent extends StatelessWidget {
  const ChatListContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Copy the body content from your ChatListScreen here, without the Scaffold/AppBar
    return const ChatListScreen(showAppBar: false);
  }
}

// Extract just the content part of AppointmentsScreen without the AppBar
class AppointmentsContent extends StatelessWidget {
  const AppointmentsContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Copy the body content from your AppointmentsScreen here, without the Scaffold/AppBar
    return const AppointmentsScreen(showAppBar: false);
  }
}
