import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMyMessage;
  final VoidCallback onLongPress;
  final VoidCallback onFavoriteToggle;
  final Function(String) onReact;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Widget readStatus;
  final Widget? voiceWidget;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMyMessage,
    required this.onLongPress,
    required this.onFavoriteToggle,
    required this.onReact,
    this.onEdit,
    this.onDelete,
    required this.readStatus,
    this.voiceWidget,
  });

  @override
  Widget build(BuildContext context) {
    final content = message['content'];
    final createdAt = DateTime.parse(message['created'] ?? DateTime.now().toIso8601String()).toLocal();
    final timeString = DateFormat('HH:mm').format(createdAt);
    final isCallMessage = content.toString().contains('CALL_');
    final isVoiceMessage = content.toString().startsWith('[VOICE]');
    final bool isFavorite = message['is_favorite'] == true;
    final reactions = message['reactions'] as String? ?? '';
    final created = DateTime.parse(message['created']).toUtc();
    final updated = DateTime.parse(message['updated']).toUtc();
    final bool isEdited = updated.difference(created).inSeconds > 1;

    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        label: "${isFavorite ? 'Yıldızlı. ' : ''}${isVoiceMessage 
            ? (isMyMessage ? "Gönderdiğiniz sesli mesaj. $timeString" : "Gelen sesli mesaj. $timeString") 
            : (isCallMessage 
                ? "$content. $timeString" 
                : (isMyMessage ? "Gönderdiğiniz mesaj: $content. $timeString" : "Gelen mesaj: $content. $timeString"))}${isEdited ? '. Düzenlendi' : ''}${reactions.isNotEmpty ? '. Tepkiler: $reactions' : ''}",
        button: true,
        onLongPressHint: "Tepki eklemek veya diğer seçenekler için uzun dokunun",
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isCallMessage 
                    ? Colors.blueGrey[900]?.withOpacity(0.5) 
                    : (isMyMessage ? Colors.green[700] : Colors.grey[800]),
                  borderRadius: BorderRadius.circular(12),
                  border: isCallMessage ? Border.all(color: Colors.white24, width: 0.5) : null,
                ),
                child: Column(
                  crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (voiceWidget != null) voiceWidget!,
                    if (!isVoiceMessage)
                      Text(
                        content.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    if (isEdited)
                      const Text(
                        'Düzenlendi',
                        style: TextStyle(fontSize: 10, color: Colors.white70, fontStyle: FontStyle.italic),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isFavorite)
                          const Icon(Icons.star, color: Colors.amber, size: 12),
                        if (isFavorite) const SizedBox(width: 4),
                        Text(
                          timeString,
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                        if (isMyMessage) ...[
                          const SizedBox(width: 4),
                          readStatus,
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (reactions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(reactions, style: const TextStyle(fontSize: 16)),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
