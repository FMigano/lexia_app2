import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lexia_app/services/post_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexia_app/util/name_utils.dart'; // Add this import

class CommentsScreen extends StatefulWidget {
  final String postId;

  const CommentsScreen({super.key, required this.postId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final PostService _postService = PostService();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;

  // Track which comment is being replied to
  String? _replyToCommentId;
  String? _replyToUsername;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Set up reply state
  void _setupReply(String commentId, String username) {
    setState(() {
      _replyToCommentId = commentId;
      _replyToUsername = username;
      _commentController.text = ''; // Clear any existing text
    });
    _focusNode.requestFocus(); // Focus the input field
  }

  // Cancel reply mode
  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUsername = null;
    });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get the user's actual name from Firestore
      String authorName = 'User'; // Default fallback
      String authorPhotoUrl = '';
      
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          // Use the NameUtils to get the proper name
          authorName = NameUtils.extractName(userData, user: currentUser);
          authorPhotoUrl = userData['photoUrl'] ?? userData['profile_image_url'] ?? currentUser.photoURL ?? '';
        }
      } catch (e) {
        debugPrint('Error getting user name: $e');
        // Use fallback name from Firebase Auth
        authorName = currentUser.displayName?.trim() ?? 'User';
        authorPhotoUrl = currentUser.photoURL ?? '';
      }

      // Check if this is a reply
      if (_replyToCommentId != null) {
        print('Sending reply to comment: $_replyToCommentId');
        
        // Add reply to the specific comment's replies subcollection
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(_replyToCommentId!)
            .collection('replies')
            .add({
          'content': text,
          'authorId': currentUser.uid,
          'authorName': authorName,
          'authorPhotoUrl': authorPhotoUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'parentCommentId': _replyToCommentId, // Track parent comment
        });
        
        print('Reply sent successfully');
      } else {
        print('Sending new comment');
        
        // Add the comment with the correct author name
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .add({
          'content': text,
          'authorId': currentUser.uid,
          'authorName': authorName, // Use the correct name from Firestore
          'authorPhotoUrl': authorPhotoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update comment count
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .update({
          'commentCount': FieldValue.increment(1),
        });
        
        print('Comment sent successfully');
      }

      _commentController.clear();

      // Reset reply state
      setState(() {
        _replyToCommentId = null;
        _replyToUsername = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _replyToCommentId != null ? 'Reply added!' : 'Comment added!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      print('Error sending comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send comment: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _sendComment,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // New method to add comment directly (bypassing the service for direct Firestore access)
  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get the user's actual name from Firestore
      String authorName = 'User'; // Default fallback
      String authorPhotoUrl = '';
      
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          // Use the NameUtils to get the proper name
          authorName = NameUtils.extractName(userData, user: currentUser);
          authorPhotoUrl = userData['photoUrl'] ?? userData['profile_image_url'] ?? currentUser.photoURL ?? '';
        }
      } catch (e) {
        debugPrint('Error getting user name: $e');
        // Use fallback name from Firebase Auth
        authorName = currentUser.displayName?.trim() ?? 'User';
        authorPhotoUrl = currentUser.photoURL ?? '';
      }

      // Check if this is a reply
      if (_replyToCommentId != null) {
        // Add reply to the specific comment
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(_replyToCommentId!)
            .collection('replies')
            .add({
          'content': _commentController.text.trim(),
          'authorId': currentUser.uid,
          'authorName': authorName, // Use the correct name from Firestore
          'authorPhotoUrl': authorPhotoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Clear reply state
        _cancelReply();
      } else {
        // Add the comment with the correct author name
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .add({
          'content': _commentController.text.trim(),
          'authorId': currentUser.uid,
          'authorName': authorName, // Use the correct name from Firestore
          'authorPhotoUrl': authorPhotoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update comment count
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .update({
          'commentCount': FieldValue.increment(1),
        });
      }

      _commentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _replyToCommentId != null ? 'Reply added!' : 'Comment added!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error adding comment: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = Theme.of(context);
    final isDarkMode = currentTheme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Comments',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _postService.getCommentsStream(widget.postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  // Handle index error specifically
                  if (snapshot.error.toString().contains('failed-precondition')) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sync, color: Colors.orange, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'Setting up comments...',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'We\'re creating the necessary database indexes. This usually takes a minute when first using the app.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: () {
                                // Force refresh the stream builder
                                setState(() {});
                              },
                              child: Text('Retry', style: GoogleFonts.poppins()),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  // Regular error display
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Something went wrong',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Error: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              // Force refresh the stream builder
                              setState(() {});
                            },
                            child: Text('Retry', style: GoogleFonts.poppins()),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allComments = snapshot.data?.docs ?? [];

                // Filter only top-level comments (no parentId)
                final comments = allComments.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['parentId'] == null;
                }).toList();

                // Sort comments by timestamp
                comments.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  
                  final aTime = aData['createdAt'];
                  final bTime = bData['createdAt'];
                  
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  
                  return (aTime as Timestamp).compareTo(bTime as Timestamp);
                });

                if (comments.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 72,
                            color: Colors.grey.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No comments yet',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to share your thoughts!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton.icon(
                            onPressed: () {
                              _focusNode.requestFocus();
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Add a comment'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 24,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.grey.shade800 
                        : Colors.grey.shade300,
                  ),
                  itemBuilder: (context, index) {
                    final comment = comments[index].data() as Map<String, dynamic>;
                    final commentId = comments[index].id;
                    final isCurrentUserComment = FirebaseAuth.instance.currentUser != null &&
                        comment['authorId'] == FirebaseAuth.instance.currentUser!.uid;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main comment
                        _buildCommentWidget(comment, commentId, isCurrentUserComment, false, null),
                        
                        // Replies for this comment
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.postId)
                              .collection('comments')
                              .doc(commentId)
                              .collection('replies')
                              .orderBy('createdAt', descending: false)
                              .snapshots(),
                          builder: (context, replySnapshot) {
                            if (!replySnapshot.hasData || replySnapshot.data!.docs.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            final replies = replySnapshot.data!.docs;

                            return Padding(
                              padding: const EdgeInsets.only(left: 48, top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: replies.map((reply) {
                                  final replyData = reply.data() as Map<String, dynamic>;
                                  final replyId = reply.id;
                                  final isCurrentUserReply = FirebaseAuth.instance.currentUser != null &&
                                      replyData['authorId'] == FirebaseAuth.instance.currentUser!.uid;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey.shade900.withOpacity(0.5)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: _buildCommentWidget(replyData, replyId, isCurrentUserReply, true, commentId), // Pass parent comment ID
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Comment input field with improved styling
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show reply indicator if replying to a comment
                  if (_replyToCommentId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                ),
                                children: [
                                  const TextSpan(text: 'Replying to '),
                                  TextSpan(
                                    text: _replyToUsername,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: currentTheme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _cancelReply,
                          ),
                        ],
                      ),
                    ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CircleAvatar(
                        backgroundImage:
                            FirebaseAuth.instance.currentUser?.photoURL != null
                                ? NetworkImage(
                                    FirebaseAuth.instance.currentUser!.photoURL!)
                                : null,
                        radius: 16,
                        backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                        child: FirebaseAuth.instance.currentUser?.photoURL == null
                            ? Text(
                                (FirebaseAuth.instance.currentUser?.displayName ??
                                        '?')[0]
                                    .toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: _replyToCommentId == null
                                ? 'Add a comment...'
                                : 'Write a reply...',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: isDarkMode ? Colors.grey.shade800.withOpacity(0.5) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                          ),
                          maxLines: 4,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: currentTheme.primaryColor,
                        borderRadius: BorderRadius.circular(50),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: _isSubmitting ? null : _sendComment,
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentWidget(Map<String, dynamic> commentData, String commentId, bool isCurrentUser, bool isReply, String? parentCommentId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with author info and actions
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundImage: commentData['authorPhotoUrl'] != null &&
                      commentData['authorPhotoUrl'] != ''
                  ? NetworkImage(commentData['authorPhotoUrl'])
                  : null,
              radius: isReply ? 14 : 18,
              child: commentData['authorPhotoUrl'] == null ||
                      commentData['authorPhotoUrl'] == ''
                  ? Icon(
                      Icons.person, 
                      size: isReply ? 14 : 18, 
                      color: isDarkMode ? Colors.white70 : Colors.black54
                    )
                  : null,
            ),
            SizedBox(width: isReply ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    commentData['authorName'] as String? ?? 'Anonymous',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: isReply ? 13 : 15,
                    ),
                  ),
                  if (commentData['createdAt'] != null)
                    Text(
                      timeago.format((commentData['createdAt'] as Timestamp).toDate()),
                      style: GoogleFonts.poppins(
                        fontSize: isReply ? 11 : 12,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                // Reply button (only for main comments, not replies)
                if (!isReply)
                  IconButton(
                    icon: Icon(
                      Icons.reply,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      size: 20,
                    ),
                    onPressed: () {
                      _setupReply(
                        commentId,
                        commentData['authorName'] as String? ?? 'Anonymous'
                      );
                    },
                    tooltip: 'Reply',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                    visualDensity: VisualDensity.compact,
                  ),

                // Delete button (only for user's own comments)
                if (isCurrentUser)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade300,
                      size: isReply ? 16 : 20,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            isReply ? 'Delete Reply' : 'Delete Comment',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          content: Text('Are you sure you want to delete this ${isReply ? 'reply' : 'comment'}?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('CANCEL'),
                            ),
                            FilledButton(
                              onPressed: () async {
                                try {
                                  Navigator.of(context).pop(); // Close dialog first
                                  
                                  if (isReply && parentCommentId != null) {
                                    // Delete reply
                                    await FirebaseFirestore.instance
                                        .collection('posts')
                                        .doc(widget.postId)
                                        .collection('comments')
                                        .doc(parentCommentId)
                                        .collection('replies')
                                        .doc(commentId)
                                        .delete();
                                  } else {
                                    // Delete main comment and all its replies
                                    final commentRef = FirebaseFirestore.instance
                                        .collection('posts')
                                        .doc(widget.postId)
                                        .collection('comments')
                                        .doc(commentId);
                                    
                                    // First delete all replies
                                    final repliesSnapshot = await commentRef.collection('replies').get();
                                    final batch = FirebaseFirestore.instance.batch();
                                    
                                    for (final reply in repliesSnapshot.docs) {
                                      batch.delete(reply.reference);
                                    }
                                    
                                    // Then delete the comment
                                    batch.delete(commentRef);
                                    
                                    // Update comment count
                                    batch.update(
                                      FirebaseFirestore.instance.collection('posts').doc(widget.postId),
                                      {'commentCount': FieldValue.increment(-1)}
                                    );
                                    
                                    await batch.commit();
                                  }
                                  
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${isReply ? 'Reply' : 'Comment'} deleted',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error deleting ${isReply ? 'reply' : 'comment'}: ${error.toString()}',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('DELETE'),
                            ),
                          ],
                        ),
                      );
                    },
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.all(isReply ? 0 : 8),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
        SizedBox(height: isReply ? 8 : 12),

        // Comment content
        Padding(
          padding: EdgeInsets.only(
            left: isReply ? 4 : 48, 
            right: isReply ? 4 : 8
          ),
          child: Text(
            commentData['content'] as String? ?? '',
            style: GoogleFonts.poppins(
              fontSize: isReply ? 13 : 15,
              height: isReply ? 1.3 : 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
