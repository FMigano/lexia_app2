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

class _AppointmentsScreenState extends State<AppointmentsScreen>
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
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Appointments')),
        body: const Center(child: Text('Please sign in to view appointments')),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }

          final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
          final userRole = userData?['role'] as String? ?? 'parent';
          final bool isProfessional = userRole == 'professional';

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
                      isProfessional: isProfessional,
                    ),
                    _AppointmentsList(
                      userId: currentUser.uid,
                      isPast: true,
                      isProfessional: isProfessional,
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
        });
  }
}

class _AppointmentsList extends StatelessWidget {
  final String userId;
  final bool isPast;
  final bool isProfessional;

  const _AppointmentsList({
    required this.userId,
    required this.isPast,
    required this.isProfessional,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return StreamBuilder<QuerySnapshot>(
      stream: isProfessional
          ? FirebaseFirestore.instance
              .collection('appointments')
              .where('professionalId', isEqualTo: userId)
              .orderBy('appointmentTime', descending: isPast)
              .snapshots()
          : FirebaseFirestore.instance
              .collection('appointments')
              .where('userId', isEqualTo: userId)
              .orderBy('appointmentTime', descending: isPast)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
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

        // Check and update past appointments to "done" status
        _updatePastAppointmentsStatus(appointments);

        final filteredAppointments = appointments.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final appointmentTime =
              (data['appointmentTime'] as Timestamp).toDate();

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
                  isPast ? 'No past appointments' : 'No upcoming appointments',
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
            final appointmentTime =
                (data['appointmentTime'] as Timestamp).toDate();
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
                            // If user is professional, show the user's name, otherwise show professional's name
                            isProfessional
                                ? (data['userName'] ?? 'Client')
                                : professionalName,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _buildStatusChip(status),
                      ],
                    ),

                    // Display role information based on who's viewing
                    Text(
                      isProfessional ? 'Parent/Client' : specialty,
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
                    const SizedBox(height: 16),
                    // Show different buttons based on status and user role
                    if (!isPast && status == 'pending')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Show Accept button only to professionals for pending appointments
                            if (isProfessional)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ElevatedButton(
                                  onPressed: () => _acceptAppointment(
                                      context, appointment.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('ACCEPT'),
                                ),
                              ),

                            // Show Cancel button to everyone for pending appointments
                            OutlinedButton(
                              onPressed: () =>
                                  _cancelAppointment(context, appointment.id),
                              child: const Text('CANCEL'),
                            ),
                          ],
                        ),
                      ),

                    // For accepted appointments, show Reschedule option
                    if (!isPast && status == 'accepted')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => _rescheduleAppointment(
                                  context, appointment.id),
                              child: const Text('RESCHEDULE'),
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
      case 'accepted':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'confirmed': // Keep for backward compatibility
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
      case 'done':
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

  Future<void> _cancelAppointment(
      BuildContext context, String appointmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content:
            const Text('Are you sure you want to cancel this appointment?'),
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

  Future<void> _acceptAppointment(
      BuildContext context, String appointmentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({'status': 'accepted'});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment accepted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting appointment: $e')),
        );
      }
    }
  }

  Future<void> _rescheduleAppointment(
      BuildContext context, String appointmentId) async {
    // This would typically show a date/time picker and then update the appointment
    // For now, just show a placeholder message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reschedule functionality coming soon')),
      );
    }
  }

  void _updatePastAppointmentsStatus(List<QueryDocumentSnapshot> appointments) {
    final now = DateTime.now();

    for (final doc in appointments) {
      final data = doc.data() as Map<String, dynamic>;
      final appointmentTime = (data['appointmentTime'] as Timestamp).toDate();
      final status = data['status'] as String;

      // If appointment is in the past, has been accepted, and isn't already marked
      // cancelled, completed, or done, update it to "done"
      if (appointmentTime.isBefore(now) &&
          (status == 'accepted' || status == 'confirmed') &&
          status != 'cancelled' &&
          status != 'completed' &&
          status != 'done') {
        // Update to "done" status
        FirebaseFirestore.instance
            .collection('appointments')
            .doc(doc.id)
            .update({'status': 'done'}).catchError(
                (e) => debugPrint('Error updating appointment status: $e'));
      }
    }
  }
}

// Add userName field when booking appointments (add this where appointments are created)
// Example: Define the required variables before using them
final currentUser = FirebaseAuth.instance.currentUser;
const professionalId = 'someProfessionalId'; // Replace with actual value
const professionalName = 'Some Professional'; // Replace with actual value
const specialty = 'Specialty'; // Replace with actual value
final appointmentTime = DateTime.now().add(const Duration(days: 1)); // Replace with actual value

final appointmentData = {
  'userId': currentUser?.uid ?? '',
  'userName': currentUser?.displayName ?? 'User',
  'professionalId': professionalId,
  'professionalName': professionalName,
  'specialty': specialty,
  'appointmentTime': appointmentTime,
  'status': 'pending',
  'createdAt': FieldValue.serverTimestamp(),
  // Any other fields...
};
