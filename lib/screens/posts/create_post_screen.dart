import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Add this import
import 'package:provider/provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // Add this import
// Import with a prefix to avoid ambiguity
import 'package:lexia_app/providers/auth_provider.dart' as app_provider;
import 'package:google_fonts/google_fonts.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImages.add(File(image.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Question':
        return const Color(0xFF9C27B0); // Vibrant Purple
      case 'Discussion':
        return const Color(0xFF2196F3); // Vibrant Blue
      case 'Tips':
        return const Color(0xFF4CAF50); // Vibrant Green
      case 'Resource':
        return const Color(0xFFFF9800); // Vibrant Orange
      case 'Success Story':
        return const Color(0xFF009688); // Vibrant Teal
      case 'Support':
        return const Color(0xFFF44336); // Vibrant Red
      default:
        return Colors.grey;
    }
  }

  Color _getCategoryColorWithOpacity(String category, double opacity) {
    final Color baseColor = _getCategoryColor(category);
    return Color.fromRGBO(
        baseColor.r.toInt(), // Add toInt() here
        baseColor.g.toInt(), // Add toInt() here
        baseColor.b.toInt(), // Add toInt() here
        opacity);
  }

  Future<void> _submitPost() async {
    // Check if user is authenticated first
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to create posts')),
      );
      return;
    }

    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content to your post.')),
      );
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

      // Process images BEFORE creating the post document
      List<String> mediaUrls = [];

      if (_selectedImages.isNotEmpty) {
        // Use a list of futures to track all uploads
        List<Future<String>> uploadFutures = [];

        for (File image in _selectedImages) {
          // Create a future for each upload and add it to the list
          uploadFutures.add(_uploadImageToFirebase(image));
        }

        // Wait for ALL uploads to complete before continuing
        try {
          mediaUrls = await Future.wait(uploadFutures);
          debugPrint(
              '📸 ALL images uploaded successfully. Total: ${mediaUrls.length}');
        } catch (e) {
          debugPrint('❌ Error waiting for image uploads: $e');
        }
      }

      // Now create the post with image URLs instead of base64 data
      debugPrint(
          '📝 Creating post with ${mediaUrls.length} images: $mediaUrls');

      final docRef = await _firestore.collection('posts').add({
        'authorId': currentUser.uid,
        'authorName': currentUser.displayName ?? '',
        'authorPhotoUrl': currentUser.photoURL ?? '',
        'content': content,
        'mediaUrls': mediaUrls, // These should be the download URLs
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
        'isProfessionalPost': isProfessional,
        'category': _selectedCategory,
      });

      debugPrint('📝 Post created with ID: ${docRef.id}');

      // Double check the document was created correctly
      final createdDoc = await docRef.get();
      debugPrint('📝 Verifying document contents:');
      debugPrint(
          '📝 mediaUrls in document: ${createdDoc.data()?['mediaUrls']}');

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }
    } catch (e) {
      debugPrint("Detailed firestore error: $e");
      if (e.toString().contains('permission-denied')) {
        debugPrint("User ID: ${_auth.currentUser?.uid}");
        debugPrint("Is email verified: ${_auth.currentUser?.emailVerified}");
      }
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

  Future<String> _uploadImageToFirebase(File image) async {
    try {
      final bytes = await image.readAsBytes();
      final currentUser = _auth.currentUser!;

      final resizedImg = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 500,
        minWidth: 500,
        quality: 30,
      );

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid}.jpg';
      final ref = FirebaseStorage.instance.ref().child('posts').child(fileName);

      final uploadTask = ref.putData(
        resizedImg,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error in _uploadImageToFirebase: $e');
      rethrow; // Re-throw to be caught by the caller
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
      body: SingleChildScrollView(
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
                      ? Text(
                          (_auth.currentUser?.displayName ?? '?')[0]
                              .toUpperCase(),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  _auth.currentUser?.displayName ?? 'Anonymous',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(_selectedImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.photo_library),
              onPressed: _pickImage,
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: () async {
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                );

                if (image != null) {
                  setState(() {
                    _selectedImages.add(File(image.path));
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
