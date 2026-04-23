
import 'package:flutter/material.dart';

class VoiceRoomItem extends StatelessWidget {
  final String roomName;
  final VoidCallback onTap;

  const VoiceRoomItem({
    super.key,
    required this.roomName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "$roomName adlı sesli oda. Katılmak için çift dokunun.",
      button: true,
      excludeSemantics: true,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          child: Icon(Icons.mic, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          roomName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: const Text('Canlı Ses Odası'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
