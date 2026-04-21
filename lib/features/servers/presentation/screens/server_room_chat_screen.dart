import 'package:flutter/material.dart';
import 'package:blind_social/features/servers/data/models/chat_server_room.dart';
import 'package:blind_social/features/servers/data/models/server_message.dart';
import 'package:blind_social/features/servers/data/services/chat_server_service.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ServerRoomChatScreen extends StatefulWidget {
  final ChatServerRoom room;
  const ServerRoomChatScreen({super.key, required this.room});

  @override
  State<ServerRoomChatScreen> createState() => _ServerRoomChatScreenState();
}

class _ServerRoomChatScreenState extends State<ServerRoomChatScreen> {
  final TextEditingController _messageController = TextEditingController();
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
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupSubscription() async {
    _unsub = await ChatServerService().subscribeToRoomMessages(widget.room.id, (RecordSubscriptionEvent e) {
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
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
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.senderId == ChatServerService().currentUserId;
                        final senderName = message.expand?['sender_id']?['name'] ?? 'Bilinmeyen';

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                                Text(
                                  ProfanityFilter.filter(message.content),
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('HH:mm').format(message.created.toLocal()),
                                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.black26,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Mesaj yazın...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendMessage,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
