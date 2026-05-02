import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
          expand: 'chat_id,chat_id.chat_participants_via_chat_id,chat_id.chat_participants_via_chat_id.user_id'
      );

      List<RecordModel> chatRecords = [];
      for(var p in participants) {
         if (p.expand['chat_id'] != null) {
            final chatData = p.expand['chat_id']!.first as RecordModel;
            
            // Eğer DM ise (is_group false) karşı tarafın adını belirle
            String displayName = chatData.getStringValue('name');
            if (!chatData.getBoolValue('is_group')) {
               final chatParticipants = chatData.expand['chat_participants_via_chat_id'] ?? [];
               for (var cp in chatParticipants) {
                  if (cp.getStringValue('user_id') != userId && cp.expand['user_id'] != null) {
                     displayName = cp.expand['user_id']!.first.getStringValue('username');
                     break;
                  }
               }
            }
            if (displayName.isEmpty) displayName = 'İsimsiz Sohbet';
            
            chatData.data['display_name'] = displayName;
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

  Future<void> _unarchiveChat(String participantId) async {
    try {
      await PocketBaseService.client.collection('chat_participants').update(participantId, body: {
        'is_archived': false
      });
      _fetchArchivedChats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sohbet arşivden çıkarıldı'), duration: Duration(seconds: 2))
        );
      }
    } catch (e) {
      AppLogger.instance.error('Arşivden çıkarma hatası: $e');
    }
  }

  void _showOptions(RecordModel chat) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final myParticipant = chat.data['my_participant'] as RecordModel;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.unarchive),
                title: const Text('Arşivden Çıkar'),
                onTap: () {
                  Navigator.pop(context);
                  _unarchiveChat(myParticipant.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arşivlenmiş Sohbetler')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _chats.isEmpty
                ? const Center(child: Text('Arşivlenmiş sohbet yok.'))
                : ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
                    itemCount: _chats.length,
                    itemBuilder: (context, index) {
                      final chat = _chats[index];
                      final myParticipant = chat.data['my_participant'] as RecordModel;
                      
                      return Semantics(
                        label: "${chat.data['display_name'] ?? 'Sohbet'}. Arşivlenmiş.",
                        excludeSemantics: true,
                        hint: "Sohbeti açmak için çift dokunun, seçenekler için uzun dokunun",
                        customSemanticsActions: {
                          CustomSemanticsAction(label: 'Arşivden çıkar'): () {
                            _unarchiveChat(myParticipant.id);
                          },
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey,
                            child: Text(
                              (chat.data['display_name'] as String? ?? 'S')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(chat.data['display_name'] ?? 'Sohbet'),
                          subtitle: const Text('Arşivden çıkarmak için basılı tutun'),
                          trailing: IconButton(
                            icon: const Icon(Icons.unarchive_outlined),
                            onPressed: () => _unarchiveChat(myParticipant.id),
                            tooltip: 'Arşivden Çıkar',
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailScreen(chat: {'id': chat.id, 'name': chat.getStringValue('name')}),
                              ),
                            );
                            _fetchArchivedChats();
                          },
                          onLongPress: () => _showOptions(chat),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
