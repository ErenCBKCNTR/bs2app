import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
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

      final baseFilter = widget.chatId != null 
          ? 'is_favorite = true && chat_id = "${widget.chatId}"'
          : 'is_favorite = true';
          
      String filter = '$baseFilter && deleted_for !~ "$myId"';
      
      List<RecordModel> records;
      try {
        records = await PocketBaseService.client.collection('messages').getFullList(
          filter: filter,
          sort: '-created',
        );
      } catch (e) {
        // deleted_for alanı yoksa yedek filtre ile çek
        if (e.toString().contains('400') || e.toString().contains('deleted_for')) {
          records = await PocketBaseService.client.collection('messages').getFullList(
            filter: baseFilter,
            sort: '-created',
          );
        } else {
          rethrow;
        }
      }
      
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

  Future<void> _removeFromFavorites(RecordModel message) async {
    try {
      await PocketBaseService.client.collection('messages').update(
        message.id,
        body: {'is_favorite': false},
      );
      if (mounted) {
        _fetchFavoriteMessages();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Favorilerden kaldırıldı.')),
        );
      }
    } catch (e) {
      AppLogger.instance.error('Favoriden kaldırılamadı: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.chatId != null 
        ? '${widget.chatName} - Favoriler' 
        : 'Favori Mesajlar';

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
          Semantics(
            label: _isSearching ? "Aramayı kapat" : "Favori mesajlarda ara",
            button: true,
            child: IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              tooltip: _isSearching ? "Aramayı Kapat" : "Ara",
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _searchController.clear();
                  }
                  _isSearching = !_isSearching;
                });
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredMessages.isEmpty
                ? Center(
                    child: Text(_isSearching 
                        ? 'Arama sonucu bulunamadı.' 
                        : 'Favoriye eklenmiş mesaj bulunamadı.'),
                  )
                : ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: _filteredMessages.length,
                    itemBuilder: (context, index) {
                      final message = _filteredMessages[index];
                      final content = ProfanityFilter.filter(message.getStringValue('content'));
                      final isVoice = content.startsWith('[VOICE]');
                      final isCall = content.contains('CALL_');
                      final createdAt = DateTime.parse(message.created).toLocal();
                      final timeStr = DateFormat('dd.MM.yyyy HH:mm').format(createdAt);
                      
                      return Semantics(
                        label: isVoice ? '[Sesli Mesaj]' : (isCall ? '[Sistem Mesajı]' : content),
                        button: true,
                        excludeSemantics: true,
                        customSemanticsActions: {
                          CustomSemanticsAction(label: 'Favorilerden Kaldır'): () => _removeFromFavorites(message),
                        },
                        child: Card(
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
                            onLongPress: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (context) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.delete, color: Colors.red),
                                      title: const Text('Favorilerden Kaldır'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _removeFromFavorites(message);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _removeFromFavorites(message),
                              tooltip: 'Favorilerden kaldır',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
