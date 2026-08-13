import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return ChatMessage(
      id: doc.id,
      role: data['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role == ChatRole.user ? 'user' : 'assistant',
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
