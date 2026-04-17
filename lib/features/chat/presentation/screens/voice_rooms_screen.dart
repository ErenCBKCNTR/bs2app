import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:blind_social/features/chat/presentation/screens/active_voice_room_screen.dart';
import 'dart:async';
import '../../../../core/utils/logger.dart';

class VoiceRoomsScreen extends StatefulWidget {
  const VoiceRoomsScreen({super.key});

  @override
  State<VoiceRoomsScreen> createState() => _VoiceRoomsScreenState();
}

class _VoiceRoomsScreenState extends State<VoiceRoomsScreen> {
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchRooms(isBackground: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRooms({bool isBackground = false}) async {
    try {
      final response = await Supabase.instance.client
          .from('voice_rooms')
          .select()
          .eq('is_active', true)
          .order('created_at');
          
      if (mounted) {
        setState(() {
          _rooms = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!isBackground) {
        AppLogger.instance.error('Odalar yüklenirken hata: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rooms.isEmpty) {
      return const Center(
        child: Text(
          'Şu an aktif bir sesli oda bulunmuyor.\nYeni bir oda oluşturabilirsiniz.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      itemCount: _rooms.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
      itemBuilder: (context, index) {
        final room = _rooms[index];
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ActiveVoiceRoomScreen(
                    roomId: room['id'].toString(),
                    roomName: room['name'].toString(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
