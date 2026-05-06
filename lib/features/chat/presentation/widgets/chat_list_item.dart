
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';

class ChatListItem extends StatelessWidget {
  final RecordModel chat;
  final String currentUserId;
  final int unreadCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onPin;

  const ChatListItem({
    super.key,
    required this.chat,
    required this.currentUserId,
    this.unreadCount = 0,
    required this.onTap,
    required this.onLongPress,
    required this.onArchive,
    required this.onDelete,
    required this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    final myPart = chat.data['my_participant'] as RecordModel?;
    final isPinned = myPart?.getBoolValue('is_pinned') ?? false;
    final displayChatName = chat.getStringValue('name').isEmpty ? 'İsimsiz Sohbet' : chat.getStringValue('name');

    return Dismissible(
      key: Key(chat.id),
      background: Container(
        color: Colors.blue,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.archive, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          onArchive();
        } else {
          onDelete();
        }
      },
      child: ListTile(
        leading: ExcludeSemantics(
          child: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[800],
            child: Text(
              displayChatName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(''),
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                displayChatName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (displayChatName == 'Blind Social Ekibi')
              const Padding(
                padding: EdgeInsets.only(left: 4.0),
                child: Icon(Icons.verified, color: Colors.blue, size: 16),
              ),
            if (isPinned)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.push_pin, size: 16, color: Colors.blue),
              ),
          ],
        ),
        subtitle: const Text('Sohbete gitmek için dokunun', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
             else
                const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
