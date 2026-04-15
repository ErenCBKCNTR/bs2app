import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

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
          const Center(child: Text("Sesli Odalar")),
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
    final chats = [
      {"name": "Ahmet Yılmaz", "lastMsg": "Selam kardeşim, akşamki sesli odaya katılıyor musun?", "time": "14:45", "unread": 2},
      {"name": "Elif Demir", "lastMsg": "Sesli mesaj: 0:45", "time": "12:10", "unread": 0},
      {"name": "Teknoloji Grubu", "lastMsg": "Can: Yeni ekran okuyucu güncellemesi yayına alındı.", "time": "Dün", "unread": 15},
      {"name": "Mert Erkan", "lastMsg": "Tamamdır, haberleşiriz.", "time": "Dün", "unread": 0},
    ];

    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
      itemBuilder: (context, index) {
        final chat = chats[index];
        final bool hasUnread = (chat['unread'] as int) > 0;

        return Semantics(
          label: "${chat['name']} ile sohbet. Son mesaj: ${chat['lastMsg']}. Saat: ${chat['time']}. ${hasUnread ? "${chat['unread']} okunmamış mesaj var." : ""}",
          button: true,
          onTapHint: "Sohbeti açmak için çift dokunun",
          child: ListTile(
            // Standart CircleAvatar boyutu
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[800],
              child: Text(
                chat['name'].toString().split(' ').map((e) => e[0]).take(2).join(''),
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            title: Text(
              chat['name'].toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              chat['lastMsg'].toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chat['time'].toString(),
                  style: TextStyle(
                    color: hasUnread ? Theme.of(context).colorScheme.primary : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                if (hasUnread)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      chat['unread'].toString(),
                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            onTap: () {},
          ),
        );
      },
    );
  }
}
