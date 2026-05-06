import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';

class SendAnnouncementScreen extends StatefulWidget {
  const SendAnnouncementScreen({super.key});

  @override
  State<SendAnnouncementScreen> createState() => _SendAnnouncementScreenState();
}

class _SendAnnouncementScreenState extends State<SendAnnouncementScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  Future<void> _sendAnnouncement() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final client = PocketBaseService.client;
      final adminId = client.authStore.model?.id;
      if (adminId == null) throw Exception('Yönetici girişi bulunamadı.');

      // 1. Check if "Blind Social Ekibi" chat exists
      final chats = await client.collection('chats').getFullList(
          filter: 'name = "Blind Social Ekibi" && is_group = true',
      );

      String chatId;
      if (chats.isNotEmpty) {
        chatId = chats.first.id;
      } else {
        // Create the chat
        final newChat = await client.collection('chats').create(body: {
          'name': 'Blind Social Ekibi',
          'is_group': true,
          'created_by': adminId,
        });
        chatId = newChat.id;
      }

      // 2. Fetch all users
      final users = await client.collection('users').getFullList(fields: 'id');

      // 3. Fetch existing participants of this chat to avoid duplicates
      final participants = await client.collection('chat_participants').getFullList(
         filter: 'chat_id = "$chatId"',
         fields: 'user_id'
      );
      final existingUserIds = participants.map((p) => p.getStringValue('user_id')).toSet();

      // 4. Add missing users to chat
      for (var user in users) {
        if (!existingUserIds.contains(user.id)) {
           await client.collection('chat_participants').create(body: {
             'chat_id': chatId,
             'user_id': user.id,
           });
        }
      }

      // 5. Send message
      await client.collection('messages').create(body: {
        'chat_id': chatId,
        'sender_id': adminId,
        'content': text,
      });

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duyuru başarıyla gönderildi.')));
         Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
         setState(() {
           _isSending = false;
         });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcılara Mesaj Gönder'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Buradan göndereceğiniz mesajlar tüm kullanıcılara "Blind Social Ekibi" adı altında özel mesaj olarak iletilecektir.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Mesajınızı buraya yazın...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendAnnouncement,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                  child: _isSending 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Tüm Kullanıcılara Gönder', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
