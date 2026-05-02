import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/features/servers/data/models/chat_server.dart';
import 'package:blind_social/features/servers/data/models/chat_server_room.dart';
import 'package:blind_social/features/servers/data/services/chat_server_service.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'package:pocketbase/pocketbase.dart';

class ServerSettingsScreen extends StatefulWidget {
  final ChatServer server;
  const ServerSettingsScreen({super.key, required this.server});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _passwordController;
  
  late int _capacity;

  bool _isSaving = false;
  List<RecordModel> _members = [];
  bool _isLoadingMembers = true;
  List<RecordModel> _bans = [];
  bool _isLoadingBans = true;
  bool _canMembersCreateRooms = false;
  List<ChatServerRoom> _rooms = [];
  bool _isLoadingRooms = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _nameController = TextEditingController(text: widget.server.name);
    _descController = TextEditingController(text: widget.server.description);
    _passwordController = TextEditingController(text: widget.server.password ?? '');
    _capacity = widget.server.capacity;
    _canMembersCreateRooms = widget.server.canMembersCreateRooms;
    _fetchMembers();
    _fetchBans();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    try {
      final rooms = await ChatServerService().getRooms(widget.server.id);
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _isLoadingRooms = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRooms = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    try {
      final members = await ChatServerService().getServerMembers(widget.server.id);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  Future<void> _fetchBans() async {
    try {
      final bans = await ChatServerService().getServerBans(widget.server.id);
      if (mounted) {
        setState(() {
          _bans = bans;
          _isLoadingBans = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBans = false);
      }
    }
  }

  Future<void> _updateServer() async {
    setState(() => _isSaving = true);
    
    // Doğrulama
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length < 3) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sunucu adı en az 3 karakter olmalıdır.')));
      return;
    }

    try {
      await ChatServerService().updateServer(
        serverId: widget.server.id,
        name: name,
        description: _descController.text.trim(),
        capacity: _capacity, // Direkt integer değişkenini kullanıyoruz, dropdowndan besleniyor.
        canMembersCreateRooms: _canMembersCreateRooms,
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sunucu başarıyla güncellendi!')));
        Navigator.pop(context, true); // True means updated
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sunucu güncellenemedi: $e')));
      }
    }
  }

  Future<void> _confirmDeleteServer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sunucuyu Sil'),
        content: const Text('Sunucuyu tamamen silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Evet, Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        await ChatServerService().deleteServer(widget.server.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sunucu silindi.')));
          // Navigate to home / root, which triggers refreshing of servers
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silinirken hata: $e')));
        }
      }
    }
  }

  Future<void> _kickMember(RecordModel membership) async {
    final user = membership.expand['user_id']?[0];
    if (user == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üyeyi Uzaklaştır'),
        content: Text('${user.getStringValue('username')} bu sunucudan uzaklaştırılsın mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Uzaklaştır', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChatServerService().removeMember(widget.server.id, user.id);
        _fetchMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Üye uzaklaştırıldı')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    }
  }

  Future<void> _banMember(RecordModel membership) async {
    final user = membership.expand['user_id']?[0];
    if (user == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üyeyi Yasakla (Banla)'),
        content: Text('${user.getStringValue('username')} adlı kullanıcı sunucudan kalıcı olarak yasaklansın mı? Bir daha giriş yapamayacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yasakla', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChatServerService().banMember(widget.server.id, user.id);
        _fetchMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Üye başarıyla yasaklandı.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    }
  }

  Future<void> _unbanMember(RecordModel ban) async {
    final user = ban.expand['user_id']?[0];
    if (user == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yasaklamayı Kaldır'),
        content: Text('${user.getStringValue('username')} adlı kullanıcının yasağı kaldırılsın mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yasağı Kaldır')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChatServerService().unbanMember(widget.server.id, user.id);
        _fetchBans();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcının yasağı kaldırıldı.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sunucu Ayarları'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'Genel'),
            Tab(icon: Icon(Icons.meeting_room), text: 'Odalar'),
            Tab(icon: Icon(Icons.people), text: 'Üyeler'),
            Tab(icon: Icon(Icons.block), text: 'Yasaklılar'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildGeneralSettingsTab(),
            _buildRoomsTab(),
            _buildMembersTab(),
            _buildBansTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Temel Bilgiler',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Sunucu Adı',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.dns),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _capacity,
                    decoration: const InputDecoration(
                      labelText: 'Kişi Kapasitesi',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.groups),
                    ),
                    items: [12, 24, 32, 48, 64, 128].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value Kişilik'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _capacity = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text(
                        'Güvenlik ve Yetkiler',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    title: const Text('Üyeler Oda Açabilsin', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Bu özellik kapalıyken sadece kurucu oda açabilir.'),
                    contentPadding: EdgeInsets.zero,
                    activeColor: Theme.of(context).colorScheme.primary,
                    value: _canMembersCreateRooms,
                    onChanged: (val) => setState(() => _canMembersCreateRooms = val),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sunucu Şifresi (Sadece Rakam)',
                      hintText: 'Şifresiz olması için boş bırakın',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isSaving ? null : _updateServer,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: _isSaving 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Text('Değişiklikleri Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          if (ChatServerService().currentUserId == widget.server.creatorId)
            ElevatedButton(
              onPressed: _isSaving ? null : _confirmDeleteServer,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sunucuyu Sil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _deleteRoom(ChatServerRoom room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odayı Sil'),
        content: Text('${room.name} odasını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChatServerService().deleteRoom(room.id);
        _fetchRooms();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oda silindi')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    }
  }

  Widget _buildRoomsTab() {
    if (_isLoadingRooms) return const Center(child: CircularProgressIndicator());
    if (_rooms.isEmpty) return const Center(child: Text('Oda bulunamadı.'));

    final imCreator = ChatServerService().currentUserId == widget.server.creatorId;

    return Semantics(
      label: imCreator ? 'Odalar sekmesi. Odaları silmek için ilgili odanın üzerindeyken işlemler menüsünden odayı sil seçeneğini kullanabilirsiniz (tek parmakla yukarı ve aşağı kaydırarak).' : 'Odalar sekmesi',
      child: ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
        itemCount: _rooms.length,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          return Semantics(
            customSemanticsActions: {
              if (imCreator)
                CustomSemanticsAction(label: 'Odayı sil'): () {
                  _deleteRoom(room);
                },
            },
            child: ListTile(
              leading: Icon(room.type.name == 'audio' ? Icons.headset_mic : Icons.tag),
              title: Text(room.name),
              subtitle: Text(room.description.isNotEmpty ? room.description : 'Açıklama yok'),
              trailing: imCreator
                ? ExcludeSemantics(
                    child: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteRoom(room),
                    ),
                  )
                : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMembersTab() {
    if (_isLoadingMembers) return const Center(child: CircularProgressIndicator());
    if (_members.isEmpty) return const Center(child: Text('Üye bulunamadı.'));

    return ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final membership = _members[index];
        final user = membership.expand['user_id']?[0];
        if (user == null) return const SizedBox.shrink();

        final userName = ProfanityFilter.filter(user.getStringValue('username'));
        final isCreator = user.id == widget.server.creatorId;
        final isAdmin = widget.server.admins.contains(user.id);
        final isMe = user.id == ChatServerService().currentUserId;
        final imCreator = ChatServerService().currentUserId == widget.server.creatorId;
        final imAdmin = widget.server.admins.contains(ChatServerService().currentUserId);

        return Semantics(
          customSemanticsActions: {
            if (!isCreator && !isMe && (imCreator || imAdmin))
              CustomSemanticsAction(label: 'Sunucudan At'): () {
                _kickMember(membership);
              },
            if (!isCreator && !isMe && imCreator)
              CustomSemanticsAction(label: 'Kullanıcıyı Yasakla'): () {
                _banMember(membership);
              },
          },
          child: ListTile(
            leading: ExcludeSemantics(
            child: CircleAvatar(
              child: Text(userName.isEmpty ? '?' : userName[0].toUpperCase()),
            ),
          ),
          title: Row(
            children: [
              Text(userName.isEmpty ? 'İsimsiz' : userName),
              if (isCreator) 
                const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.star, color: Colors.amber, size: 16)),
              if (isAdmin && !isCreator)
                const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.shield, color: Colors.blue, size: 16)),
              if (isMe)
                const Padding(padding: EdgeInsets.only(left: 8), child: Text('(Sen)', style: TextStyle(fontSize: 12, color: Colors.grey))),
            ],
          ),
          subtitle: Text(isCreator ? 'Kurucu' : (isAdmin ? 'Yönetici' : 'Üye')),
          trailing: (!isCreator && !isMe && (imCreator || imAdmin)) 
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'kick') {
                    _kickMember(membership);
                  } else if (value == 'ban') {
                    if (imCreator) {
                      _banMember(membership);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yalnızca sunucu sahibi yasaklama işlemi yapabilir.')));
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'kick',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text('Sunucudan At'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'ban',
                    child: Row(
                      children: [
                        Icon(Icons.block, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Yasakla (Ban)'),
                      ],
                    ),
                  ),
                ],
              )
            : null,
          ),
        );
      },
    );
  }

  Widget _buildBansTab() {
    if (_isLoadingBans) return const Center(child: CircularProgressIndicator());
    if (_bans.isEmpty) return const Center(child: Text('Yasaklı üye bulunamadı.'));

    final imCreator = ChatServerService().currentUserId == widget.server.creatorId;

    return ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
      itemCount: _bans.length,
      itemBuilder: (context, index) {
        final ban = _bans[index];
        final user = ban.expand['user_id']?[0];
        if (user == null) return const SizedBox.shrink();

        final userName = ProfanityFilter.filter(user.getStringValue('username'));

        return Semantics(
          customSemanticsActions: {
            if (imCreator)
              CustomSemanticsAction(label: 'Yasak listesinden çıkar'): () {
                _unbanMember(ban);
              },
          },
          child: ListTile(
            leading: ExcludeSemantics(
              child: CircleAvatar(
                backgroundColor: Colors.red.shade100,
                child: Text(userName.isEmpty ? '?' : userName[0].toUpperCase(), style: TextStyle(color: Colors.red.shade900)),
              ),
            ),
            title: Text(userName.isEmpty ? 'İsimsiz' : userName),
            trailing: imCreator 
              ? IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => _unbanMember(ban),
                  tooltip: 'Yasak listesinden çıkar',
                )
              : null,
          ),
        );
      },
    );
  }
}
