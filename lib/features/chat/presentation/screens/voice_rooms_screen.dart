import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
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
      final response = await PocketBaseService.client.collection('voice_rooms').getFullList(
          filter: 'is_active = true',
          sort: 'created'
      );
          
      if (mounted) {
        setState(() {
          _rooms = response.map((e) => e.toJson()).toList();
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
        return VoiceRoomItem(
          roomName: room['name'].toString(),
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
        );
      },
    );
  }
}
