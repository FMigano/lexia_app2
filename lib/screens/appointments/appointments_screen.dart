import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AppointmentsScreen extends StatefulWidget {
  final bool showAppBar;

  const AppointmentsScreen({
    this.showAppBar = true,
    super.key,
  });

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  String _selectedFilter = 'All';
  bool _isProfessional = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  // ✅ Check if current user is a professional
  Future<void> _checkUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _isProfessional = userData['role'] == 'professional';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please sign in to view appointments'),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', Colors.blue),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', Colors.orange),
                const SizedBox(width: 8),
                _buildFilterChip('Confirmed', Colors.green),
                const SizedBox(width: 8),
                _buildFilterChip('Done', Colors.purple),
              ],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildAppointmentsQuery(currentUser.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final appointments = snapshot.data?.docs ?? [];

              if (appointments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No appointments yet',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: appointments.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final appointment = appointments[index].data() as Map<String, dynamic>;
                  final appointmentId = appointments[index].id;

                  return _AppointmentCard(
                    appointmentId: appointmentId,
                    appointment: appointment,
                    currentUserId: currentUser.uid,
                    isProfessional: _isProfessional, // ✅ Pass professional status
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (!widget.showAppBar) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Appointments',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _buildFilterChip(String label, Color color) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? Colors.white : color,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: color.withOpacity(0.15),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? color : color.withOpacity(0.3),
        width: 1.5,
      ),
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
    );
  }

  // ✅ Updated query to handle both user and professional views
  Stream<QuerySnapshot> _buildAppointmentsQuery(String userId) {
    Query query;

    // ✅ Professionals see appointments where they are the receiver
    if (_isProfessional) {
      query = FirebaseFirestore.instance
          .collection('appointments')
          .where('professionalId', isEqualTo: userId);
    } else {
      // Regular users see appointments they booked
      query = FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: userId);
    }

    // Apply status filter if not "All"
    if (_selectedFilter != 'All') {
      String statusFilter = _selectedFilter == 'Done' ? 'completed' : _selectedFilter.toLowerCase();
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.snapshots();
  }
}

class _AppointmentCard extends StatelessWidget {
  final String appointmentId;
  final Map<String, dynamic> appointment;
  final String currentUserId;
  final bool isProfessional; // ✅ Added to differentiate views

  const _AppointmentCard({
    required this.appointmentId,
    required this.appointment,
    required this.currentUserId,
    required this.isProfessional,
  });

  @override
  Widget build(BuildContext context) {
    final appointmentTime = (appointment['appointmentTime'] as Timestamp).toDate();
    final status = appointment['status'] ?? 'pending';
    final professionalName = appointment['professionalName'] ?? 'Unknown';
    final userName = appointment['userName'] ?? 'Unknown'; // ✅ Get user name
    final specialty = appointment['specialty'] ?? '';
    final reason = appointment['reason'] ?? '';

    // ✅ Show different names based on user type
    final displayName = isProfessional ? userName : professionalName;
    final displayLabel = isProfessional ? 'Client' : 'Professional';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ Show label for professionals
                      if (isProfessional) ...[
                        Text(
                          displayLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (specialty.isNotEmpty && !isProfessional) ...[
                        const SizedBox(height: 4),
                        Text(
                          specialty,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  DateFormat.yMMMMd().format(appointmentTime),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  DateFormat.jm().format(appointmentTime),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Reason for Appointment',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reason,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // ✅ Show action buttons based on user type and status
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isProfessional) ...[
                    // Regular users can cancel
                    TextButton(
                      onPressed: () => _cancelAppointment(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                    ),
                  ] else ...[
                    // Professionals can confirm or decline
                    TextButton(
                      onPressed: () => _declineAppointment(context),
                      child: Text(
                        'Decline',
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _confirmAppointment(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: Text(
                        'Confirm',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            // ✅ Add "Mark as Done" button for confirmed appointments (professionals only)
            if (status == 'confirmed' && isProfessional) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _markAsDone(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                    ),
                    icon: const Icon(Icons.task_alt, color: Colors.white),
                    label: Text(
                      'Mark as Done',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    String displayText;

    switch (status.toLowerCase()) {
      case 'confirmed':
        color = Colors.green;
        icon = Icons.check_circle;
        displayText = 'CONFIRMED';
        break;
      case 'pending':
        color = Colors.orange;
        icon = Icons.pending;
        displayText = 'PENDING';
        break;
      case 'completed':
        color = Colors.purple;
        icon = Icons.task_alt;
        displayText = 'DONE';
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        displayText = 'CANCELLED';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        displayText = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            displayText,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Confirm appointment (for professionals)
  Future<void> _confirmAppointment(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Appointment confirmed successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error confirming appointment: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ Decline appointment (for professionals)
  Future<void> _declineAppointment(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Decline Appointment',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to decline this appointment?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Yes, Decline', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': currentUserId,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Appointment declined',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error declining appointment: $e',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelAppointment(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Cancel Appointment',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to cancel this appointment?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Yes, Cancel', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': currentUserId,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Appointment cancelled successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error cancelling appointment: $e',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ✅ Add this method after _confirmAppointment
  Future<void> _markAsDone(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Appointment marked as done',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.purple,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error marking appointment as done: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
