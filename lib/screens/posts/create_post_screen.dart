import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
// Import with a prefix to avoid ambiguity
import 'package:lexia_app/providers/auth_provider.dart' as app_provider;
import 'package:lexia_app/services/post_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lexia_app/widgets/verification_badge.dart';

class CreatePostScreen extends StatefulWidget {
  final bool? isProfessional;

  const CreatePostScreen({this.isProfessional, super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final PostService _postService = PostService();
  final ImagePicker _picker = ImagePicker();
  List<XFile>? _selectedImages;
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  // Available categories for selection
  final List<String> _categories = [
    'Question',
    'Discussion',
    'Tips',
    'Resource',
    'Success Story',
    'Support',
  ];

  // Selected category - default to Discussion
  String _selectedCategory = 'Discussion';

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Question':
        return Colors.blue;
      case 'Discussion':
        return Colors.purple;
      case 'Tips':
        return Colors.green;
      case 'Resource':
        return Colors.orange;
      case 'Success Story':
        return Colors.teal;
      case 'Support':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Color _getCategoryColorWithOpacity(String category, double opacity) {
    return _getCategoryColor(category).withAlpha((opacity * 255).toInt());
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage() ?? [];

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages = images;
        });
        debugPrint('Selected ${images.length} images');
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  Widget _buildImagePreview() {
    if (_selectedImages == null || _selectedImages!.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages!.length,
        itemBuilder: (context, index) {
          final xFile = _selectedImages![index];

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: FutureBuilder<Uint8List>(
                    future: xFile.readAsBytes(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError || !snapshot.hasData) {
                        debugPrint('Error loading image: ${snapshot.error}');
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image, size: 40),
                        );
                      }

                      return Image.memory(
                        snapshot.data!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedImages!.removeAt(index);
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.7 * 255).toInt()),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
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

  Future<void> _submitPost() async {
    if (_auth.currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You must be signed in to create posts')),
        );
      }
      return;
    }

    final content = _contentController.text.trim();
    if (content.isEmpty &&
        (_selectedImages == null || _selectedImages!.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please add some content to your post.')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final authProvider =
          Provider.of<app_provider.AuthProvider>(context, listen: false);
      final isProfessional =
          authProvider.userRole == app_provider.UserRole.professional;

      debugPrint('Creating post with category: $_selectedCategory');
      debugPrint('Selected images: ${_selectedImages?.length ?? 0}');

      // Call YOUR createPost method instead of _postService.createPost
      await createPost(
        content: content,
        category: _selectedCategory,
        selectedImages: _selectedImages,
        isProfessional: isProfessional,
      );

      debugPrint('Post created successfully');

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }
    } catch (e) {
      debugPrint("Detailed error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating post: $e'),
            backgroundColor: Colors.red,
          ),
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

  Future<DocumentReference?> createPost({
    required String content,
    required String category,
    List<XFile>? selectedImages,
    List<File>? imageFiles,
    bool isProfessional = false,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      // Get user data from Firestore to get the correct name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      String authorName = 'User'; // Default fallback
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        authorName = userData['name']?.toString().trim() ??
                     userData['fullName']?.toString().trim() ??
                     currentUser.displayName?.trim() ??
                     'User';
      }

      // Upload images if provided
      List<String> mediaUrls = [];

      // Handle web uploads using XFile
      if (selectedImages != null && selectedImages.isNotEmpty) {
        mediaUrls = await uploadImageFiles(selectedImages);
      }
      // Handle mobile uploads using File (for backward compatibility)
      else if (imageFiles != null && imageFiles.isNotEmpty) {
        mediaUrls = await uploadImageFiles(
            imageFiles.map((file) => XFile(file.path)).toList());
      }

      // Create the post document
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // When creating posts, include author verification data
      final userData = await firestore.collection('users').doc(currentUser.uid).get();
      final userInfo = userData.data();

      return await firestore.collection('posts').add({
        'content': content,
        'title': '', // For compatibility
        'mediaUrls': mediaUrls,
        'imageIds': [], // For compatibility
        'category': category,
        'authorId': currentUser.uid,
        'authorName': authorName, // Now uses the correct name from Firestore
        'authorPhotoUrl': currentUser.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
        'isProfessionalPost': isProfessional,
        'authorRole': userInfo?['role'],
        'authorVerificationStatus': userInfo?['verificationStatus'],
      });
    } catch (e) {
      debugPrint('Error creating post: $e');
      return null;
    }
  }

  // Add this new method for web uploads
  Future<List<String>> uploadImageFiles(List<XFile> imageFiles) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final List<String> imageUrls = [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      for (int i = 0; i < imageFiles.length; i++) {
        final xFile = imageFiles[i];

        // Read the file bytes directly from XFile
        final bytes = await xFile.readAsBytes();

        if (bytes.isEmpty) {
          debugPrint('File is empty: ${xFile.name}');
          continue;
        }

        // Create a reference for this specific image
        final imageRef = FirebaseStorage.instance
            .ref()
            .child('post_images/${currentUser.uid}/${timestamp}_${xFile.name}');

        try {
          // Upload file data with metadata
          final metadata = SettableMetadata(contentType: 'image/jpeg');
          await imageRef.putData(bytes, metadata);

          // Get download URL
          final downloadUrl = await imageRef.getDownloadURL();
          imageUrls.add(downloadUrl);

          debugPrint('Image uploaded successfully: $downloadUrl');
        } catch (uploadError) {
          debugPrint('Error uploading individual image: $uploadError');
        }
      }

      return imageUrls;
    } catch (e) {
      debugPrint('Error in uploadImageFiles: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Post',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Post',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: _auth.currentUser?.photoURL != null
                        ? NetworkImage(_auth.currentUser!.photoURL!)
                        : null,
                    child: _auth.currentUser?.photoURL == null
                        ? FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(_auth.currentUser!.uid)
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!.exists) {
                                final userData = snapshot.data!.data() as Map<String, dynamic>;
                                final name = userData['name']?.toString().trim() ?? 
                                             userData['fullName']?.toString().trim() ?? 
                                             _auth.currentUser?.displayName?.trim() ?? 
                                             'User';
                                return Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                );
                              }
                              return const Text('?');
                            },
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(_auth.currentUser!.uid)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final userData = snapshot.data!.data() as Map<String, dynamic>;
                          final name = userData['name']?.toString().trim() ?? 
                                       userData['fullName']?.toString().trim() ?? 
                                       _auth.currentUser?.displayName?.trim() ?? 
                                       'Anonymous';
                          final role = userData['role'];
                          final verificationStatus = userData['verificationStatus'];

                          return Row(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              VerificationBadge(
                                role: role,
                                verificationStatus: verificationStatus,
                                size: 18,
                              ),
                            ],
                          );
                        }
                        return const Text(
                          'Anonymous',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post Category',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _categories.map((category) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(
                                category,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: _selectedCategory == category
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _selectedCategory == category
                                      ? Colors.white
                                      : null,
                                ),
                              ),
                              selected: _selectedCategory == category,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedCategory = category;
                                  });
                                }
                              },
                              backgroundColor:
                                  _getCategoryColorWithOpacity(category, 0.15),
                              selectedColor: _getCategoryColor(category),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              TextField(
                controller: _contentController,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: 'What do you want to share?',
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              _buildImagePreview(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.photo_library),
              onPressed: _pickImages,
            ),
          ],
        ),
      ),
    );
  }
}
