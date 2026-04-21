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
  late TextEditingController _capacityController;
  
  bool _isSaving = false;
  List<RecordModel> _members = [];
  bool _isLoadingMembers = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController = TextEditingController(text: widget.server.name);
    _descController = TextEditingController(text: widget.server.description);
    _capacityController = TextEditingController(text: widget.server.capacity.toString());
    _fetchMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _capacityController.dispose();
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
    try {
      await ChatServerService().updateServer(
        serverId: widget.server.id,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        capacity: int.tryParse(_capacityController.text.trim()),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sunucu güncellendi.')));
        Navigator.pop(context, true); // True means updated
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
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
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Sunucu Adı', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Açıklama', border: OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _capacityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Kişi Kapasitesi', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _updateServer,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: _isSaving ? const CircularProgressIndicator() : const Text('Değişiklikleri Kaydet'),
          ),
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
          leading: CircleAvatar(
            child: Text(userName.isEmpty ? '?' : userName[0].toUpperCase()),
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
