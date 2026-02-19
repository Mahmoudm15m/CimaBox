import 'package:cloud_firestore/cloud_firestore.dart';

class ReplyModel {
  final String id;
  final String commentId;
  final String userId;
  final String userName;
  final String userImage;
  final String text;
  final DateTime createdAt;
  final int likesCount;
  final List<String> likedBy;

  ReplyModel({
    required this.id,
    required this.commentId,
    required this.userId,
    required this.userName,
    required this.userImage,
    required this.text,
    required this.createdAt,
    required this.likesCount,
    required this.likedBy,
  });

  factory ReplyModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ReplyModel(
      id: doc.id,
      commentId: data['commentId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userImage: data['userImage'] ?? '',
      text: data['text'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      likesCount: data['likesCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'userId': userId,
      'userName': userName,
      'userImage': userImage,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'likesCount': likesCount,
      'likedBy': likedBy,
    };
  }
}