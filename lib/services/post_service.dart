import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Toggle like function
  Future<void> toggleLike(String postId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Get references
    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(currentUser.uid);

    // Use a transaction for safe update
    return _firestore.runTransaction((transaction) async {
      final likeDoc = await transaction.get(likeRef);

      if (likeDoc.exists) {
        // User already liked this post - unlike it
        transaction.delete(likeRef);
        transaction.update(postRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        // User hasn't liked this post yet - add like
        transaction.set(likeRef, {
          'userId': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        transaction.update(postRef, {'likeCount': FieldValue.increment(1)});
      }
    });
  }

  // Add comment function
  Future<void> addComment(String postId, String comment) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Get references
    final postRef = _firestore.collection('posts').doc(postId);
    final commentsRef = postRef.collection('comments');

    // Use a transaction to update comment count atomically
    return _firestore.runTransaction((transaction) async {
      // Step 1: Add the comment
      final commentDoc = commentsRef.doc(); // Generate a new document ID
      transaction.set(commentDoc, {
        'content': comment, // Change from 'text' to 'content'
        'authorId': currentUser.uid,
        'authorName': currentUser.displayName ?? 'User',
        'authorPhotoUrl': currentUser.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(), // This should always be set
      });

      // Step 2: Increment comment count on the post
      transaction.update(postRef, {'commentCount': FieldValue.increment(1)});

      return;
    });
  }

  // Delete comment function
  Future<void> deleteComment(String postId, String commentId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Get references
    final postRef = _firestore.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    // Use a transaction to update comment count atomically
    return _firestore.runTransaction((transaction) async {
      // First, get the comment to verify ownership (security check)
      final commentDoc = await transaction.get(commentRef);

      if (!commentDoc.exists) {
        throw Exception('Comment does not exist');
      }

      final commentData = commentDoc.data() as Map<String, dynamic>;

      // Verify user is the author of the comment
      if (commentData['authorId'] != currentUser.uid) {
        throw Exception('You can only delete your own comments');
      }

      // Delete the comment
      transaction.delete(commentRef);

      // Decrement comment count on the post
      transaction.update(postRef, {'commentCount': FieldValue.increment(-1)});

      return;
    });
  }

  // Add a reply to a comment
  Future<void> addReply(String postId, String parentCommentId, String content) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // First check if both post and parent comment exist
      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await postRef.get();
      
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }
      
      final parentCommentRef = postRef.collection('comments').doc(parentCommentId);
      final parentCommentDoc = await parentCommentRef.get();
      
      if (!parentCommentDoc.exists) {
        throw Exception('Parent comment not found');
      }
      
      // Now proceed with adding the reply
      final commentsCollection = postRef.collection('comments');
      await commentsCollection.add({
        'parentId': parentCommentId, // null for top-level comments
        'authorId': user.uid,
        'authorName': user.displayName ?? 'User',
        'authorPhotoUrl': user.photoURL ?? '',
        'content': content,
        'createdAt': FieldValue.serverTimestamp(), // This should always be set
      });

      // Update the post to show it has new activity
      await postRef.update({
        'lastActivityTime': FieldValue.serverTimestamp(),
        'commentCount': FieldValue.increment(1), // Count replies as comments too
      });
    } catch (e) {
      print('Error in addReply: $e');
      rethrow;
    }
  }

  // Delete a reply - using transaction for consistency
  Future<void> deleteReply(String postId, String replyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final postRef = _firestore.collection('posts').doc(postId);
    final replyRef = postRef.collection('comments').doc(replyId);

    return _firestore.runTransaction((transaction) async {
      final replyDoc = await transaction.get(replyRef);
      if (!replyDoc.exists) throw Exception('Reply not found');

      final replyData = replyDoc.data() as Map<String, dynamic>;
      if (replyData['authorId'] != user.uid) {
        throw Exception('You can only delete your own replies');
      }

      // Delete the reply
      transaction.delete(replyRef);

      // Update post comment count
      transaction.update(postRef, {
        'commentCount': FieldValue.increment(-1),
      });
    });
  }

  // Stream of all posts for real-time updates
  Stream<QuerySnapshot> getPostsStream() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Alternative method that doesn't require special indexes
  Stream<QuerySnapshot> getCommentsStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .snapshots();
  }

  // Check if a user has liked a post in real-time
  Stream<bool> hasLikedStream(String postId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(false);
    }

    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(currentUser.uid)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  // Get a single post as a stream for real-time updates
  Stream<DocumentSnapshot> getPostStream(String postId) {
    return _firestore.collection('posts').doc(postId).snapshots();
  }

  Future<List<String>> uploadPostImages(List<File> imageFiles) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final List<String> imageUrls = [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      for (int i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];

        // Check if file exists and has data
        if (!file.existsSync()) {
          debugPrint('File does not exist: ${file.path}');
          continue;
        }

        // Check file size
        final fileSize = await file.length();
        debugPrint('Uploading file size: $fileSize bytes');

        if (fileSize == 0) {
          debugPrint('File is empty: ${file.path}');
          continue;
        }

        // Create a reference for this specific image
        final imageRef = FirebaseStorage.instance
            .ref()
            .child('post_images/${currentUser.uid}/${timestamp}_$i.jpg');

        try {
          // Upload file with metadata
          final metadata = SettableMetadata(contentType: 'image/jpeg');
          await imageRef.putFile(file, metadata);

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
      debugPrint('Error in uploadPostImages: $e');
      return [];
    }
  }

  Future<List<String>> uploadImageFiles(List<XFile> imageFiles) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final List<String> imageUrls = [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      for (int i = 0; i < imageFiles.length; i++) {
        final xFile = imageFiles[i];
        debugPrint('Processing file: ${xFile.name}');

        try {
          // Read the file bytes directly
          final bytes = await xFile.readAsBytes();

          if (bytes.isEmpty) {
            debugPrint('File is empty: ${xFile.name}');
            continue;
          }

          debugPrint('Preparing to upload ${bytes.length} bytes');

          // Create a unique image path using UUID instead of timestamp+index
          final fileName =
              '${timestamp}_${i}_${xFile.name.replaceAll(' ', '_')}';
          final imageRef = FirebaseStorage.instance
              .ref()
              .child('post_images/${currentUser.uid}/$fileName');

          // Upload file data with metadata
          final metadata = SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {'uploaded_by': currentUser.uid});

          // Upload with tracking
          final uploadTask = imageRef.putData(bytes, metadata);

          // Add progress listener
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            debugPrint(
                'Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
          });

          // Wait for the upload to complete
          await uploadTask;
          debugPrint('Upload completed, getting download URL');

          // Get download URL with optimized exponential backoff logic
          String? downloadUrl;
          int attempts = 0;
          const maxAttempts = 3;

          while (downloadUrl == null && attempts < maxAttempts) {
            try {
              // Use exponential backoff with a base delay of 300ms
              final backoffDelay = (attempts == 0) ? 0 : 300 * (1 << attempts);
              if (backoffDelay > 0) {
                debugPrint(
                    'Waiting ${backoffDelay}ms before attempt ${attempts + 1}');
                await Future.delayed(Duration(milliseconds: backoffDelay));
              }

              attempts++;
              downloadUrl = await imageRef.getDownloadURL();
            } catch (urlError) {
              debugPrint(
                  'Error getting download URL (attempt $attempts/$maxAttempts): $urlError');

              if (attempts >= maxAttempts) {
                debugPrint('Max attempts reached, giving up on this image URL');
              }
            }
          }

          if (downloadUrl != null && downloadUrl.isNotEmpty) {
            imageUrls.add(downloadUrl);
            debugPrint('✅ Image successfully uploaded: $downloadUrl');
          } else {
            debugPrint(
                '⚠️ Failed to get download URL after $attempts attempts');
          }
        } catch (uploadError) {
          debugPrint('❌ Error processing image ${xFile.name}: $uploadError');
        }
      }

      debugPrint('Total URLs collected: ${imageUrls.length}');
      return imageUrls;
    } catch (e) {
      debugPrint('❌ Error in uploadImageFiles: $e');
      return [];
    }
  }

  Future<DocumentReference?> createPost({
    required String content,
    required String category,
    List<File>? imageFiles,
    List<XFile>? selectedImages, // Add this parameter for web compatibility
    bool isProfessional = false,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      // Upload images if provided
      List<String> mediaUrls = [];

      // Handle web uploads using XFile
      if (selectedImages != null && selectedImages.isNotEmpty) {
        mediaUrls = await uploadImageFiles(selectedImages);
      }
      // Handle mobile uploads using File
      else if (imageFiles != null && imageFiles.isNotEmpty) {
        mediaUrls = await uploadPostImages(imageFiles);
      }

      debugPrint('Creating post with ${mediaUrls.length} media URLs');

      // Create the post document
      return await _firestore.collection('posts').add({
        'content': content,
        'title': '', // Keep empty string for compatibility
        'mediaUrls': mediaUrls,
        'imageIds': [], // Empty array for compatibility
        'category': category,
        'authorId': currentUser.uid,
        'authorName': currentUser.displayName ?? 'User',
        'authorPhotoUrl': currentUser.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
        'isProfessionalPost': isProfessional,
      });
    } catch (e) {
      debugPrint('Error creating post: $e');
      return null;
    }
  }
}
