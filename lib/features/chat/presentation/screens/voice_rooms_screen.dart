import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoiceRoomsScreen extends StatelessWidget {
  const VoiceRoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('voice_rooms')
          .stream(primaryKey: ['id'])
          .eq('is_active', true)
          .order('created_at'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        final rooms = snapshot.data ?? [];

        if (rooms.isEmpty) {
          return const Center(
            child: Text(
              'Şu an aktif bir sesli oda bulunmuyor.\nYeni bir oda oluşturabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          itemCount: rooms.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
          itemBuilder: (context, index) {
            final room = rooms[index];
            return Semantics(
              label: "${room['name']} adlı sesli oda. Katılmak için çift dokunun.",
              button: true,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Icon(Icons.mic, color: Theme.of(context).colorScheme.primary),
                ),
                title: Text(
                  room['name'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text('Canlı Ses Odası'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: LiveKit ile odaya katılma mantığı eklenecek
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Odaya bağlanılıyor...')),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
