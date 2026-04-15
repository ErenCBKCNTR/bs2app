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
        title: Semantics(
          label: "Blind Social Ana Sayfa",
          header: true,
          child: const Text('Blind Social'),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
            tooltip: "Sohbetlerde ara",
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
            tooltip: "Daha fazla seçenek",
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        tooltip: "Yeni sohbet başlat",
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  Widget _buildChatList() {
    // Örnek veri
    final chats = [
      {"name": "Ahmet Yılmaz", "lastMsg": "Sesli mesaj: 0:45", "time": "14:20", "unread": 2},
      {"name": "Erişilebilirlik Grubu", "lastMsg": "Yeni etkinlik duyurusu", "time": "Dün", "unread": 0},
      {"name": "Ayşe Demir", "lastMsg": "Tamam, görüşürüz.", "time": "Pazartesi", "unread": 5},
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
            leading: CircleAvatar(
              backgroundColor: Colors.grey[800],
              child: Text(chat['name'].toString()[0]),
            ),
            title: Text(
              chat['name'].toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              chat['lastMsg'].toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      chat['unread'].toString(),
                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            onTap: () {
              // Sohbet detayına git
            },
          ),
        );
      },
    );
  }
}
