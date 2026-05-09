import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../../core/services/pocketbase_service.dart';
import '../../../../core/utils/logger.dart';

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  // Şimdilik arkadaşlık sistemi kurulana kadar boş bir liste tutuyoruz.
  List<RecordModel> _friends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final currentUserId = PocketBaseService.client.authStore.model!.id;
      final response = await PocketBaseService.client.collection('friendships').getFullList(
        filter: 'user1 = "$currentUserId" || user2 = "$currentUserId"',
        expand: 'user1,user2',
      );

      List<RecordModel> friendsList = [];

      for (var f in response) {
        final u1List = f.expand['user1'];
        final u2List = f.expand['user2'];
        final u1 = (u1List != null && u1List.isNotEmpty) ? u1List.first : null;
        final u2 = (u2List != null && u2List.isNotEmpty) ? u2List.first : null;
        
        if (u1 != null && u1.id != currentUserId) friendsList.add(u1);
        if (u2 != null && u2.id != currentUserId) friendsList.add(u2);
      }

      friendsList.sort((a, b) {
        final aName = a.getStringValue('full_name').isNotEmpty ? a.getStringValue('full_name') : a.getStringValue('username');
        final bName = b.getStringValue('full_name').isNotEmpty ? b.getStringValue('full_name') : b.getStringValue('username');
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _friends = friendsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.instance.error('Arkadaş listesi çekilirken hata: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onNewContactPressed() async {
    final searchController = TextEditingController();
    bool isSearching = false;
    String? errorMessage;

    final RecordModel? result = await showDialog<RecordModel>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Kullanıcı Ara'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    maxLength: 32,
                    decoration: InputDecoration(
                      labelText: 'Kullanıcı Adı',
                      hintText: 'Örn: ahmet123',
                      border: const OutlineInputBorder(),
                      errorText: errorMessage,
                      counterText: "",
                    ),
                    onSubmitted: (val) {
                      // Tetiklemeyi butondan yapıyoruz ama submit için de eklenebilir.
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSearching ? null : () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isSearching ? null : () async {
                    final username = searchController.text.trim();
                    if (username.isEmpty) return;
                    
                    final currentUserId = PocketBaseService.client.authStore.model!.id;

                    setStateDialog(() {
                      isSearching = true;
                      errorMessage = null;
                    });
                    
                    try {
                      final response = await PocketBaseService.client.collection('users').getFirstListItem('username = "${username.toLowerCase()}"');

                      if (response.id == currentUserId) {
                         setStateDialog(() {
                           isSearching = false;
                           errorMessage = "Kendinizle sohbet edemezsiniz.";
                         });
                      } else {
                         // Kullanıcı bulundu! Geri döndür.
                         if (context.mounted) {
                           Navigator.pop(context, response);
                         }
                      }
                    } catch (e) {
                      AppLogger.instance.error('Kullanıcı arama hatası: $e');
                      setStateDialog(() {
                        isSearching = false;
                        errorMessage = "Böyle bir kullanıcı bulunamadı.";
                      });
                    }
                  },
                  child: isSearching 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Ara & Mesaj At'),
                ),
              ],
            );
          }
        );
      }
    );

    if (result != null && mounted) {
      // Bulunan kullanıcıyı önceki sayfaya (ChatListScreen) geri döndür ki orada sohbet başlatılabilsin.
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kişi seç', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${_friends.length} kişi', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.grey)),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.person_add, color: Colors.white),
                  ),
                  title: const Text('Yeni kişi', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: _onNewContactPressed,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Uygulamadaki Kişiler', 
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400]
                    )
                  ),
                ),
                Expanded(
                  child: _friends.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "Henüz arkadaşınız bulunmuyor.\nYukarıdan 'Yeni kişi' butonuna tıklayarak arkadaş ekleyebilirsiniz.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _friends.length,
                        itemBuilder: (context, index) {
                          final friend = _friends[index];
                          final fullName = friend.getStringValue('full_name');
                          final username = friend.getStringValue('username');
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : '?'),
                            ),
                            title: Text(fullName.isNotEmpty ? fullName : username),
                            subtitle: Text('@$username'),
                            onTap: () {
                              Navigator.pop(context, friend);
                            },
                          );
                        },
                      ),
                ),
              ],
            ),
      ),
    );
  }
}
