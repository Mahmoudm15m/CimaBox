import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/comment_model.dart';
import '../models/reply_model.dart';

class CommentsProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<CommentModel>> getCommentsStream(String contentId) {
    return _firestore
        .collection('Comments')
        .where('contentId', isEqualTo: contentId)
        .snapshots()
        .map((snapshot) {
      final comments = snapshot.docs.map((doc) => CommentModel.fromFirestore(doc)).toList();
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return comments;
    });
  }

  Future<void> addComment({
    required String contentId,
    required String userId,
    required String userName,
    required String userImage,
    required String text,
  }) async {
    try {
      await _firestore.collection('Comments').add({
        'contentId': contentId,
        'userId': userId,
        'userName': userName,
        'userImage': userImage,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'likedBy': [],
        'repliesCount': 0,
      });
    } catch (e) {}
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _firestore.collection('Comments').doc(commentId).delete();
    } catch (e) {}
  }

  Future<void> toggleCommentLike(String commentId, String userId, bool isCurrentlyLiked) async {
    try {
      if (isCurrentlyLiked) {
        await _firestore.collection('Comments').doc(commentId).update({
          'likesCount': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([userId]),
        });
      } else {
        await _firestore.collection('Comments').doc(commentId).update({
          'likesCount': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId]),
        });
      }
    } catch (e) {}
  }

  Stream<List<ReplyModel>> getRepliesStream(String commentId) {
    return _firestore
        .collection('Comments')
        .doc(commentId)
        .collection('Replies')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ReplyModel.fromFirestore(doc)).toList());
  }

  Future<void> addReply({
    required String commentId,
    required String userId,
    required String userName,
    required String userImage,
    required String text,
  }) async {
    try {
      await _firestore.collection('Comments').doc(commentId).collection('Replies').add({
        'commentId': commentId,
        'userId': userId,
        'userName': userName,
        'userImage': userImage,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'likedBy': [],
      });

      await _firestore.collection('Comments').doc(commentId).update({
        'repliesCount': FieldValue.increment(1),
      });
    } catch (e) {}
  }

  Future<void> deleteReply(String commentId, String replyId) async {
    try {
      await _firestore.collection('Comments').doc(commentId).collection('Replies').doc(replyId).delete();
      await _firestore.collection('Comments').doc(commentId).update({
        'repliesCount': FieldValue.increment(-1),
      });
    } catch (e) {}
  }

  Future<void> toggleReplyLike(String commentId, String replyId, String userId, bool isCurrentlyLiked) async {
    try {
      DocumentReference replyRef = _firestore
          .collection('Comments')
          .doc(commentId)
          .collection('Replies')
          .doc(replyId);

      if (isCurrentlyLiked) {
        await replyRef.update({
          'likesCount': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([userId]),
        });
      } else {
        await replyRef.update({
          'likesCount': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId]),
        });
      }
    } catch (e) {}
  }
}