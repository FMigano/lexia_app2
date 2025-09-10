import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexia_app/widgets/verification_badge.dart';

class ProfessionalDetailScreen extends StatelessWidget {
  final String professionalId;

  const ProfessionalDetailScreen({
    super.key,
    required this.professionalId,
  });

  Color _getProfessionColor(String profession) {
    switch (profession.toLowerCase()) {
      case 'neurologist':
        return const Color(0xFFE91E63);
      case 'psychologist':
        return const Color(0xFF9C27B0);
      case 'teacher':
        return const Color(0xFF2196F3);
      case 'speech therapist':
        return const Color(0xFFFF9800);
      case 'occupational therapist':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Professional Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
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
                'Error loading profile',
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

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final profession = userData['profession'] ?? userData['specialty'] ?? 'Professional';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getProfessionColor(profession),
                        _getProfessionColor(profession).withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Profile Picture
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            backgroundImage: userData['photoUrl'] != null && userData['photoUrl'].isNotEmpty
                                ? NetworkImage(userData['photoUrl'])
                                : null,
                            child: userData['photoUrl'] == null || userData['photoUrl'].isEmpty
                                ? Text(
                                    userData['name']?.isNotEmpty == true 
                                        ? userData['name'][0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.poppins(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: _getProfessionColor(profession),
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Name
                      Text(
                        userData['name'] ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Email
                      Text(
                        userData['email'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'PROFESSIONAL',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Professional Information Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withAlpha(76),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Professional Information',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Profession Field (Locked)
                      _buildLockedField(
                        context,
                        'Profession',
                        profession,
                        userData['verificationStatus'] == 'verified',
                      ),
                      
                      // Experience Field
                      _buildInfoField(
                        context,
                        'Experience (years)',
                        userData['experience']?.toString() ?? 'Not specified',
                      ),
                      
                      // About Field
                      _buildInfoField(
                        context,
                        'About',
                        userData['about'] ?? 'No information provided',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLockedField(BuildContext context, String label, String value, bool isVerified) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified,
                        size: 12,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isVerified 
                  ? Colors.green.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isVerified 
                    ? Colors.green.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      height: 1.4,
                      color: isVerified 
                          ? Colors.green[800]
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isVerified ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(
                  isVerified ? Icons.verified : Icons.info_outline,
                  color: isVerified ? Colors.green[600] : Colors.grey[500],
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField(BuildContext context, String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
