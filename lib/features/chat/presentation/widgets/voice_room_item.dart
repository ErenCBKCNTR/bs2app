
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blind_social/core/providers/localization_provider.dart';

class VoiceRoomItem extends ConsumerWidget {
  final String roomName;
  final VoidCallback onTap;

  const VoiceRoomItem({
    super.key,
    required this.roomName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localizationProvider);
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
        subtitle: Text(lang.liveVoiceRoom),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
