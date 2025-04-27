import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        'createdAt': FieldValue.serverTimestamp(),
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

  // Stream of all posts for real-time updates
  Stream<QuerySnapshot> getPostsStream() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Stream of comments for a specific post (most recent first)
  Stream<QuerySnapshot> getCommentsStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
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
}
