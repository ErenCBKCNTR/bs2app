import 'package:flutter/material.dart';
import 'package:blind_social/features/servers/data/models/chat_server.dart';
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
  bool _canMembersCreateRooms = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController = TextEditingController(text: widget.server.name);
    _descController = TextEditingController(text: widget.server.description);
    _passwordController = TextEditingController(text: widget.server.password ?? '');
    _capacity = widget.server.capacity;
    _canMembersCreateRooms = widget.server.canMembersCreateRooms;
    _fetchMembers();
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

  Future<void> _kickMember(RecordModel membership) async {
    final user = membership.expand['user_id']?[0];
    if (user == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üyeyi Uzaklaştır'),
        content: Text('${user.getStringValue('name')} bu sunucudan uzaklaştırılsın mı?'),
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Üye uzaklaştırıldı.')));
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
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'Genel'),
            Tab(icon: Icon(Icons.people), text: 'Üyeler'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildGeneralSettingsTab(),
            _buildMembersTab(),
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
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    if (_isLoadingMembers) return const Center(child: CircularProgressIndicator());
    if (_members.isEmpty) return const Center(child: Text('Üye bulunamadı.'));

    return ListView.builder(
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final membership = _members[index];
        final user = membership.expand['user_id']?[0];
        if (user == null) return const SizedBox.shrink();

        final userName = ProfanityFilter.filter(user.getStringValue('name'));
        final isCreator = user.id == widget.server.creatorId;
        final isAdmin = widget.server.admins.contains(user.id);
        final isMe = user.id == ChatServerService().currentUserId;

        return ListTile(
          leading: ExcludeSemantics(
            child: CircleAvatar(
              child: Text(userName.isEmpty ? '?' : userName[0].toUpperCase()),
            ),
          ),
          title: Row(
            children: [
              Text(userName),
              if (isCreator) 
                const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.star, color: Colors.amber, size: 16)),
              if (isAdmin && !isCreator)
                const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.shield, color: Colors.blue, size: 16)),
              if (isMe)
                const Padding(padding: EdgeInsets.only(left: 8), child: Text('(Sen)', style: TextStyle(fontSize: 12, color: Colors.grey))),
            ],
          ),
          subtitle: Text(isCreator ? 'Kurucu' : (isAdmin ? 'Yönetici' : 'Üye')),
          trailing: (!isCreator && !isMe) 
            ? IconButton(
                icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                onPressed: () => _kickMember(membership),
                tooltip: 'Sunucudan At',
              )
            : null,
        );
      },
    );
  }
}
