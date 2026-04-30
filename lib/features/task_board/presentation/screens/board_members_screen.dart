import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/features/task_board/data/models/task_board.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';

class BoardMembersScreen extends StatefulWidget {
  final TaskBoard board;
  final TaskBoardService service;

  const BoardMembersScreen({Key? key, required this.board, required this.service}) : super(key: key);

  @override
  State<BoardMembersScreen> createState() => _BoardMembersScreenState();
}

class _BoardMembersScreenState extends State<BoardMembersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLoading = true;
  TaskBoard? _board;
  List<Map<String, dynamic>> _members = [];
  Map<String, dynamic>? _ownerData;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _board = widget.board;
    _currentUserId = PocketBaseService.client.authStore.model?.id ?? '';
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);
    try {
      final updatedRecord = await PocketBaseService.client.collection('task_boards').getOne(_board!.id);
      _board = TaskBoard.fromRecord(updatedRecord);

      final membersList = <Map<String, dynamic>>[];
      
      final ownerRecord = await PocketBaseService.client.collection('_pb_users_auth_').getOne(_board!.ownerId);
      _ownerData = ownerRecord.toJson();

      for (var mId in _board!.members) {
        if (mId == _board!.ownerId) continue; // safety check
        try {
          final mRec = await PocketBaseService.client.collection('_pb_users_auth_').getOne(mId);
          membersList.add(mRec.toJson());
        } catch (e) {
          // Ignore
        }
      }

      setState(() {
        _members = membersList;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleEditPermission(String memberId) async {
    try {
      List<String> editors = List.from(_board!.editors);
      bool isEditor = editors.contains(memberId);
      if (isEditor) {
        editors.remove(memberId);
      } else {
        editors.add(memberId);
      }
      
      final updatedRecord = await PocketBaseService.client.collection('task_boards').update(_board!.id, body: {
        'editors': editors
      });
      setState(() {
        _board = TaskBoard.fromRecord(updatedRecord);
      });
      SemanticsService.announce(isEditor ? "Kullanıcının düzenleme yetkisi alındı" : "Kullanıcıya düzenleme yetkisi verildi", TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yetki değiştirilemedi: $e')));
    }
  }

  Future<void> _removeMember(String memberId, String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üyeyi Çıkar'),
        content: Text('$memberName isimli üyeyi panodan çıkarmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hayır')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );

    if (confirmed == true) {
      try {
        List<String> newMembers = List.from(_board!.members)..remove(memberId);
        List<String> newEditors = List.from(_board!.editors)..remove(memberId);
        final updatedRecord = await PocketBaseService.client.collection('task_boards').update(_board!.id, body: {
          'members': newMembers,
          'editors': newEditors,
        });
        setState(() {
          _board = TaskBoard.fromRecord(updatedRecord);
          _members.removeWhere((m) => m['id'] == memberId);
        });
        SemanticsService.announce("$memberName isimli üye panodan çıkarıldı", TextDirection.ltr);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Üye çıkarılamadı: $e')));
      }
    }
  }

  Future<void> _askToggleEditPermission(String memberId, String memberName, bool isEditor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yetki Düzenle'),
        content: Text(isEditor ? '$memberName isimli kullanıcının düzenleme yetkisini almak istiyor musunuz?' : '$memberName isimli kullanıcıya düzenleme yetkisi vermek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hayır')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet'),
          )
        ],
      )
    );
    if (confirmed == true) {
      _toggleEditPermission(memberId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = _currentUserId == _board?.ownerId;
    final query = _searchCtrl.text.toLowerCase();
    
    final filteredMembers = _members.where((m) {
      final uname = (m['username'] as String? ?? '').toLowerCase();
      final fname = (m['full_name'] as String? ?? '').toLowerCase();
      final email = (m['email'] as String? ?? '').toLowerCase();
      return uname.contains(query) || fname.contains(query) || email.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Focus(
          autofocus: true,
          child: const Text('Panoya Bağlı Kullanıcılar'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'E-posta veya kullanıcı adı ara',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (_isLoading) const Expanded(child: Center(child: CircularProgressIndicator()))
            else Expanded(
              child: ListView(
                children: [
                  if (_ownerData != null)
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(_ownerData!['full_name']?.toString().isNotEmpty == true ? _ownerData!['full_name'] : _ownerData!['username']),
                        subtitle: const Text('Pano Sahibi', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Kullanıcılar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  if (filteredMembers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Başka üye bulunamadı.'),
                    ),
                  ...filteredMembers.map((m) {
                    final memberId = m['id'];
                    final mName = m['full_name']?.toString().isNotEmpty == true ? m['full_name'] : m['username'];
                    final isEditor = _board!.editors.contains(memberId);
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Semantics(
                        label: '$mName. Yetkisi: ${isEditor ? "Panoyu Düzenleyebilir" : "Sadece Görüntüleyebilir"}. Yönetici seçenekleri için parmağınızı yukarı ya da aşağı kaydırın.',
                        button: true,
                        customSemanticsActions: {
                          if (isOwner) CustomSemanticsAction(label: isEditor ? 'Düzenleme Yetkisini Al' : 'Düzenleme Yetkisi Ver'): () => _askToggleEditPermission(memberId, mName, isEditor),
                          if (isOwner) const CustomSemanticsAction(label: 'Kullanıcıyı Panodan Çıkar'): () => _removeMember(memberId, mName),
                        },
                        child: ExcludeSemantics(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(mName),
                            subtitle: Text(isEditor ? "Panoyu Düzenleyebilir" : "Sadece Görüntüleyebilir"),
                            trailing: isOwner ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Yetkiyi Düzenle',
                                  onPressed: () => _askToggleEditPermission(memberId, mName, isEditor),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Üyeyi Çıkar',
                                  onPressed: () => _removeMember(memberId, mName),
                                )
                              ],
                            ) : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
