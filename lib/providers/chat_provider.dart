import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/message_model.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<MessageModel>> getMessagesStream() {
    _cleanupOldMessages();
    return _firestore
        .collection('GlobalChat')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  Stream<bool> getChatStatusStream() {
    return _firestore
        .collection('Settings')
        .doc('ChatSettings')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data()!['isChatEnabled'] ?? true;
      }
      return true;
    });
  }

  Future<void> toggleChatStatus(bool isEnabled) async {
    try {
      await _firestore.collection('Settings').doc('ChatSettings').set({
        'isChatEnabled': isEnabled,
      }, SetOptions(merge: true));
    } catch (e) {}
  }

  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String senderImage,
    required String text,
  }) async {
    try {
      await _firestore.collection('GlobalChat').add({
        'senderId': senderId,
        'senderName': senderName,
        'senderImage': senderImage,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore.collection('GlobalChat').doc(messageId).delete();
    } catch (e) {}
  }

  Future<void> _cleanupOldMessages() async {
    try {
      final twelveHoursAgo = DateTime.now().subtract(const Duration(hours: 12));
      final snapshot = await _firestore
          .collection('GlobalChat')
          .where('timestamp', isLessThan: Timestamp.fromDate(twelveHoursAgo))
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {}
  }
}