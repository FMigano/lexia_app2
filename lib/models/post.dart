import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String content;
  final String title;
  final List<String> mediaUrls;
  final List<String> imageIds; // Add this new field
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool isProfessionalPost;
  final String category;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.content,
    this.title = '',
    this.mediaUrls = const [],
    this.imageIds = const [], // Keep this for backward compatibility
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.isProfessionalPost,
    required this.category,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post.fromMap(data, doc.id);
  }

  factory Post.fromMap(Map<String, dynamic> map, String id) {
    // Debug the mediaUrls field
    final rawMediaUrls = map['mediaUrls'];
    debugPrint('Raw mediaUrls type: ${rawMediaUrls.runtimeType}');
    debugPrint('Raw mediaUrls value: $rawMediaUrls');

    List<String> mediaUrls = [];
    try {
      if (rawMediaUrls != null) {
        mediaUrls = List<String>.from(rawMediaUrls);
      }
    } catch (e) {
      debugPrint('Error parsing mediaUrls: $e');
    }

    return Post(
      id: id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Anonymous',
      authorPhotoUrl: map['authorPhotoUrl'] ?? '',
      content: map['content'] ?? '',
      title: map['title'] ?? '',
      mediaUrls: mediaUrls,
      imageIds: List<String>.from(map['imageIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: map['likeCount'] ?? 0,
      commentCount: map['commentCount'] ?? 0,
      isProfessionalPost: map['isProfessionalPost'] ?? false,
      category: map['category'] ?? 'General',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'content': content,
      'title': title,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'createdAt': createdAt,
      'isProfessionalPost': isProfessionalPost,
      'mediaUrls': mediaUrls,
      'imageIds': imageIds, // Include imageIds in map
      'category': category,
    };
  }
}
