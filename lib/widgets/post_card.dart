import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lexia_app/models/post.dart' as post_model;
import 'package:timeago/timeago.dart' as timeago;
import 'package:lexia_app/screens/comments/comments_screen.dart';
import 'package:lexia_app/screens/posts/edit_post_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexia_app/services/post_service.dart';
import 'dart:convert';

class PostCard extends StatefulWidget {
  final post_model.Post post;
  final Function(String)? onPostHidden; // Add this callback

  const PostCard({
    super.key,
    required this.post,
    this.onPostHidden, // Optional callback
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PostService _postService = PostService();
  String _currentUserId = '';
  final List<String> _imageData = [];

  // Test with a guaranteed working tiny base64 image
  Widget _createTestImage() {
    // This is a 1x1 red pixel
    const testBase64 =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

    try {
      final base64Data = testBase64.split(',')[1];
      final decodedData = base64Decode(base64Data);

      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: Image(
          image: MemoryImage(decodedData),
          fit: BoxFit.cover,
        ),
      );
    } catch (e) {
      debugPrint("❌ Test image failed: $e");
      return Container(
        width: 100,
        height: 100,
        color: Colors.red.withOpacity(0.3),
        child: const Center(child: Text("Test Failed")),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    // Make sure we have a current user
    final user = _auth.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      debugPrint('User authenticated as: $_currentUserId');

      // Wait a bit to ensure token is fully processed
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _checkIfLiked();
        }
      });
    } else {
      debugPrint('WARNING: No authenticated user found when loading post card');
      // Listen for auth state changes
      _auth.authStateChanges().listen((User? user) {
        if (user != null && mounted) {
          _currentUserId = user.uid;
          debugPrint('User authenticated after delay: $_currentUserId');
          _checkIfLiked();
        }
      });
    }

