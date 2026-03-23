import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

/// Persists AI chat messages to local storage (non-web) or Firebase (web).
class ChatService {
  DatabaseReference? get _dbRef => kIsWeb ? FirebaseDatabase.instance.ref() : null;

  String _sanitizeKey(String key) {
    return key
        .replaceAll('.', '_')
        .replaceAll('#', '_')
        .replaceAll('\$', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_')
        .replaceAll('/', '_');
  }

  String _getLocalStorageKey(String studentId) {
    return 'chat_history_${_sanitizeKey(studentId)}';
  }

  DatabaseReference? _messagesRef(String studentId) {
    if (!kIsWeb || _dbRef == null) return null;
    return _dbRef!
        .child('chat_history')
        .child(_sanitizeKey(studentId))
        .child('messages');
  }

  Future<void> saveMessage({
    required String studentId,
    required types.Message message,
  }) async {
    print('DEBUG: Saving message for student: $studentId (web: $kIsWeb)');
    try {
      if (kIsWeb) {
        await _saveToFirebase(studentId, message);
      } else {
        await _saveToLocal(studentId, message);
      }
      print('DEBUG: Message saved successfully');
    } catch (e) {
      print('ERROR: Failed to save message: $e');
    }
  }

  Future<void> _saveToFirebase(String studentId, types.Message message) async {
    final ref = _messagesRef(studentId)!.child(message.id);

    if (message is types.TextMessage) {
      await ref.set({
        'id': message.id,
        'role': message.author.id == 'topper-ai' ? 'assistant' : 'user',
        'type': 'text',
        'text': message.text,
        'authorId': message.author.id,
        'authorName': message.author.firstName ?? '',
        'createdAt': message.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      });
    } else if (message is types.ImageMessage) {
      await ref.set({
        'id': message.id,
        'role': 'assistant',
        'type': 'image',
        'imageUrl': message.uri,
        'imageName': message.name,
        'authorId': message.author.id,
        'authorName': message.author.firstName ?? '',
        'createdAt': message.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<void> _saveToLocal(String studentId, types.Message message) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getLocalStorageKey(studentId);
    
    final messages = await _loadMessagesFromLocal(key);
    final msgData = _messageToMap(message);
    messages[message.id] = msgData;
    
    await prefs.setString(key, json.encode(messages));
  }

  Future<Map<String, dynamic>> _loadMessagesFromLocal(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    if (data == null) return {};
    final decoded = json.decode(data) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as Map<String, dynamic>));
  }

  Map<String, dynamic> _messageToMap(types.Message message) {
    final Map<String, dynamic> data = {
      'id': message.id,
      'authorId': message.author.id,
      'authorName': message.author.firstName ?? '',
      'createdAt': message.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    };

    if (message is types.TextMessage) {
      data['type'] = 'text';
      data['text'] = message.text;
      data['role'] = message.author.id == 'topper-ai' ? 'assistant' : 'user';
    } else if (message is types.ImageMessage) {
      data['type'] = 'image';
      data['imageUrl'] = message.uri;
      data['imageName'] = message.name;
      data['role'] = 'assistant';
    }

    return data;
  }

  Future<List<types.Message>> loadHistory(String studentId) async {
    final aiUser = const types.User(
      id: 'topper-ai',
      firstName: 'TopperAI',
      imageUrl: 'assets/AIAvtar.png',
    );

    try {
      print('DEBUG: Loading chat history for student: $studentId (web: $kIsWeb)');

      if (kIsWeb) {
        return await _loadFromFirebase(studentId, aiUser);
      } else {
        return await _loadFromLocal(studentId, aiUser);
      }
    } catch (e) {
      print('ERROR: Failed to load history: $e');
      return [];
    }
  }

  Future<List<types.Message>> _loadFromFirebase(String studentId, types.User aiUser) async {
    final snapshot = await _messagesRef(studentId)!.get();
    print('DEBUG: Firebase snapshot exists: ${snapshot.exists}');

    if (!snapshot.exists || snapshot.value == null) {
      print('DEBUG: No history found');
      return [];
    }

    return _parseMessages(snapshot.value, aiUser);
  }

  Future<List<types.Message>> _loadFromLocal(String studentId, types.User aiUser) async {
    final key = _getLocalStorageKey(studentId);
    final data = await _loadMessagesFromLocal(key);
    print('DEBUG: Local data entries: ${data.length}');

    if (data.isEmpty) {
      return [];
    }

    return _parseMessages(data, aiUser);
  }

  List<types.Message> _parseMessages(dynamic rawValue, types.User aiUser) {
    final List<types.Message> messages = [];

    Map<dynamic, dynamic> data;
    if (rawValue is Map) {
      data = Map<dynamic, dynamic>.from(rawValue);
    } else if (rawValue is List) {
      data = {};
      for (int i = 0; i < rawValue.length; i++) {
        if (rawValue[i] != null) {
          data[i.toString()] = rawValue[i];
        }
      }
    } else {
      return [];
    }

    data.forEach((key, value) {
      if (value is Map) {
        try {
          final msgData = Map<dynamic, dynamic>.from(value);
          final authorId = msgData['authorId']?.toString() ?? '';
          final authorName = msgData['authorName']?.toString() ?? '';
          final author = authorId == 'topper-ai'
              ? aiUser
              : types.User(
                  id: authorId.isNotEmpty ? authorId : 'user',
                  firstName: authorName,
                );

          final createdAt = msgData['createdAt'] is int
              ? msgData['createdAt'] as int
              : (msgData['createdAt'] as num?)?.toInt() ??
                    DateTime.now().millisecondsSinceEpoch;

          final type = msgData['type']?.toString() ?? 'text';
          final msgId = msgData['id']?.toString() ?? key.toString();

          if (type == 'image') {
            messages.add(
              types.ImageMessage(
                id: msgId,
                author: author,
                createdAt: createdAt,
                name: msgData['imageName']?.toString() ?? 'Image',
                size: 1024,
                uri: msgData['imageUrl']?.toString() ?? '',
              ),
            );
          } else {
            final text = msgData['text']?.toString() ?? '';
            if (text.isNotEmpty) {
              messages.add(
                types.TextMessage(
                  id: msgId,
                  author: author,
                  createdAt: createdAt,
                  text: text,
                ),
              );
            }
          }
        } catch (e) {
          print('DEBUG: Error parsing message entry: $e');
        }
      }
    });

    print('DEBUG: Loaded ${messages.length} messages');
    messages.sort((a, b) => (a.createdAt ?? 0).compareTo(b.createdAt ?? 0));
    return messages;
  }

  Future<void> clearHistory(String studentId) async {
    try {
      if (kIsWeb) {
        await _messagesRef(studentId)?.remove();
      } else {
        final prefs = await SharedPreferences.getInstance();
        final key = _getLocalStorageKey(studentId);
        await prefs.remove(key);
      }
    } catch (e) {
      print('ERROR: Failed to clear history: $e');
    }
  }
}
