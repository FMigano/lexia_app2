import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Delete image from storage by URL
  Future<void> deleteImageByUrl(String imageUrl) async {
    try {
      // Extract reference from URL
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('Successfully deleted image: ${ref.fullPath}');
    } catch (e) {
      print('Error deleting image: $e');
      // Continue even if deletion fails
    }
  }

  // Delete all images for a post
  Future<void> deletePostImages(List<String> mediaUrls) async {
    for (final url in mediaUrls) {
      // Only try to delete Firebase Storage URLs, not base64 images
      if (!url.startsWith('data:image')) {
        await deleteImageByUrl(url);
      }
    }
  }
}

// Add this to where you handle post deletion
Future<void> deletePost(String postId, List<String> mediaUrls) async {
  try {
    // First delete any images from Firebase Storage
    final storageService = StorageService();
    await storageService.deletePostImages(mediaUrls);

    // Then delete the post document from Firestore
    await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
  } catch (e) {
    debugPrint('Error deleting post: $e');
    rethrow; // Allow the caller to handle the error
  }
}
