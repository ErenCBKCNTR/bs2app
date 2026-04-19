import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/logger.dart';

class FavoriteMessagesScreen extends StatefulWidget {
  final String? chatId;
  final String? chatName;

  const FavoriteMessagesScreen({
    super.key,
    this.chatId,
    this.chatName,
  });

  @override
  State<FavoriteMessagesScreen> createState() => _FavoriteMessagesScreenState();
}

class _FavoriteMessagesScreenState extends State<FavoriteMessagesScreen> {
  List<RecordModel> _favoriteMessages = [];
  List<RecordModel> _filteredMessages = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchFavoriteMessages();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMessages = _favoriteMessages;
      } else {
        _filteredMessages = _favoriteMessages.where((msg) {
          final content = msg.getStringValue('content').toLowerCase();
          return content.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _fetchFavoriteMessages() async {
    try {
      final myId = PocketBaseService.client.authStore.model?.id;
      if (myId == null) return;

      String filter = 'is_favorite = true && deleted_for !~ "$myId"';
      
      // Eğer belirli bir sohbetse sadece o sohbeti getir
      if (widget.chatId != null) {
        filter += ' && chat_id = "${widget.chatId}"';
      } else {
        // Global ise sadece benim dahil olduğum mesajları getir (opsiyonel ama güvenlik için iyi)
        // Ancak PocketBase API kuralları zaten bunu engeller. 
        // Şimdilik sadece is_favorite yeterli çünkü kurallar buna göre ayarlandı.
      }

      final records = await PocketBaseService.client.collection('messages').getFullList(
        filter: filter,
        sort: '-created',
      );
      
      if (mounted) {
        setState(() {
          _favoriteMessages = records;
          _filteredMessages = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.instance.error('Favori mesajlar yüklenemedi: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.chatId != null 
        ? '${widget.chatName} - Favoriler' 
        : 'Tüm Favori Mesajlarım';

    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Mesajlarda ara...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              )
            : Text(title),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                }
                _isSearching = !_isSearching;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredMessages.isEmpty
              ? Center(
                  child: Text(_isSearching 
                      ? 'Arama sonucu bulunamadı.' 
                      : 'Favoriye eklenmiş mesaj bulunamadı.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _filteredMessages.length,
                  itemBuilder: (context, index) {
                    final message = _filteredMessages[index];
                    final content = message.getStringValue('content');
                    final isVoice = content.startsWith('[VOICE]');
                    final isCall = content.contains('CALL_');
                    final createdAt = DateTime.parse(message.created).toLocal();
                    final timeStr = DateFormat('dd.MM.yyyy HH:mm').format(createdAt);
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.grey[900],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.star, color: Colors.amber),
                        title: Text(
                          isVoice ? '[Sesli Mesaj]' : (isCall ? '[Sistem Mesajı]' : content),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          timeStr,
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                        onTap: () {
                           // İsteğe bağlı
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
