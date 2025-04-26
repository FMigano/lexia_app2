import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lexia_app/models/post.dart' as post_model;
import 'package:lexia_app/widgets/post_card.dart';
import 'package:lexia_app/screens/posts/create_post_screen.dart';
import 'package:google_fonts/google_fonts.dart';
// Add this import at the top

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
  List<post_model.Post> _posts = [];
  List<post_model.Post> _filteredPosts = []; // For filtered posts

  // For filtering
  String _searchQuery = '';
  String? _selectedCategory;

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
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);

    if (_currentUserId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load hidden posts first to filter them out
      final hiddenPostsSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('hidden_posts')
          .get();

      final hiddenPostIds =
          hiddenPostsSnapshot.docs.map((doc) => doc.id).toList();

      // Get all posts sorted by creation time
      final postsSnapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .get();

      List<post_model.Post> posts = postsSnapshot.docs
          .where((doc) => !hiddenPostIds.contains(doc.id))
          .map((doc) => post_model.Post.fromFirestore(doc))
          .toList();

      if (mounted) {
        setState(() {
          _posts = posts;
          _filteredPosts = posts; // Initialize with all posts
          _isLoading = false;
        });

        // Apply any existing filters
        if (_selectedCategory != null || _searchQuery.isNotEmpty) {
          _applyFilters();
        }
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Apply both search and category filters
  void _applyFilters() {
    List<post_model.Post> filtered = _posts;

    // Apply category filter if selected
    if (_selectedCategory != null && _selectedCategory != 'All') {
      filtered =
          filtered.where((post) => post.category == _selectedCategory).toList();
    }

    // Apply search filter if provided
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((post) {
        return post.content
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            post.authorName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    setState(() {
      _filteredPosts = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Add this heading section here
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

          // Add this category filter section here
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
                          _applyFilters();
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
                  _applyFilters();
                });
              },
            ),
          ),

          // Post list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPosts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sentiment_dissatisfied,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No posts found',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            if (_searchQuery.isNotEmpty ||
                                _selectedCategory != null)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _selectedCategory = 'All';
                                    _applyFilters();
                                  });
                                },
                                child: const Text('Clear filters'),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPosts,
                        child: ListView.builder(
                          itemCount: _filteredPosts.length,
                          itemBuilder: (context, index) {
                            final post = _filteredPosts[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PostCard(post: post),
                              ],
                            );
                          },
                        ),
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
          ).then((_) => _loadPosts());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // Add this helper method
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
}
