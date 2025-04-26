import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lexia_app/screens/chat/chat_screen.dart';
import 'package:lexia_app/screens/professionals/professional_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfessionalsScreen extends StatefulWidget {
  const ProfessionalsScreen({super.key});

  @override
  State<ProfessionalsScreen> createState() => _ProfessionalsScreenState();
}

class _ProfessionalsScreenState extends State<ProfessionalsScreen> {
  String _selectedSpecialty = '';

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
                  // Removed unused _searchQuery field
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final professionals = snapshot.data?.docs ?? [];

                if (professionals.isEmpty) {
                  return const Center(
                    child: Text('No professionals match your search criteria.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: professionals.length,
                  itemBuilder: (context, index) {
                    final profesional = professionals[index];
                    final data = profesional.data() as Map<String, dynamic>;

                    return _ProfessionalCard(
                      id: profesional.id,
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

    if (_selectedSpecialty.isNotEmpty) {
      query = query.where('specialty', isEqualTo: _selectedSpecialty);
    }

    return query.snapshots();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Professionals'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort by:'),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Rating (High to Low)'),
              leading: Radio<String>(
                value: 'rating',
                groupValue: 'rating', // Add state management for this
                onChanged: (value) {
                  Navigator.pop(context);
                  // Implement sorting
                },
              ),
            ),
            ListTile(
              title: const Text('Experience (Most to Least)'),
              leading: Radio<String>(
                value: 'experience',
                groupValue: 'rating',
                onChanged: (value) {
                  Navigator.pop(context);
                  // Implement sorting
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
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
                        // Implement booking functionality
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
