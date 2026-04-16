import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:blind_social/features/chat/presentation/screens/voice_rooms_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Material 3 standartlarında başlık boyutu
        title: Semantics(
          label: "Blind Social Ana Sayfa",
          header: true,
          child: const Text(
            'Blind Social',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search, size: 24),
            tooltip: "Sohbetlerde ara",
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, size: 24),
            tooltip: "Daha fazla seçenek",
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          // Standart sekme metin boyutu
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: [
            Tab(
              child: Semantics(
                label: "Sohbetler sekmesi",
                selected: _tabController.index == 0,
                child: const Text("Sohbetler"),
              ),
            ),
            Tab(
              child: Semantics(
                label: "Blog sekmesi",
                selected: _tabController.index == 1,
                child: const Text("Blog"),
              ),
            ),
            Tab(
              child: Semantics(
                label: "Odalar sekmesi",
                selected: _tabController.index == 2,
                child: const Text("Odalar"),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatList(),
          const Center(child: Text("Blog İçeriği")),
          const VoiceRoomsScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        // Standart FAB boyutu
        backgroundColor: Theme.of(context).colorScheme.primary,
        tooltip: "Yeni sohbet başlat",
        child: const Icon(Icons.message, color: Colors.black, size: 24),
      ),
    );
  }

  Widget _buildChatList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('chats')
          .select()
          .order('updated_at'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        final chats = snapshot.data ?? [];

        if (chats.isEmpty) {
          return const Center(
            child: Text(
              'Henüz bir sohbetiniz yok.\nYeni bir sohbet başlatın.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          itemCount: chats.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
          itemBuilder: (context, index) {
            final chat = chats[index];
            final chatName = chat['name'] ?? 'İsimsiz Sohbet';
            
            return Semantics(
              label: "$chatName ile sohbet.",
              button: true,
              onTapHint: "Sohbeti açmak için çift dokunun",
              child: ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[800],
                  child: Text(
                    chatName.toString().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(''),
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                title: Text(
                  chatName.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  'Sohbete gitmek için dokunun',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Sohbet detay ekranına git
                },
              ),
            );
          },
        );
      },
    );
  }
}
