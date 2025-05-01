import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lexia_app/services/post_service.dart';
import 'package:google_fonts/google_fonts.dart';

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

    setState(() {
      _isSubmitting = true;
    });

    try {
      // If it's a reply, use addReply method, otherwise addComment
      if (_replyToCommentId != null) {
        print('Sending reply to comment: $_replyToCommentId');
        await _postService.addReply(widget.postId, _replyToCommentId!, text);
        print('Reply sent successfully');
      } else {
        print('Sending new comment');
        await _postService.addComment(widget.postId, text);
        print('Comment sent successfully');
      }

      _commentController.clear();

      // Reset reply state
      setState(() {
        _replyToCommentId = null;
        _replyToUsername = null;
      });
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

                // Client-side sorting and filtering
                allComments.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  
                  // First sort by parentId (null first)
                  final aParentId = aData['parentId'] as String?;
                  final bParentId = bData['parentId'] as String?;
                  
                  if (aParentId == null && bParentId != null) return -1;
                  if (aParentId != null && bParentId == null) return 1;
                  
                  // Then sort by timestamp, with null-safety
                  final aTime = aData['createdAt'];
                  final bTime = bData['createdAt'];
                  
                  // Handle null timestamps
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1; // Null timestamps go at the end
                  if (bTime == null) return -1;
                  
                  // Now it's safe to compare timestamps
                  return (aTime as Timestamp).compareTo(bTime as Timestamp);
                });

                // Separate top-level comments and replies
                final comments = allComments.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['parentId'] == null;
                }).toList();

                // Create a map of replies by parent comment id
                final Map<String, List<QueryDocumentSnapshot>> replies = {};
                for (final doc in allComments) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['parentId'] != null) {
                    final parentId = data['parentId'] as String;
                    replies[parentId] = replies[parentId] ?? [];
                    replies[parentId]!.add(doc);
                  }
                }

                // Sort replies by timestamp
                replies.forEach((parentId, repliesList) {
                  repliesList.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    
                    final aTime = aData['createdAt'];
                    final bTime = bData['createdAt'];
                    
                    // Handle null timestamps
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1; // Null timestamps go at the end
                    if (bTime == null) return -1;
                    
                    // Now it's safe to compare timestamps
                    return (aTime as Timestamp).compareTo(bTime as Timestamp);
                  });
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
                    color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                  ),
                  itemBuilder: (context, index) {
                    final comment = comments[index].data() as Map<String, dynamic>;
                    final commentId = comments[index].id;
                    final isCurrentUserComment = FirebaseAuth.instance.currentUser != null &&
                        comment['authorId'] == FirebaseAuth.instance.currentUser!.uid;

                    // Get replies for this comment
                    final commentReplies = replies[commentId] ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main comment
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with author info and actions
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    backgroundImage: comment['authorPhotoUrl'] != null &&
                                            comment['authorPhotoUrl'] != ''
                                        ? NetworkImage(comment['authorPhotoUrl'])
                                        : null,
                                    radius: 18,
                                    child: comment['authorPhotoUrl'] == null ||
                                            comment['authorPhotoUrl'] == ''
                                        ? Icon(Icons.person, size: 18, color: isDarkMode ? Colors.white70 : Colors.black54)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment['authorName'] as String? ?? 'Anonymous',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (comment['createdAt'] != null)
                                          Text(
                                            timeago.format((comment['createdAt'] as Timestamp).toDate()),
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      // Reply button
                                      IconButton(
                                        icon: Icon(
                                          Icons.reply,
                                          color: currentTheme.colorScheme.primary.withOpacity(0.7),
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          _setupReply(
                                            commentId,
                                            comment['authorName'] as String? ?? 'Anonymous'
                                          );
                                        },
                                        tooltip: 'Reply',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8),
                                        visualDensity: VisualDensity.compact,
                                      ),

                                      // Delete button (only for user's own comments)
                                      if (isCurrentUserComment)
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Colors.red.shade300,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text(
                                                  'Delete Comment',
                                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                                ),
                                                content: const Text('Are you sure you want to delete this comment?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(context).pop(),
                                                    child: const Text('CANCEL'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () {
                                                      _postService.deleteComment(widget.postId, commentId).then((_) {
                                                        Navigator.of(context).pop();
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Comment deleted')),
                                                        );
                                                      }).catchError((error) {
                                                        Navigator.of(context).pop();
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Error: ${error.toString()}')),
                                                        );
                                                      });
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
                                          padding: const EdgeInsets.all(8),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Comment content with proper padding
                              Padding(
                                padding: const EdgeInsets.only(left: 48, right: 8),
                                child: Text(
                                  comment['content'] as String? ?? '',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Display replies if any
                        if (commentReplies.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 48, top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: commentReplies.map((reply) {
                                final replyData = reply.data() as Map<String, dynamic>;
                                final replyId = reply.id;
                                final isCurrentUserReply = FirebaseAuth.instance.currentUser != null &&
                                    replyData['authorId'] == FirebaseAuth.instance.currentUser!.uid;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.grey.shade900.withOpacity(0.5)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDarkMode
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            backgroundImage: replyData['authorPhotoUrl'] != null &&
                                                    replyData['authorPhotoUrl'] != ''
                                                ? NetworkImage(replyData['authorPhotoUrl'])
                                                : null,
                                            radius: 14,
                                            child: replyData['authorPhotoUrl'] == null ||
                                                    replyData['authorPhotoUrl'] == ''
                                                ? Icon(Icons.person, size: 14, color: isDarkMode ? Colors.white70 : Colors.black54)
                                                : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  replyData['authorName'] as String? ?? 'Anonymous',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                if (replyData['createdAt'] != null)
                                                  Text(
                                                    timeago.format((replyData['createdAt'] as Timestamp).toDate()),
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (isCurrentUserReply)
                                            IconButton(
                                              iconSize: 16,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: Icon(
                                                Icons.delete_outline,
                                                color: Colors.red.shade300,
                                                size: 16,
                                              ),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: Text(
                                                      'Delete Reply',
                                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                                    ),
                                                    content: const Text('Are you sure you want to delete this reply?'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.of(context).pop(),
                                                        child: const Text('CANCEL'),
                                                      ),
                                                      FilledButton(
                                                        onPressed: () {
                                                          _postService.deleteReply(widget.postId, replyId).then((_) {
                                                            Navigator.of(context).pop();
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(content: Text('Reply deleted')),
                                                            );
                                                          }).catchError((error) {
                                                            Navigator.of(context).pop();
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(content: Text('Error: ${error.toString()}')),
                                                            );
                                                          });
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
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4, right: 4),
                                        child: Text(
                                          replyData['content'] as String? ?? '',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
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
}
