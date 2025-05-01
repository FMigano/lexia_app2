import 'package:flutter/material.dart';
import 'package:lexia_app/screens/chat/chat_list_screen.dart';
import 'package:lexia_app/screens/appointments/appointments_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatAndAppointmentsScreen extends StatefulWidget {
  const ChatAndAppointmentsScreen({super.key});

  @override
  State<ChatAndAppointmentsScreen> createState() => _ChatAndAppointmentsScreenState();
}

class _ChatAndAppointmentsScreenState extends State<ChatAndAppointmentsScreen> with SingleTickerProviderStateMixin {
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Appointments'),
          ],
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