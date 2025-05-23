import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lexia_app/screens/chat/chat_screen.dart';
import 'package:lexia_app/screens/professionals/professional_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:intl/intl.dart';

class ProfessionalsScreen extends StatefulWidget {
  const ProfessionalsScreen({super.key});

  @override
  State<ProfessionalsScreen> createState() => _ProfessionalsScreenState();
}

class _ProfessionalsScreenState extends State<ProfessionalsScreen> {
  String _selectedSpecialty = '';
  String _searchQuery = '';
  String _sortBy = ''; // Add this variable to track sorting option

  final List<String> _specialties = [
    'All',
    'Neurologist',
    'Psychologist',
    'Teacher',
    'Speech Therapist',
    'Occupational Therapist',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Find Professionals',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search professionals...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _specialties.map((specialty) {
                final isSelected = specialty == 'All'
                    ? _selectedSpecialty.isEmpty
                    : specialty == _selectedSpecialty;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      specialty,
                      style: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSpecialty =
                            selected && specialty != 'All' ? specialty : '';
                      });
                    },
                    backgroundColor: specialty == 'All'
                        ? Colors.grey[200]
                        : _getSpecialtyColorWithOpacity(specialty, 0.2),
                    selectedColor: specialty == 'All'
                        ? Colors.blue
                        : _getSpecialtyColor(specialty),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                var professionals = snapshot.data?.docs ?? [];

                // Apply search filter in real-time
                if (_searchQuery.isNotEmpty) {
                  professionals = professionals.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] as String? ?? '';
                    final specialty = data['specialty'] as String? ?? '';
                    final about = data['about'] as String? ?? '';

                    return name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ||
                        specialty
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ||
                        about
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                // Apply sorting if selected
                if (_sortBy.isNotEmpty && professionals.length > 1) {
                  professionals.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;

                    switch (_sortBy) {
                      case 'name_asc':
                        final nameA =
                            (dataA['name'] as String?)?.toLowerCase() ?? '';
                        final nameB =
                            (dataB['name'] as String?)?.toLowerCase() ?? '';
                        return nameA.compareTo(nameB); // A-Z

                      case 'name_desc':
                        final nameA =
                            (dataA['name'] as String?)?.toLowerCase() ?? '';
                        final nameB =
                            (dataB['name'] as String?)?.toLowerCase() ?? '';
                        return nameB.compareTo(nameA); // Z-A

                      default:
                        return 0;
                    }
                  });
                }

                if (professionals.isEmpty) {
                  return const Center(
                    child: Text('No professionals match your search criteria.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: professionals.length,
                  itemBuilder: (context, index) {
                    final professional = professionals[index];
                    final data = professional.data() as Map<String, dynamic>;

                    return _ProfessionalCard(
                      id: professional.id,
                      name: data['name'] ?? 'Unknown',
                      specialty: data['specialty'] ?? 'Not specified',
                      photoUrl: data['photoUrl'] ?? '',
                      rating: (data['rating'] as num?)?.toDouble() ?? 0,
                      ratingCount: data['ratingCount'] as int? ?? 0,
                      about: data['about'] ?? 'No information provided.',
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildQuery() {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'professional');

    if (_selectedSpecialty.isNotEmpty && _selectedSpecialty != 'All') {
      query = query.where('specialty', isEqualTo: _selectedSpecialty);
    }

    return query.snapshots();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sort Professionals',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort by:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(
                'Name (A-Z)',
                style: GoogleFonts.poppins(),
              ),
              leading: Radio<String>(
                value: 'name_asc',
                groupValue: _sortBy,
                onChanged: (value) {
                  setState(() {
                    _sortBy = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: Text(
                'Name (Z-A)',
                style: GoogleFonts.poppins(),
              ),
              leading: Radio<String>(
                value: 'name_desc',
                groupValue: _sortBy,
                onChanged: (value) {
                  setState(() {
                    _sortBy = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSpecialtyColor(String specialty) {
    switch (specialty) {
      case 'Neurologist':
        return const Color(0xFFE91E63); // Vibrant Pink
      case 'Psychologist':
        return const Color(0xFF9C27B0); // Vibrant Purple
      case 'Teacher':
        return const Color(0xFF2196F3); // Vibrant Blue
      case 'Speech Therapist':
        return const Color(0xFFFF9800); // Vibrant Orange
      case 'Occupational Therapist':
        return const Color(0xFF4CAF50); // Vibrant Green
      default:
        return Colors.grey;
    }
  }

  Color _getSpecialtyColorWithOpacity(String specialty, double opacity) {
    final Color baseColor = _getSpecialtyColor(specialty);
    return Color.fromRGBO(
      baseColor.r.toInt(),
      baseColor.g.toInt(),
      baseColor.b.toInt(),
      opacity,
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  final String id;
  final String name;
  final String specialty;
  final String photoUrl;
  final double rating;
  final int ratingCount;
  final String about;

  const _ProfessionalCard({
    required this.id,
    required this.name,
    required this.specialty,
    required this.photoUrl,
    required this.rating,
    required this.ratingCount,
    required this.about,
  });

  @override
  Widget build(BuildContext context) {
    // Add this line to debug
    debugPrint('Professional specialty: "$specialty"');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        // Add this InkWell to make the card tappable
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfessionalDetailScreen(professionalId: id),
            ),
          );
        },
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _getSpecialtyColor(specialty)
                  .withAlpha(128), // 0.5 * 255 = 128
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(fontSize: 24),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            specialty,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _getSpecialtyColor(specialty),
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 80),
                  child: SingleChildScrollView(
                    child: Text(
                      about,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Message'),
                      onPressed: () {
                        _startChat(context, id, name);
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Book'),
                      onPressed: () {
                        _showBookingDialog(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add this method to show the booking dialog
  Future<void> _showBookingDialog(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to book appointments')),
      );
      return;
    }

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay(hour: 9, minute: 0);
    String appointmentReason = '';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Book Appointment with $name'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: const Text('Date'),
                    subtitle: Text(DateFormat.yMMMMd().format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        // Increase the date range to allow more years
                        lastDate: DateTime.now().add(
                            const Duration(days: 365 * 5)), // 5 years ahead
                        // Add these settings to improve year selection
                        initialDatePickerMode: DatePickerMode.day,
                        selectableDayPredicate: (DateTime date) {
                          // Exclude weekends if desired (optional)
                          // return date.weekday != DateTime.saturday && date.weekday != DateTime.sunday;
                          return true; // Allow all days
                        },
                        builder: (BuildContext context, Widget? child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              dialogTheme: const DialogTheme(
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(16)),
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null && picked != selectedDate) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('Time'),
                    subtitle: Text(selectedTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null && picked != selectedTime) {
                        setState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Reason for appointment',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      appointmentReason = value;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Specialty: $specialty',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getSpecialtyColor(specialty),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop({
                    'date': selectedDate,
                    'time': selectedTime,
                    'reason': appointmentReason,
                  });
                },
                child: const Text('BOOK'),
              ),
            ],
          );
        },
      ),
    );

    // Process booking if user confirmed
    if (result != null) {
      final DateTime appointmentDateTime = DateTime(
        result['date'].year,
        result['date'].month,
        result['date'].day,
        result['time'].hour,
        result['time'].minute,
      );

      try {
        // Save to Firestore first (most important)
        await _saveAppointmentToFirestore(
          context,
          currentUser.uid,
          appointmentDateTime,
          result['reason'] as String,
        );

        // Then try adding to calendar (optional)
        try {
          final event = Event(
            title: 'Appointment with $name',
            description: result['reason'].isEmpty
                ? 'Consultation with $name ($specialty)'
                : '${result['reason']}\n\nConsultation with $name ($specialty)',
            location: 'Online Session',
            startDate: appointmentDateTime,
            endDate: appointmentDateTime.add(const Duration(hours: 1)),
            allDay: false,
            iosParams: const IOSParams(
              reminder: Duration(minutes: 30),
            ),
            androidParams: const AndroidParams(
              emailInvites: null,
            ),
          );

          final bool addedToCalendar = await Add2Calendar.addEvent2Cal(event);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(addedToCalendar
                      ? 'Appointment scheduled and added to calendar'
                      : 'Appointment scheduled successfully')),
            );
          }
        } catch (calendarError) {
          // Just show appointment scheduled message if calendar fails
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Appointment scheduled successfully')),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error scheduling appointment: $e')),
          );
        }
      }
    }
  }

  // Store the appointment in Firestore
  Future<void> _saveAppointmentToFirestore(
    BuildContext context,
    String userId,
    DateTime appointmentTime,
    String reason,
  ) async {
    try {
      // Get user's display name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final userName = userDoc.data()?['name'] ?? 'Client';

      // Create the appointment
      await FirebaseFirestore.instance.collection('appointments').add({
        'professionalId': id,
        'professionalName': name,
        'userId': userId,
        'userName': userName,
        'appointmentTime': Timestamp.fromDate(appointmentTime),
        'reason': reason,
        'specialty': specialty,
        'status': 'pending', // pending, confirmed, completed, cancelled
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send a notification to the professional
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': id,
        'senderId': userId,
        'senderName': userName,
        'type': 'appointment_request',
        'message': 'New appointment request from $userName',
        'appointmentTime': Timestamp.fromDate(appointmentTime),
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment with $name has been scheduled!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scheduling appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startChat(
    BuildContext context,
    String professionalId,
    String name,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Check if chat already exists
      final querySnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      String chatId = '';

      for (final doc in querySnapshot.docs) {
        final participants =
            List<String>.from(doc['participants'] as List<dynamic>);
        if (participants.contains(professionalId)) {
          chatId = doc.id;
          break;
        }
      }

      // If no chat exists, create one
      if (chatId.isEmpty) {
        final docRef =
            await FirebaseFirestore.instance.collection('chats').add({
          'participants': [currentUser.uid, professionalId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastSenderId': '',
          'unreadCount': {
            currentUser.uid: 0,
            professionalId: 0,
          },
        });

        chatId = docRef.id;
      }

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              otherUserId: professionalId,
              otherUserName: name,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getSpecialtyColor(String specialty) {
    // Normalize the specialty string
    final normalizedSpecialty = specialty.trim();

    debugPrint('Checking color for: "$normalizedSpecialty"');

    switch (normalizedSpecialty) {
      case 'Neurologist':
        return const Color(0xFFE91E63); // Vibrant Pink
      case 'Psychologist':
        return const Color(0xFF9C27B0); // Vibrant Purple
      case 'Teacher':
        return const Color(0xFF2196F3); // Vibrant Blue
      case 'Speech Therapist':
        return const Color(0xFFFF9800); // Vibrant Orange
      case 'Occupational Therapist':
        return const Color(0xFF4CAF50); // Vibrant Green
      default:
        debugPrint('No match found, using gray for: "$normalizedSpecialty"');
        return Colors.grey;
    }
  }
}
