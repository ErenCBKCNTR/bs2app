import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'chat_detail_screen.dart';

class ArchivedMessagesScreen extends StatefulWidget {
  const ArchivedMessagesScreen({super.key});

  @override
  State<ArchivedMessagesScreen> createState() => _ArchivedMessagesScreenState();
}

class _ArchivedMessagesScreenState extends State<ArchivedMessagesScreen> {
  List<RecordModel> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchArchivedChats();
  }

  Future<void> _fetchArchivedChats() async {
    try {
      final userId = PocketBaseService.client.authStore.model?.id;
      if (userId == null) return;

      final participants = await PocketBaseService.client.collection('chat_participants').getFullList(
          filter: 'user_id = "$userId" && is_archived = true',
          expand: 'chat_id'
      );

      List<RecordModel> chatRecords = [];
      for(var p in participants) {
         if (p.expand['chat_id'] != null) {
            final chatData = p.expand['chat_id']!.first as RecordModel;
            chatData.data['my_participant'] = p;
            chatRecords.add(chatData);
         }
      }

      if (mounted) {
        setState(() {
          _chats = chatRecords;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.instance.error('Arşivlenen sohbetler yüklenemedi: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arşivlenmiş Sohbetler')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? const Center(child: Text('Arşivlenmiş sohbet yok.'))
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    return ListTile(
                      title: Text(chat.getStringValue('name')),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatDetailScreen(chat: {'id': chat.id, 'name': chat.getStringValue('name')}),
                          ),
                        );
                        _fetchArchivedChats();
                      },
                    );
                  },
                ),
    );
  }
}
