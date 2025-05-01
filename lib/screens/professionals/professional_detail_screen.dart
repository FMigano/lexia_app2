import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lexia_app/screens/chat/chat_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfessionalDetailScreen extends StatelessWidget {
  final String professionalId;

  const ProfessionalDetailScreen({super.key, required this.professionalId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Professional Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(professionalId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: GoogleFonts.poppins(),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Professional not found',
                style: GoogleFonts.poppins(),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final name = data['name'] as String? ?? 'Unknown';
          final specialty = data['specialty'] as String? ?? 'Not specified';
          final photoUrl = data['photoUrl'] as String? ?? '';
          final about = data['about'] as String? ?? 'No information provided.';
          final experience = data['experience'] as int? ?? 0;
          final education = data['education'] as String? ?? 'Not specified';
          final services = List<String>.from(data['services'] ?? []);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(fontSize: 36),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            specialty,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'About',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  about,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.work,
                  label: 'Experience',
                  value: '$experience years',
                ),
                _InfoRow(
                  icon: Icons.school,
                  label: 'Education',
                  value: education,
                ),
                const SizedBox(height: 24),
                if (services.isNotEmpty) ...[
                  Text(
                    'Services',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: services.map((service) {
                      return Chip(
                        label: Text(
                          service,
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _startChat(BuildContext context) async {
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
        final participants = List<String>.from(
          doc['participants'] as List<dynamic>,
        );
        if (participants.contains(professionalId)) {
          chatId = doc.id;
          break;
        }
      }

      // If no chat exists, create one
      if (chatId.isEmpty) {
        final docRef = await FirebaseFirestore.instance.collection('chats').add(
          {
            'participants': [currentUser.uid, professionalId],
            'createdAt': FieldValue.serverTimestamp(),
            'lastMessage': '',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastSenderId': '',
            'unreadCount': {currentUser.uid: 0, professionalId: 0},
          },
        );

        chatId = docRef.id;
      }

      if (context.mounted) {
        // Get professional name
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(professionalId)
            .get();

        final name = (doc.data()?['name'] as String?) ?? 'Professional';

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
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
              ),
              Text(value, style: GoogleFonts.poppins(fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
