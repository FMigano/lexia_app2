import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lexia_app/models/post.dart' as post_model;
import 'package:lexia_app/widgets/post_card.dart';
import 'package:lexia_app/screens/posts/create_post_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _currentUserId = '';
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedCategory;

  // Add hiddenPostIds to track which posts are hidden
  List<String> _hiddenPostIds = [];

  // Define available categories
  final List<String> _categories = [
    'All', // Default option to see all posts
    'Question',
    'Discussion',
    'Tips',
    'Resource',
    'Success Story',
    'Support',
  ];

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid ?? '';
    _loadHiddenPosts();
  }

  // New method to load hidden post IDs
  Future<void> _loadHiddenPosts() async {
    setState(() => _isLoading = true);

    if (_currentUserId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final hiddenPostsSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('hidden_posts')
          .get();

      if (mounted) {
        setState(() {
          _hiddenPostIds =
              hiddenPostsSnapshot.docs.map((doc) => doc.id).toList();
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

  // A method to add a post ID to hidden posts (call this from PostCard)
  void addHiddenPost(String postId) {
    setState(() {
      _hiddenPostIds.add(postId);
    });
  }

  // Update your _buildPostsQuery method:
  Stream<QuerySnapshot> _buildPostsQuery() {
    Query query = _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true);

    // Apply category filter - fix the null check
    if (_selectedCategory != null && _selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Heading section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Community Feed',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Category filter section
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _categories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: FilterChip(
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
                        setState(() {
                          _selectedCategory = selected ? category : 'All';
                        });
                      },
                      backgroundColor: category == 'All'
                          ? Colors.grey[200]
                          : _getCategoryColorWithOpacity(category, 0.15),
                      selectedColor: category == 'All'
                          ? Colors.blue
                          : _getCategoryColor(category),
                      checkmarkColor: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Search bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search posts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Post list with stream to update hidden posts in real time
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(_currentUserId)
                        .collection('hidden_posts')
                        .snapshots(),
                    builder: (context, hiddenSnapshot) {
                      // Update hidden post IDs from the stream
                      if (hiddenSnapshot.hasData && !hiddenSnapshot.hasError) {
                        _hiddenPostIds = hiddenSnapshot.data!.docs
                            .map((doc) => doc.id)
                            .toList();
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: _buildPostsQuery(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(
                                child: Text('Error: ${snapshot.error}'));
                          }

                          final allPosts = snapshot.data?.docs ?? [];

                          if (allPosts.isEmpty) {
                            return const Center(child: Text('No posts yet'));
                          }

                          // Apply filters in real-time including hidden posts filter
                          var filteredPosts = allPosts.where((doc) {
                            // Filter out hidden posts first!
                            return !_hiddenPostIds.contains(doc.id);
                          }).toList();

                          // Filter by category if selected
                          if (_selectedCategory != null &&
                              _selectedCategory != 'All') {
                            filteredPosts = filteredPosts.where((doc) {
                              final postData =
                                  doc.data() as Map<String, dynamic>;
                              return postData['category'] == _selectedCategory;
                            }).toList();
                          }

                          // Apply search filter
                          if (_searchQuery.isNotEmpty) {
                            filteredPosts = filteredPosts.where((doc) {
                              final postData =
                                  doc.data() as Map<String, dynamic>;
                              final content =
                                  postData['content'] as String? ?? '';
                              final authorName =
                                  postData['authorName'] as String? ?? '';

                              return content
                                      .toLowerCase()
                                      .contains(_searchQuery.toLowerCase()) ||
                                  authorName
                                      .toLowerCase()
                                      .contains(_searchQuery.toLowerCase());
                            }).toList();
                          }

                          if (filteredPosts.isEmpty) {
                            return const Center(
                                child: Text('No posts match your filters'));
                          }

                          return ListView.builder(
                            itemCount: filteredPosts.length,
                            itemBuilder: (context, index) {
                              final post = filteredPosts[index].data()
                                  as Map<String, dynamic>;
                              final postId = filteredPosts[index].id;

                              return PostCard(
                                post: post_model.Post.fromMap(post, postId),
                                onPostHidden: (id) {
                                  // Immediately update the UI when a post is hidden
                                  setState(() {
                                    _hiddenPostIds.add(id);
                                  });
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreatePostScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // Helper methods for category colors
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Question':
        return const Color(0xFF2196F3); // Vibrant Blue
      case 'Discussion':
        return const Color(0xFF9C27B0); // Vibrant Purple
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
        baseColor.red, baseColor.green, baseColor.blue, opacity);
  }
}
