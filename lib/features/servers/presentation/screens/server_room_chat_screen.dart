import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/features/servers/data/models/chat_server_room.dart';
import 'package:blind_social/features/servers/data/models/server_message.dart';
import 'package:blind_social/features/servers/data/services/chat_server_service.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'package:blind_social/core/widgets/expandable_text.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:blind_social/core/widgets/chat_input_field.dart';

import 'package:blind_social/core/widgets/voice_message_widget.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';

class ServerRoomChatScreen extends StatefulWidget {
  final ChatServerRoom room;
  const ServerRoomChatScreen({super.key, required this.room});

  @override
  State<ServerRoomChatScreen> createState() => _ServerRoomChatScreenState();
}

class _ServerRoomChatScreenState extends State<ServerRoomChatScreen> {
  final ScrollController _scrollController = ScrollController();
  List<ServerMessage> _messages = [];
  bool _isLoading = true;
  UnsubscribeFunc? _unsub;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _setupSubscription();
  }

  @override
  void dispose() {
    _unsub?.call();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupSubscription() async {
    final sub = await ChatServerService().subscribeToRoomMessages(widget.room.id, (RecordSubscriptionEvent e) {
      if (e.action == 'create') {
        final newMessage = ServerMessage.fromRecord(e.record!);
        if (mounted) {
          setState(() {
            // Check if already exists to avoid duplicates (though create shouldn't duplicate)
            if (!_messages.any((m) => m.id == newMessage.id)) {
              _messages.add(newMessage);
            }
          });
          _scrollToBottom();
        }
      } else if (e.action == 'delete') {
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m.id == e.record!.id);
          });
        }
      }
    });
    if (!mounted) {
      sub.call();
      return;
    }
    _unsub = sub;
  }

  Future<void> _fetchMessages() async {
    try {
      final messages = await ChatServerService().getRoomMessages(widget.room.id);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(child: Text('Henüz mesaj yok.'))
                  : ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.senderId == ChatServerService().currentUserId;
                        final senderName = message.expand?['sender_id']?['username'] ?? 'Bilinmeyen';
                        final isVoice = message.content.startsWith('[VOICE]');
                        
                        String? voiceUrl;
                        if (isVoice && message.file != null && message.file!.isNotEmpty) {
                          const collectionId = 'col_server_messages';
                          voiceUrl = '${PocketBaseService.client.baseUrl}/api/files/$collectionId/${message.id}/${message.file}';
                        }

                        final timeStr = DateFormat('HH:mm').format(message.created.toLocal());

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Semantics(
                            label: "${isMe ? 'Siz' : senderName}: ${isVoice ? 'Sesli mesaj' : message.content}. $timeStr",
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
                                    : Colors.grey[800],
                                borderRadius: BorderRadius.circular(16).copyWith(
                                  bottomRight: isMe ? const Radius.circular(0) : null,
                                  bottomLeft: !isMe ? const Radius.circular(0) : null,
                                ),
                              ),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Text(
                                      senderName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                  if (isVoice && voiceUrl != null)
                                    VoiceMessageWidget(url: voiceUrl, isMyMessage: isMe)
                                  else
                                    ExpandableText(
                                      text: ProfanityFilter.filter(message.content),
                                      maxLines: 10,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeStr,
                                    style: const TextStyle(fontSize: 10, color: Colors.white60),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        ChatInputField(
          onSendText: (text) => _sendTextMessage(text),
          onSendAudio: (path) => _sendAudioMessage(path),
          hintText: 'Mesaj yazın...',
        ),
      ],
    );
  }

  Future<void> _sendTextMessage(String content) async {
    try {
      await ChatServerService().sendRoomMessage(
        roomId: widget.room.id,
        content: content,
      );
      _fetchMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _sendAudioMessage(String path) async {
    try {
      await ChatServerService().sendRoomAudio(
        roomId: widget.room.id,
        audioPath: path,
      );
      _fetchMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ses gönderme hatası: $e')));
      }
    }
  }
}