    // Load images from subcollection
    if (widget.post.imageIds.isNotEmpty) {
      _loadImages();
    }
  }

  Future<void> _loadImages() async {
    for (String imageId in widget.post.imageIds) {
      try {
        final imageDoc = await _firestore
            .collection('posts')
            .doc(widget.post.id)
            .collection('images')
            .doc(imageId)
            .get();

        if (imageDoc.exists) {
          final data = imageDoc.data();
          if (data != null && data['data'] != null) {
            setState(() {
              _imageData.add(data['data']);
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading image $imageId: $e');
      }
    }
  }

  Future<void> _checkIfLiked() async {
    if (_currentUserId.isEmpty) {
      debugPrint('ERROR: Cannot check like status - no user ID available');
      return;
    }

    try {
      debugPrint(
          '[PERMISSION CHECK] Attempting to access: posts/${widget.post.id}/likes/$_currentUserId');

      final snapshot = await _firestore
          .collection('posts')
          .doc(widget.post.id)
          .collection('likes')
          .doc(_currentUserId)
          .get();

      debugPrint('SUCCESS: Like status retrieved - liked: ${snapshot.exists}');

      if (mounted) {
        setState(() {
          _isLiked = snapshot.exists;
        });
      }
    } catch (e) {
      debugPrint('ERROR accessing likes collection: $e');
      // Fall back to assuming not liked if there's an error
    }
  }

  Future<void> _toggleLike() async {
    try {
      await _postService.toggleLike(widget.post.id);
    } catch (e) {
      debugPrint('Error toggling like: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process like')),
        );
      }
    }
  }

  Future<void> _editPost(BuildContext context) async {
    // Navigate to edit post screen
    final updatedContent = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => EditPostScreen(post: widget.post),
      ),
    );

    // If post was updated, refresh the widget
    if (updatedContent != null && mounted) {
      setState(() {
        // The post will be refreshed from Firestore in the parent widget
      });
    }
  }

  Future<void> _deletePost(BuildContext context) async {
    // Check authentication status first
    if (_currentUserId.isEmpty || _currentUserId != widget.post.authorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You are not authorized to delete this post')),
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Post',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // First delete the post document itself
        await _firestore.collection('posts').doc(widget.post.id).delete();

        // Then get and delete likes - this will happen after the post is gone
        // which is safer since rules often only check parent document
        final likesSnapshot = await _firestore
            .collection('posts')
            .doc(widget.post.id)
            .collection('likes')
            .get();

        // Delete likes one by one if any still exist
        for (var doc in likesSnapshot.docs) {
          await doc.reference.delete();
        }

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Post deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error deleting post: $e')),
          );
        }
      }
    }
  }

  Future<void> _hidePost(BuildContext context) async {
    // Capture the ScaffoldMessenger before the async operation
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (_currentUserId.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('You need to be logged in to hide posts')),
      );
      return;
    }

    // Create a reference to store hidden posts for the current user
    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('hidden_posts')
          .doc(widget.post.id)
          .set({
        'hiddenAt': FieldValue.serverTimestamp(),
        'postId':
            widget.post.id, // Store the post ID explicitly for easier querying
      });

      // Call the callback to notify the parent widget
      if (widget.onPostHidden != null) {
        widget.onPostHidden!(widget.post.id);
      }

      if (mounted) {
        // Notify user - use the captured scaffoldMessenger
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text(
                'Post hidden. You won\'t see it in your feed anymore.'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: _undoHidePost,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Use the captured scaffoldMessenger
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Could not hide post: $e')),
        );
      }
    }
  }

  void _undoHidePost() async {
    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('hidden_posts')
          .doc(widget.post.id)
          .delete();
    } catch (e) {
      debugPrint('Error undoing hide post: $e');
    }
  }

  Future<void> _reportPost(BuildContext context) async {
    // Capture the ScaffoldMessenger before the async operation
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show dialog to confirm report and select reason
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you reporting this post?'),
            const SizedBox(height: 16),
            ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('Inappropriate content'),
                  onTap: () => Navigator.of(context).pop('inappropriate'),
                ),
                ListTile(
                  title: const Text('Spam'),
                  onTap: () => Navigator.of(context).pop('spam'),
                ),
                ListTile(
                  title: const Text('False information'),
                  onTap: () => Navigator.of(context).pop('misinformation'),
                ),
                ListTile(
                  title: const Text('Harassment or bullying'),
                  onTap: () => Navigator.of(context).pop('harassment'),
                ),
                ListTile(
                  title: const Text('Other'),
                  onTap: () => Navigator.of(context).pop('other'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (reason != null && mounted) {
      try {
        // Store the report in Firestore
        await _firestore.collection('reported_posts').add({
          'postId': widget.post.id,
          'reportedBy': _currentUserId,
          'authorId': widget.post.authorId,
          'reason': reason,
          'content': widget.post.content,
          'reportedAt': FieldValue.serverTimestamp(),
        });

        // Also hide the post for the user
        await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('hidden_posts')
            .doc(widget.post.id)
            .set({
          'hiddenAt': FieldValue.serverTimestamp(),
          'wasReported': true,
          'reportReason': reason,
        });

        if (mounted) {
          // Use the captured scaffoldMessenger
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Thank you for reporting this post. Our team will review it shortly.',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Use the captured scaffoldMessenger
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Could not report post: $e')),
          );
        }
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Question':
        return Colors.purple;
      case 'Discussion':
        return Colors.blue;
      case 'Tips':
        return Colors.green;
      case 'Resource':
        return Colors.orange;
      case 'Success Story':
        return Colors.teal;
      case 'Support':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLikeButton() {
    return StreamBuilder<bool>(
      stream: _postService.hasLikedStream(widget.post.id),
      initialData: _isLiked, // Use current state as initial
      builder: (context, snapshot) {
        final isLiked = snapshot.data ?? false;

        return TextButton.icon(
          icon: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Colors.red : null,
          ),
          label: Text(
            'Like',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          onPressed: _toggleLike,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // More detailed debugging
    debugPrint("==== POST CARD DEBUG [${widget.post.id}] ====");
    debugPrint("Post author: ${widget.post.authorName}");
    debugPrint(
        "Post content: ${widget.post.content.substring(0, widget.post.content.length > 30 ? 30 : widget.post.content.length)}...");

    if (widget.post.mediaUrls.isNotEmpty) {
      debugPrint("✅ Post has ${widget.post.mediaUrls.length} images");

      for (int i = 0; i < widget.post.mediaUrls.length; i++) {
        final url = widget.post.mediaUrls[i];
        debugPrint(
            "Image $i type: ${url.startsWith('data:image') ? 'BASE64' : 'URL'}");

        if (url.startsWith('data:image')) {
          try {
            final parts = url.split(',');
            final formatInfo = parts[0]; // e.g., data:image/jpeg;base64
            debugPrint("Format: $formatInfo");

            final base64Data = parts.length > 1 ? parts[1] : '';
            final dataLength = base64Data.length;
            debugPrint("Data length: $dataLength characters");

            if (dataLength > 0) {
              debugPrint(
                  "First 20 chars: ${base64Data.substring(0, dataLength > 20 ? 20 : dataLength)}...");
              debugPrint(
                  "Last 20 chars: ...${base64Data.substring(dataLength > 20 ? dataLength - 20 : 0)}");
            } else {
              debugPrint("❌ ERROR: Empty base64 data!");
            }
          } catch (e) {
            debugPrint("❌ ERROR parsing base64: $e");
          }
        }
      }
    } else {
      debugPrint("❌ Post has NO images!");
    }
    debugPrint("========================================");

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: widget.post.authorPhotoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(
                          widget.post.authorPhotoUrl,
                        ) as ImageProvider
                      : null,
                  child: widget.post.authorPhotoUrl.isEmpty
                      ? Text(widget.post.authorName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            widget.post.authorName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.post.isProfessionalPost)
                            Container(
                              margin: const EdgeInsets.only(
                                  left: 8, top: 2, bottom: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Pro',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Container(
                            margin: const EdgeInsets.only(
                                left: 8, top: 2, bottom: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(widget.post.category),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.post.category,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        timeago.format(widget.post.createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'hide') {
                      _hidePost(context);
                    } else if (value == 'edit') {
                      _editPost(context);
                    } else if (value == 'delete') {
                      _deletePost(context);
                    }
                  },
                  itemBuilder: (context) => [
                    // Only show edit and delete options if current user is the author
                    if (_currentUserId == widget.post.authorId) ...[
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Edit Post'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Delete Post',
                              style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuDivider(),
                    ],
                    // Show hide option for all users
                    const PopupMenuItem(
                      value: 'hide',
                      child: ListTile(
                        leading: Icon(Icons.visibility_off),
                        title: Text('Hide Post'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.25,
                  ),
                  maxLines: 2, // Limit to 2 lines
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.post.content,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.5,
                  ),
                  maxLines: 8, // Show reasonable preview
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.post.mediaUrls.isNotEmpty)
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.post.mediaUrls.length,
                itemBuilder: (context, index) {
                  final imageUrl = widget.post.mediaUrls[index];
                  debugPrint('Loading image from URL: $imageUrl');

                  return Padding(
                    padding: const EdgeInsets.only(left: 12.0, right: 4.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: 200,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child:
                              const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) {
                          debugPrint(
                              'Failed to load image: $url, Error: $error');
                          return Container(
                            width: MediaQuery.of(context).size.width * 0.8,
                            height: 200,
                            color: Colors.grey[200],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image, size: 50),
                                const SizedBox(height: 8),
                                Text('Error: $error',
                                    textAlign: TextAlign.center),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .doc(widget.post.id)
                .snapshots(),
            builder: (context, snapshot) {
              int likeCount = widget.post.likeCount;
              int commentCount = widget.post.commentCount;

              if (snapshot.hasData && snapshot.data != null) {
                final postData = snapshot.data!.data() as Map<String, dynamic>?;
                if (postData != null) {
                  likeCount = postData['likeCount'] ?? widget.post.likeCount;
                  commentCount =
                      postData['commentCount'] ?? widget.post.commentCount;
                }
              }

              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(
                      '$likeCount ${likeCount == 1 ? 'Like' : 'Likes'}',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$commentCount ${commentCount == 1 ? 'Comment' : 'Comments'}',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: _buildLikeButton(),
              ),
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.comment_outlined),
                  label: const Text('Comment'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CommentsScreen(postId: widget.post.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
