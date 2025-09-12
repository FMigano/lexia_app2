import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lexia_app/screens/chat/chat_screen.dart';
import 'package:lexia_app/screens/professionals/professional_detail_screen.dart';
import 'package:lexia_app/widgets/verification_badge.dart'; // Add this import at the top
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
          // Replace your SingleChildScrollView section with this colored filter chips:
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _specialties.map((specialty) {
                final isSelected = _selectedSpecialty == specialty ||
                    (specialty == 'All' && _selectedSpecialty.isEmpty);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                _getSpecialtyColor(specialty),
                                _getSpecialtyColor(specialty).withOpacity(0.8),
                              ],
                            )
                          : null,
                      border: Border.all(
                        color: _getSpecialtyColor(specialty),
                        width: 1.5,
                      ),
                      color: isSelected ? null : Colors.grey.shade50,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            _selectedSpecialty = isSelected ? '' : (specialty == 'All' ? '' : specialty);
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              if (isSelected) const SizedBox(width: 4),
                              Text(
                                specialty,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.white : _getSpecialtyColor(specialty),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(), // Use the filtered query method instead of hardcoded query
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var professionals = snapshot.data?.docs ?? [];

                // Apply search filter if search query exists
                if (_searchQuery.isNotEmpty) {
                  professionals = professionals.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final profession = (data['profession'] ?? data['specialty'] ?? '').toString().toLowerCase();
                    final about = (data['about'] ?? '').toString().toLowerCase();
                    
                    return name.contains(_searchQuery.toLowerCase()) ||
                           profession.contains(_searchQuery.toLowerCase()) ||
                           about.contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                if (professionals.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty 
                              ? 'No professionals found matching "$_searchQuery"'
                              : _selectedSpecialty.isNotEmpty
                                  ? 'No $_selectedSpecialty professionals found'
                                  : 'No verified professionals found',
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: professionals.length,
                  itemBuilder: (context, index) {
                    final professional = professionals[index].data() as Map<String, dynamic>;

                    return _ProfessionalCard(
                      id: professionals[index].id,
                      name: professional['name'] ?? 'Unknown',
                      specialty: professional['profession'] ?? professional['specialty'] ?? 'Not specified',
                      photoUrl: professional['photoUrl'] ?? '',
                      rating: (professional['rating'] as num?)?.toDouble() ?? 0.0,
                      ratingCount: professional['ratingCount'] ?? 0,
                      about: professional['about'] ?? '',
                      role: professional['role'],
                      verificationStatus: professional['verificationStatus'],
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
        .where('role', isEqualTo: 'professional')
        .where('verificationStatus', isEqualTo: 'verified');

    // Only apply specialty filter if it's not empty and not "All"
    if (_selectedSpecialty.isNotEmpty && _selectedSpecialty != 'All') {
      query = query.where('profession', isEqualTo: _selectedSpecialty);
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

  // Replace your incomplete _buildProfessionBadge method with this:
  Widget _buildProfessionBadge(String profession) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getProfessionColor(profession),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        profession,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  // Complete your _getProfessionColor method:
  Color _getProfessionColor(String profession) {
    switch (profession.toLowerCase()) {
      case 'neurologist':
        return Colors.red.shade500;
      case 'psychologist':
        return Colors.purple.shade500;
      case 'teacher':
        return Colors.green.shade500;
      case 'speech therapist':
        return Colors.blue.shade500;
      case 'occupational therapist':
        return Colors.orange.shade500;
      default:
        return Colors.grey.shade500;
    }
  }

  // Update your _getSpecialtyColor method to include 'All':
  Color _getSpecialtyColor(String specialty) {
    switch (specialty) {
      case 'All':
        return const Color(0xFF6C63FF); // Purple for "All"
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

  dynamic _parseFieldValue(String field, String value) {
    switch (field) {
      case 'experience':
      case 'age':
      case 'ratingCount':
        // Make sure to parse strings to integers
        return int.tryParse(value) ?? 0; // This converts string to int safely
      case 'rating':
        return double.tryParse(value) ?? 0.0; // This converts string to double
      default:
        return value; // Keep as string for other fields
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
  final String? role; // Add this
  final String? verificationStatus; // Add this

  const _ProfessionalCard({
    required this.id,
    required this.name,
    required this.specialty,
    required this.photoUrl,
    required this.rating,
    required this.ratingCount,
    required this.about,
    this.role, // Add this
    this.verificationStatus, // Add this
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfessionalDetailScreen(
                professionalId: id,
              ),
            ),
          );
        },
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _getSpecialtyColor(specialty), // Add colored border to card
              width: 2.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Add verification badge here
                              VerificationBadge(
                                role: role,
                                verificationStatus: verificationStatus,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Remove border from badge - keep it simple
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getSpecialtyColor(specialty),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              specialty,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
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
