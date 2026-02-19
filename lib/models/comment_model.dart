import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String contentId;
  final String userId;
  final String userName;
  final String userImage;
  final String text;
  final DateTime createdAt;
  final int likesCount;
  final List<String> likedBy;
  final int repliesCount;

  CommentModel({
    required this.id,
    required this.contentId,
    required this.userId,
    required this.userName,
    required this.userImage,
    required this.text,
    required this.createdAt,
    required this.likesCount,
    required this.likedBy,
    required this.repliesCount,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      contentId: data['contentId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userImage: data['userImage'] ?? '',
      text: data['text'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      likesCount: data['likesCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      repliesCount: data['repliesCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contentId': contentId,
      'userId': userId,
      'userName': userName,
      'userImage': userImage,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'likesCount': likesCount,
      'likedBy': likedBy,
      'repliesCount': repliesCount,
    };
  }
}