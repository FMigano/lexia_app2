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
import 'dart:math';
import 'package:lexia_app/widgets/verification_badge.dart';

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
          const SnackBar(content: Text('Failed to process like')),
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

    if (_currentUserId.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            content: Text('You need to be logged in to report posts')),
      );
      return;
    }

    // Show dialog to confirm report and select reason
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Report Post',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          // Change from Column to SingleChildScrollView
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why are you reporting this post?',
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 16),
              // Removed nested ListView and replaced with Column of buttons
              _buildReportOption(
                  context, 'Inappropriate content', 'inappropriate'),
              _buildReportOption(context, 'Spam', 'spam'),
              _buildReportOption(
                  context, 'False information', 'misinformation'),
              _buildReportOption(
                  context, 'Harassment or bullying', 'harassment'),
              _buildReportOption(context, 'Other', 'other'),
            ],
          ),
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
      // Show loading indicator
      final loadingDialog = showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Submitting report...',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          ),
        ),
      );

      try {
        // Store the report in Firestore FIRST
        debugPrint('Attempting to create report in Firestore...');

        final reportData = {
          'postId': widget.post.id,
          'reportedBy': _currentUserId,
          'authorId': widget.post.authorId,
          'reason': reason,
          'content': widget.post.content,
          'title': widget.post.title,
          'category': widget.post.category,
          'reportedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        };

        debugPrint('Report data: $reportData');

        final reportRef = await _firestore
            .collection('reported_posts')
            .add(reportData)
            .timeout(const Duration(seconds: 10));

        debugPrint('Report created with ID: ${reportRef.id}');

        // Ask if the user also wants to hide the post
        if (mounted) {
          final shouldHide = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Hide Post?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              content: Text(
                'Would you also like to hide this post from your feed?',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            ),
          );

          // Only hide the post if the user confirms
          if (shouldHide == true) {
            await _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('hidden_posts')
                .doc(widget.post.id)
                .set({
              'hiddenAt': FieldValue.serverTimestamp(),
              'wasReported': true,
              'reportReason': reason,
              'reportId': reportRef.id, // Link to the report
            });

            // Notify parent widget about the hidden post
            if (widget.onPostHidden != null) {
              widget.onPostHidden!(widget.post.id);
            }
          }
        }

        if (mounted) {
          // Close loading dialog when done
          Navigator.of(context, rootNavigator: true).pop();

          // Show success message
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Thank you for reporting this post. Our team will review it shortly.',
              ),
            ),
          );
        }
      } catch (e, stackTrace) {
        // Close loading dialog on error
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        // Enhanced error logging
        debugPrint('Error reporting post: $e');
        debugPrint('Error stack trace: $stackTrace');

        // Check for Firestore permission errors specifically
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('permission') ||
            errorMessage.contains('permission-denied')) {
          debugPrint(
              'This appears to be a Firestore permission error. Check your security rules.');

          if (mounted) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text(
                    'Permission error: Your account doesn\'t have access to report posts.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          // Generic error
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                    'Could not report post: ${e.toString().substring(0, min(e.toString().length, 100))}'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    }
  }

  // Helper method for report options
  Widget _buildReportOption(BuildContext context, String title, String value) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
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

  Widget _buildVerificationBadge() {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(widget.post.authorId).get(),
      builder: (context, snapshot) {
        // Debug logging
        debugPrint('🔍 Verification Badge Debug for ${widget.post.authorName}:');
        debugPrint('   Author ID: ${widget.post.authorId}');
        debugPrint('   Snapshot hasData: ${snapshot.hasData}');
        debugPrint('   Snapshot exists: ${snapshot.data?.exists}');
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          debugPrint('   ❌ No user document found');
          return const SizedBox.shrink();
        }
        
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final authorRole = userData?['role'] as String?;
        final verificationStatus = userData?['verificationStatus'] as String?;
        
        debugPrint('   Role: $authorRole');
        debugPrint('   Verification Status: $verificationStatus');
        debugPrint('   Should show badge: ${authorRole == 'professional' && verificationStatus == 'verified'}');
        
        // Use your VerificationBadge widget
        return VerificationBadge(
          role: authorRole,
          verificationStatus: verificationStatus,
          size: 16,
        );
      },
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getCategoryColor(widget.post.category),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        widget.post.category,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
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

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('posts').doc(widget.post.id).snapshots(),
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

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author header with verification badge
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: widget.post.authorPhotoUrl.isNotEmpty
                          ? NetworkImage(widget.post.authorPhotoUrl)
                          : null,
                      child: widget.post.authorPhotoUrl.isEmpty
                          ? Text(
                              widget.post.authorName.isNotEmpty
                                  ? widget.post.authorName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fixed Row with proper overflow handling
                          Row(
                            children: [
                              // Use Flexible for the name to allow it to shrink
                              Flexible(
                                child: Text(
                                  widget.post.authorName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis, // Handle long names
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 4), // Reduced spacing
                              _buildVerificationBadge(),
                              const SizedBox(width: 4), // Reduced spacing
                              _buildCategoryBadge(),
                            ],
                          ),
                          Text(
                            timeago.format(widget.post.createdAt),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Remove the Spacer() and just use a small SizedBox
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'hide') {
                          _hidePost(context);
                        } else if (value == 'edit') {
                          _editPost(context);
                        } else if (value == 'delete') {
                          _deletePost(context);
                        } else if (value == 'report') {
                          _reportPost(context);
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
                        // Add report option, but only if the current user is NOT the author
                        if (_currentUserId != widget.post.authorId)
                          const PopupMenuItem(
                            value: 'report',
                            child: ListTile(
                              leading: Icon(Icons.flag, color: Colors.orange),
                              title: Text('Report Post'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                  ],
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.post.mediaUrls.length,
                        itemBuilder: (context, index) {
                          final imageUrl = widget.post.mediaUrls[index];

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
                                  width: MediaQuery.of(context).size.width * 0.8,
                                  height: 200,
                                  child: const Center(
                                      child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) {
                                  debugPrint(
                                      'Failed to load image: $url, Error: $error');
                                  return Container(
                                    width: MediaQuery.of(context).size.width * 0.8,
                                    height: 200,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.broken_image, size: 50),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                Padding(
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
          ),
        );
      },
    );
  }
}
