import 'dart:io';
import 'package:flutter/material.dart';
// Import with a prefix to avoid ambiguity
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
// Import with a prefix to avoid ambiguity
import 'package:lexia_app/providers/auth_provider.dart' as app_provider;
import 'package:lexia_app/providers/theme_provider.dart';
import 'package:lexia_app/screens/auth/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/terms_and_conditions_screen.dart'; // Add this import

// Ensure this path is correct
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = false;

  Future<void> _uploadProfilePicture() async {
    if (_auth.currentUser == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (image == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final File file = File(image.path);
      final ref = _storage.ref().child(
            'profile_pictures/${_auth.currentUser!.uid}',
          );
      await ref.putFile(file);

      final url = await ref.getDownloadURL();

      await _auth.currentUser!.updatePhotoURL(url);

      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'photoUrl': url,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile picture: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    // Store BOTH navigator and authProvider before any async operation
    final navigator = Navigator.of(context);
    final authProvider =
        Provider.of<app_provider.AuthProvider>(context, listen: false);

    final bool confirmLogout = await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              'Confirm Logout',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.25,
              ),
            ),
            content: Text(
              'Are you sure you want to log out?',
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    // Only proceed with logout if confirmed
    if (confirmLogout) {
      // Use the stored authProvider instead of getting it after the async operation
      await authProvider.signOut();

      if (!mounted) return;

      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final authProvider = Provider.of<app_provider.AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (currentUser == null) {
      return Center(
        child: Text(
          'Not signed in',
          style: GoogleFonts.poppins(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit profile screen
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('users').doc(currentUser.uid).snapshots(),
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
                  print('❌ User document does not exist for UID: ${currentUser.uid}');
                  return Center(
                    child: Text(
                      'User data not found',
                      style: GoogleFonts.poppins(),
                    ),
                  );
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>;
                
                // ADD THESE DEBUG LINES
                print('=== PROFILE DEBUG ===');
                print('User UID: ${currentUser.uid}');
                print('All user data: $userData');
                print('Name field: ${userData['name']}');
                print('Email field: ${userData['email']}');
                print('Role field: ${userData['role']}');
                print('====================');
                
                // FIX THE NAME READING - this is the key fix
                final name = userData['name']?.toString().trim() ?? 
                             userData['fullName']?.toString().trim() ?? 
                             currentUser.displayName?.trim() ?? 
                             'User';
                
                final email = userData['email'] ?? currentUser.email ?? 'No email';
                final role = userData['role'] ?? 'Unknown';

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Profile Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary.withAlpha(204),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundImage: currentUser.photoURL != null
                                      ? NetworkImage(currentUser.photoURL!)
                                      : null,
                                  backgroundColor: Colors.white,
                                  child: currentUser.photoURL == null
                                      ? Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                                          style: GoogleFonts.poppins(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                                      onPressed: _uploadProfilePicture,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name, // This should now show the correct name
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withAlpha(230),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(51),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withAlpha(128)),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Role-specific information section
                      if (role == 'parent') ...[
                        // Child Information Section
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
                                'Child Information',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _EditableField(
                                label: 'Child Name',
                                value: userData['childName'] ?? 'Not set',
                                onEdit: () => _editField('childName', userData['childName'] ?? ''),
                              ),
                              _EditableField(
                                label: 'Child Age',
                                value: userData['childAge']?.toString() ?? 'Not set',
                                onEdit: () => _editField('childAge', userData['childAge']?.toString() ?? ''),
                              ),
                              _EditableField(
                                label: 'Notes',
                                value: userData['notes'] ?? 'No notes added',
                                onEdit: () => _editField('notes', userData['notes'] ?? ''),
                              ),
                            ],
                          ),
                        ),
                      ] else if (role == 'professional') ...[
                        // Professional Information Section
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
                              const SizedBox(height: 16),
                              _EditableField(
                                label: 'Specialty',
                                value: userData['specialty'] ?? 'Not set',
                                onEdit: () => _editField('specialty', userData['specialty'] ?? ''),
                              ),
                              _EditableField(
                                label: 'Experience (years)',
                                value: userData['experience']?.toString() ?? 'Not set',
                                onEdit: () => _editField('experience', userData['experience']?.toString() ?? ''),
                              ),
                              _EditableField(
                                label: 'About',
                                value: userData['about'] ?? 'No information provided',
                                onEdit: () => _editField('about', userData['about'] ?? ''),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Preferences Section
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
                              'Preferences',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Dark Theme Toggle
                            Row(
                              children: [
                                Icon(
                                  Icons.dark_mode,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Dark Theme',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Enable dark mode',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: themeProvider.isDarkMode,
                                  onChanged: (value) {
                                    themeProvider.toggleTheme();
                                  },
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Notifications Toggle
                            Row(
                              children: [
                                Icon(
                                  Icons.notifications,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Notifications',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Enable push notifications',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: true, // You can add a state for this
                                  onChanged: (value) {
                                    // Handle notification preference
                                  },
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Terms & Conditions
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.article_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(
                                'Terms & Conditions',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const TermsAndConditionsScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Sign Out Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout),
                          label: Text(
                            'Sign Out',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _editField(String field, String currentValue) async {
    // Special case for specialty field
    if (field == 'specialty') {
      // List of predefined specialties with icons
      final specialties = [
        {'name': 'Neurologist', 'icon': Icons.psychology},
        {'name': 'Psychologist', 'icon': Icons.person_outline},
        {'name': 'Teacher', 'icon': Icons.school},
        {'name': 'Speech Therapist', 'icon': Icons.record_voice_over},
        {'name': 'Occupational Therapist', 'icon': Icons.accessibility_new},
      ];

      final selectedSpecialty = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose Specialty',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: specialties.map((specialty) {
                      final isSelected = specialty['name'] == currentValue;
                      return ListTile(
                        leading: Icon(
                          specialty['icon'] as IconData,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        title: Text(
                          specialty['name'] as String,
                          style: GoogleFonts.poppins(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () {
                          Navigator.of(context)
                              .pop(specialty['name'] as String);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // Update firestore if a specialty was selected
      if (selectedSpecialty != null && _auth.currentUser != null) {
        try {
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .update({
            'specialty': selectedSpecialty,
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Specialty updated to $selectedSpecialty'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error updating specialty: $e'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
      return;
    }

    // Regular dialog for other fields (unchanged)
    final controller = TextEditingController(text: currentValue);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit ${_getFieldLabel(field)}',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.25,
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: _getFieldLabel(field),
            labelStyle: GoogleFonts.poppins(),
          ),
          style: GoogleFonts.poppins(),
          maxLines: field == 'notes' || field == 'about' ? 5 : 1,
          keyboardType: _getKeyboardType(field),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(controller.text);
            },
            child: Text(
              'Save',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null && _auth.currentUser != null) {
      try {
        final dynamic value = _parseFieldValue(field, result);
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update(
          {field: value},
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_getFieldLabel(field)} updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating ${_getFieldLabel(field)}: $e'),
            ),
          );
        }
      }
    }
  }

  String _getFieldLabel(String field) {
    switch (field) {
      case 'childName':
        return 'Child Name';
      case 'childAge':
        return 'Child Age';
      case 'notes':
        return 'Notes';
      case 'specialty':
        return 'Specialty';
      case 'experience':
        return 'Experience (years)';
      case 'about':
        return 'About';
      default:
        return field;
    }
  }

  TextInputType _getKeyboardType(String field) {
    switch (field) {
      case 'childAge':
        return TextInputType.number;
      case 'experience':
        return TextInputType.number;
      case 'notes':
        return TextInputType.multiline;
      case 'about':
        return TextInputType.multiline;
      default:
        return TextInputType.text;
    }
  }

  dynamic _parseFieldValue(String field, String value) {
    switch (field) {
      case 'childAge':
        return int.tryParse(value) ?? 0;
      case 'experience':
        return int.tryParse(value) ?? 0;
      default:
        return value;
    }
  }
}

class _EditableField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onEdit;
  final IconData icon;

  const _EditableField({
    required this.label,
    required this.value,
    required this.onEdit,
    this.icon = Icons.edit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
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
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(icon: Icon(icon), onPressed: onEdit),
        ],
      ),
    );
  }
}
