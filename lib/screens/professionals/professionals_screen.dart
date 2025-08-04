import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lexia_app/screens/chat/chat_screen.dart';
import 'package:lexia_app/screens/professionals/professional_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ProfessionalsScreen extends StatefulWidget {
  const ProfessionalsScreen({super.key});

  @override
  State<ProfessionalsScreen> createState() => _ProfessionalsScreenState();
}

class _ProfessionalsScreenState extends State<ProfessionalsScreen> {
  String _selectedSpecialty = '';
  String _searchQuery = '';
  String _sortBy = '';

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
                final isSelected = _selectedSpecialty == specialty ||
                    (specialty == 'All' && _selectedSpecialty.isEmpty);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(specialty),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSpecialty = selected ? (specialty == 'All' ? '' : specialty) : '';
                      });
                    },
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
                if (snapshot.connectionState == ConnectionState.waiting) {
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
                    return name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        specialty.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        about.toLowerCase().contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                // Apply sorting if selected
                if (_sortBy.isNotEmpty && professionals.length > 1) {
                  professionals.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;
                    
                    switch (_sortBy) {
                      case 'name':
                        return (dataA['name'] as String? ?? '').compareTo(dataB['name'] as String? ?? '');
                      case 'rating':
                        final ratingA = dataA['rating'] as double? ?? 0.0;
                        final ratingB = dataB['rating'] as double? ?? 0.0;
                        return ratingB.compareTo(ratingA); // Descending order
                      default:
                        return 0;
                    }
                  });
                }

                if (professionals.isEmpty) {
                  return Center(
                    child: Text(
                      'No professionals found',
                      style: GoogleFonts.poppins(),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: professionals.length,
                  itemBuilder: (context, index) {
                    final doc = professionals[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return _ProfessionalCard(
                      id: doc.id,
                      name: data['name'] as String? ?? 'Unknown',
                      specialty: data['specialty'] as String? ?? 'Not specified',
                      photoUrl: data['photoUrl'] as String? ?? '',
                      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
                      ratingCount: data['ratingCount'] as int? ?? 0,
                      about: data['about'] as String? ?? 'No information provided.',
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
              title: const Text('Name'),
              leading: Radio<String>(
                value: 'name',
                groupValue: _sortBy,
                onChanged: (value) {
                  setState(() {
                    _sortBy = value ?? '';
                  });
                  Navigator.of(context).pop();
                },
              ),
            ),
            ListTile(
              title: const Text('Rating'),
              leading: Radio<String>(
                value: 'rating',
                groupValue: _sortBy,
                onChanged: (value) {
                  setState(() {
                    _sortBy = value ?? '';
                  });
                  Navigator.of(context).pop();
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
        return const Color(0xFFE91E63);
      case 'Psychologist':
        return const Color(0xFF9C27B0);
      case 'Teacher':
        return const Color(0xFF2196F3);
      case 'Speech Therapist':
        return const Color(0xFFFF9800);
      case 'Occupational Therapist':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
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
              color: _getSpecialtyColor(specialty).withAlpha(128),
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
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
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
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            specialty,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _getSpecialtyColor(specialty),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (rating > 0)
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                Text(
                                  '${rating.toStringAsFixed(1)} ($ratingCount)',
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                              ],
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
                      style: GoogleFonts.poppins(fontSize: 13),
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

  Future<void> _showBookingDialog(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to book appointments')),
      );
      return;
    }

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
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
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        initialDatePickerMode: DatePickerMode.day,
                        selectableDayPredicate: (DateTime date) {
                          return true; // Allow all days
                        },
                        builder: (BuildContext context, Widget? child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              dialogTheme: const DialogThemeData(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(16)),
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
        // Save to Firestore
        await _saveAppointmentToFirestore(
          context,
          currentUser.uid,
          appointmentDateTime,
          result['reason'] as String,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Appointment with $name scheduled successfully!\n\nDate: ${DateFormat.yMMMMd().format(appointmentDateTime)}\nTime: ${TimeOfDay.fromDateTime(appointmentDateTime).format(context)}\n\nYou can manually add this to your calendar.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
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
  }

  Future<void> _saveAppointmentToFirestore(
    BuildContext context,
    String userId,
    DateTime appointmentTime,
    String reason,
  ) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final userName = userDoc.data()?['name'] ?? 'Client';

      await FirebaseFirestore.instance.collection('appointments').add({
        'professionalId': id,
        'professionalName': name,
        'userId': userId,
        'userName': userName,
        'appointmentTime': Timestamp.fromDate(appointmentTime),
        'reason': reason,
        'specialty': specialty,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

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
    } catch (e) {
      rethrow;
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
      final querySnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      String chatId = '';

      for (final doc in querySnapshot.docs) {
        final participants = List<String>.from(doc['participants'] as List<dynamic>);
        if (participants.contains(professionalId)) {
          chatId = doc.id;
          break;
        }
      }

      if (chatId.isEmpty) {
        final docRef = await FirebaseFirestore.instance.collection('chats').add({
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
    final normalizedSpecialty = specialty.trim();

    switch (normalizedSpecialty) {
      case 'Neurologist':
        return const Color(0xFFE91E63);
      case 'Psychologist':
        return const Color(0xFF9C27B0);
      case 'Teacher':
        return const Color(0xFF2196F3);
      case 'Speech Therapist':
        return const Color(0xFFFF9800);
      case 'Occupational Therapist':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }
}
