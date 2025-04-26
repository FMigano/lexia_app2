import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.imageIds = const [], // Add this line with default empty list
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    this.isProfessionalPost = false,
    required this.category,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Add this section to parse imageIds
    List<String> imageIds = [];
    if (data['imageIds'] != null) {
      imageIds = List<String>.from(data['imageIds']);
    }

    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] ?? '',
      content: data['content'] ?? '',
      title: data['title'] ?? '',
      mediaUrls:
          data['mediaUrls'] != null ? List<String>.from(data['mediaUrls']) : [],
      imageIds: imageIds, // Add this line
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      isProfessionalPost: data['isProfessionalPost'] ?? false,
      category: data['category'] ?? 'Discussion',
    );
  }

  factory Post.fromMap(Map<String, dynamic> map, String id) {
    return Post(
      id: id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorPhotoUrl: map['authorPhotoUrl'] ?? '',
      content: map['content'] ?? '',
      title: map['title'] ?? '',
      likeCount: map['likeCount'] ?? 0,
      commentCount: map['commentCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isProfessionalPost: map['isProfessionalPost'] ?? false,
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      imageIds: List<String>.from(map['imageIds'] ?? []), // Parse imageIds
      category: map['category'] ?? 'Discussion',
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
