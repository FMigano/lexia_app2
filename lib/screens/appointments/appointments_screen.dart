import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class AppointmentsScreen extends StatefulWidget {
  final bool showAppBar;
  
  const AppointmentsScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> with SingleTickerProviderStateMixin {
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
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Appointments')),
        body: const Center(child: Text('Please sign in to view appointments')),
      );
    }

    final content = Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _AppointmentsList(
                userId: currentUser.uid,
                isPast: false,
              ),
              _AppointmentsList(
                userId: currentUser.uid,
                isPast: true,
              ),
            ],
          ),
        ),
      ],
    );
    
    return widget.showAppBar
      ? Scaffold(
          appBar: AppBar(
            title: Text(
              'My Appointments',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: content,
        )
      : content;
  }
}

class _AppointmentsList extends StatelessWidget {
  final String userId;
  final bool isPast;

  const _AppointmentsList({
    required this.userId,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: userId)
          .orderBy('appointmentTime', descending: isPast)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          // Check specifically for index error
          if (snapshot.error.toString().contains('failed-precondition')) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sync, color: Colors.orange, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Setting up appointments...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'This usually takes a minute or two when first using the app.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final appointments = snapshot.data?.docs ?? [];
        
        // Filter appointments based on past/future
        final filteredAppointments = appointments.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final appointmentTime = (data['appointmentTime'] as Timestamp).toDate();
          
          if (isPast) {
            return appointmentTime.isBefore(now);
          } else {
            return appointmentTime.isAfter(now);
          }
        }).toList();

        if (filteredAppointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPast ? Icons.history : Icons.event_available,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  isPast 
                      ? 'No past appointments' 
                      : 'No upcoming appointments',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                if (!isPast)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Find Professionals'),
                      onPressed: () {
                        // Navigate to ProfessionalsScreen
                      },
                    ),
                  ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredAppointments.length,
          itemBuilder: (context, index) {
            final appointment = filteredAppointments[index];
            final data = appointment.data() as Map<String, dynamic>;
            
            final professionalName = data['professionalName'] as String;
            final specialty = data['specialty'] as String;
            final appointmentTime = (data['appointmentTime'] as Timestamp).toDate();
            final status = data['status'] as String;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            professionalName,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _buildStatusChip(status),
                      ],
                    ),
                    Text(
                      specialty,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.event, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat.yMMMMd().format(appointmentTime),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat.jm().format(appointmentTime),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    if (!isPast && status == 'pending')
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => _cancelAppointment(context, appointment.id),
                              child: const Text('CANCEL'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case 'confirmed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'pending':
        color = Colors.orange;
        icon = Icons.pending;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case 'completed':
        color = Colors.blue;
        icon = Icons.verified;
        break;
      default:
        color = Colors.grey;
        icon = Icons.circle;
    }
    
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 16),
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
  
  Future<void> _cancelAppointment(BuildContext context, String appointmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text('Are you sure you want to cancel this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('NO'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('YES'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .update({'status': 'cancelled'});
            
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment cancelled')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error cancelling appointment: $e')),
          );
        }
      }
    }
  }
}