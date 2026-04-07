import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_service.dart';

class Message {
  final int? id;
  final String text;
  final String senderRole;
  final DateTime timestamp;

  Message({this.id, required this.text, required this.senderRole, required this.timestamp});

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      text: map['text'],
      senderRole: map['sender_role'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

class ChatNotifier extends Notifier<List<Message>> {
  final DatabaseService _db = DatabaseService();

  @override
  List<Message> build() {
    loadMessages();
    return [];
  }

  Future<void> loadMessages() async {
    final maps = await _db.getChatMessages();
    state = maps.map((m) => Message.fromMap(m)).toList();
  }

  Future<void> sendMessage(String text) async {
    final now = DateTime.now();
    // 1. Optimistic update
    final newMessage = Message(text: text, senderRole: 'user', timestamp: now);
    state = [...state, newMessage];

    // 2. Persistance
    await _db.sendChatMessage(text, 'user');
    
    // 3. Simulation réponse admin
    if (text.toLowerCase().contains('bonjour')) {
      await Future.delayed(const Duration(seconds: 1));
      const response = "Bonjour ! Nous étudions votre demande. Un admin reviendra vers vous très vite.";
      await _db.sendChatMessage(response, 'admin');
      loadMessages();
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<Message>>(() {
  return ChatNotifier();
});
