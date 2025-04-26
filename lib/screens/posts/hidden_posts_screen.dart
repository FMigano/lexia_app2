import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lexia_app/models/post.dart';
import 'package:lexia_app/widgets/post_card.dart';
import 'package:google_fonts/google_fonts.dart';

class HiddenPostsScreen extends StatefulWidget {
  const HiddenPostsScreen({super.key});

  @override
  State<HiddenPostsScreen> createState() => _HiddenPostsScreenState();
}

class _HiddenPostsScreenState extends State<HiddenPostsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _currentUserId = '';
  bool _isLoading = true;
  List<Post> _hiddenPosts = [];

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid ?? '';
    _loadHiddenPosts();
  }

  Future<void> _loadHiddenPosts() async {
    if (_currentUserId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Get all hidden post IDs
      final hiddenPostsSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('hidden_posts')
          .get();

      List<Post> posts = [];

      // Look up each post by ID
      for (var doc in hiddenPostsSnapshot.docs) {
        try {
          final postDoc =
              await _firestore.collection('posts').doc(doc.id).get();

          if (postDoc.exists && postDoc.data() != null) {
            final postData = postDoc.data()!;
            posts.add(Post.fromMap(postData, postDoc.id));
          }
        } catch (e) {
          debugPrint('Error fetching post ${doc.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _hiddenPosts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading hidden posts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unhidePost(String postId) async {
    try {
      // Delete the reference in the hidden_posts collection
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('hidden_posts')
          .doc(postId)
          .delete();

      // Remove from local list
      setState(() {
        _hiddenPosts.removeWhere((post) => post.id == postId);
      });

      // Add mounted check before using BuildContext
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post unhidden successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error unhiding post: $e');

      // Add mounted check before using BuildContext
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unhide post')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hidden Posts',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hiddenPosts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.visibility_off,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No hidden posts',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Posts you hide will appear here',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _hiddenPosts.length,
                  itemBuilder: (context, index) {
                    final post = _hiddenPosts[index];
                    return Stack(
                      children: [
                        PostCard(post: post),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: ElevatedButton.icon(
                            onPressed: () => _unhidePost(post.id),
                            icon: const Icon(Icons.visibility),
                            label: Text(
                              'Unhide',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
