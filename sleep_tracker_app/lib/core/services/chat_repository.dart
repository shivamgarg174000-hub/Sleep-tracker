import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/chat_message.dart';

class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _thread(String uid) =>
      _db.collection('users').doc(uid).collection('aiConversations');

  Stream<List<ChatMessage>> watchMessages(String uid) {
    return _thread(uid)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<void> addMessage(String uid, ChatMessage message) async {
    await _thread(uid).add(message.toMap());
  }

  /// Last N messages in chronological order — what actually gets sent to
  /// the model as conversation context (kept bounded so token usage / free
  /// tier quota stays sane).
  Future<List<ChatMessage>> recentHistory(String uid, {int limit = 20}) async {
    final snap = await _thread(uid).orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map(ChatMessage.fromDoc).toList().reversed.toList();
  }
}
