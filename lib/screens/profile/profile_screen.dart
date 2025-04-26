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
          'You need to be logged in to view your profile',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
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
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userData =
                    snapshot.data?.data() as Map<String, dynamic>? ?? {};

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: currentUser.photoURL != null
                                ? NetworkImage(currentUser.photoURL!)
                                : null,
                            child: currentUser.photoURL == null
                                ? Text(
                                    (currentUser.displayName ?? '?')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(fontSize: 48),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt),
                                color: Theme.of(context).colorScheme.onPrimary,
                                onPressed: _uploadProfilePicture,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        currentUser.displayName ?? 'User',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        currentUser.email ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(
                          authProvider.userRole ==
                                  app_provider.UserRole.professional
                              ? 'Professional'
                              : 'Parent',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: authProvider.userRole ==
                                app_provider.UserRole.professional
                            ? Colors.blue
                            : Colors.green,
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      if (authProvider.userRole ==
                          app_provider.UserRole.parent) ...[
                        Text(
                          'Child Information',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.25,
                          ),
                        ),
                        _EditableField(
                          label: 'Child Name',
                          value: userData['childName'] as String? ?? 'Not set',
                          onEdit: () => _editField(
                            'childName',
                            userData['childName'] as String? ?? '',
                          ),
                        ),
                        _EditableField(
                          label: 'Child Age',
                          value: userData['childAge'] != null
                              ? '${userData['childAge']} years'
                              : 'Not set',
                          onEdit: () => _editField(
                            'childAge',
                            userData['childAge']?.toString() ?? '',
                          ),
                        ),
                        _EditableField(
                          label: 'Notes',
                          value:
                              userData['notes'] as String? ?? 'No notes added',
                          onEdit: () => _editField(
                            'notes',
                            userData['notes'] as String? ?? '',
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 16),
                      ],
                      if (authProvider.userRole ==
                          app_provider.UserRole.professional) ...[
                        Text(
                          'Professional Information',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.25,
                          ),
                        ),
                        _EditableField(
                          label: 'Specialty',
                          value: userData['specialty'] as String? ?? 'Not set',
                          onEdit: () => _editField(
                            'specialty',
                            userData['specialty'] as String? ?? '',
                          ),
                        ),
                        _EditableField(
                          label: 'Experience',
                          value: userData['experience'] != null
                              ? '${userData['experience']} years'
                              : 'Not set',
                          onEdit: () => _editField(
                            'experience',
                            userData['experience']?.toString() ?? '',
                          ),
                        ),
                        _EditableField(
                          label: 'About',
                          value: userData['about'] as String? ??
                              'No information added',
                          onEdit: () => _editField(
                            'about',
                            userData['about'] as String? ?? '',
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'Preferences',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.25,
                        ),
                      ),
                      SwitchListTile(
                        title: Text(
                          'Dark Theme',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Enable dark mode',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        value: themeProvider.isDarkMode,
                        onChanged: (value) {
                          themeProvider.toggleTheme();
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Notifications'),
                        subtitle: const Text('Enable push notifications'),
                        value: userData['notifications'] as bool? ?? true,
                        onChanged: (value) async {
                          await _firestore
                              .collection('users')
                              .doc(currentUser.uid)
                              .update({'notifications': value});
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start chatting with parents or professionals',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _editField(String field, String currentValue) async {
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

  const _EditableField({
    required this.label,
    required this.value,
    required this.onEdit,
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
          IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
        ],
      ),
    );
  }
}
