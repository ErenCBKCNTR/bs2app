import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  bool _isLoading = true;
  List<RecordModel> _incomingRequests = [];
  List<RecordModel> _outgoingRequests = [];
  List<RecordModel> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final currentUserId = PocketBaseService.client.authStore.model!.id;

      // Gelen istekler (to_user benim id olanlar)
      final incoming = await PocketBaseService.client.collection('friend_requests').getFullList(
        filter: 'to_user = "$currentUserId"',
        expand: 'from_user'
      );

      // Giden istekler (from_user benim id olanlar)
      final outgoing = await PocketBaseService.client.collection('friend_requests').getFullList(
        filter: 'from_user = "$currentUserId"',
        expand: 'to_user'
      );

      // Engellenen kullanıcılar (blocker = benim id olanlar)
      final blocks = await PocketBaseService.client.collection('user_blocks').getFullList(
        filter: 'blocker = "$currentUserId"',
        expand: 'blocked'
      );

      if (mounted) {
        setState(() {
          _incomingRequests = incoming;
          _outgoingRequests = outgoing;
          _blockedUsers = blocks;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.instance.error('Arkadaşlık istekleri yüklenirken hata: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptRequest(RecordModel request) async {
    try {
      final fromUserId = request.getStringValue('from_user');
      final toUserId = request.getStringValue('to_user');

      // Arkadaşlık oluştur
      await PocketBaseService.client.collection('friendships').create(body: {
        'user1': fromUserId,
        'user2': toUserId,
      });

      // İsteği sil
      await PocketBaseService.client.collection('friend_requests').delete(request.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arkadaşlık isteği kabul edildi.')),
        );
        _fetchRequests();
      }
    } catch (e) {
      AppLogger.instance.error('Arkadaşlık isteği kabul edilirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _rejectRequest(RecordModel request) async {
    try {
      await PocketBaseService.client.collection('friend_requests').delete(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arkadaşlık isteği reddedildi.')),
        );
        _fetchRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _unblockUser(RecordModel blockRecord) async {
    try {
      await PocketBaseService.client.collection('user_blocks').delete(blockRecord.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcının engeli kaldırıldı.')),
        );
        _fetchRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İstekler ve Engellenenler'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Gelen İstekler', _incomingRequests.length),
                  if (_incomingRequests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Gelen istek yok.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._incomingRequests.map((req) => _buildIncomingRequestItem(req)),

                  const Divider(height: 32),

                  _buildSectionHeader('Giden İstekler', _outgoingRequests.length),
                  if (_outgoingRequests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Giden istek yok.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._outgoingRequests.map((req) => _buildOutgoingRequestItem(req)),

                  const Divider(height: 32),

                  _buildSectionHeader('Engellenen Kullanıcılar', _blockedUsers.length),
                  if (_blockedUsers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Engellenen kullanıcı yok.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._blockedUsers.map((blk) => _buildBlockedUserItem(blk)),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        '$title ($count)',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildIncomingRequestItem(RecordModel request) {
    final fromUser = request.expand['from_user']?.first;
    if (fromUser == null) return const SizedBox.shrink();

    final username = fromUser.getStringValue('username');
    final fullName = fromUser.getStringValue('full_name');
    final displayName = username.isNotEmpty ? username : fullName;

    return Semantics(
      label: "$displayName'den gelen arkadaşlık isteği",
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?'),
        ),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('@$username'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Kabul et',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => _acceptRequest(request),
              ),
            ),
            Semantics(
              label: 'Reddet',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () => _rejectRequest(request),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutgoingRequestItem(RecordModel request) {
    final toUser = request.expand['to_user']?.first;
    if (toUser == null) return const SizedBox.shrink();

    final username = toUser.getStringValue('username');
    final fullName = toUser.getStringValue('full_name');
    final displayName = username.isNotEmpty ? username : fullName;

    return Semantics(
      label: "$displayName'ye gönderilen arkadaşlık isteği. İptal etmek için tıklayın.",
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?'),
        ),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('@$username'),
        trailing: Semantics(
          label: 'İsteği iptal et',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => _rejectRequest(request),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedUserItem(RecordModel blockRecord) {
    final blockedUser = blockRecord.expand['blocked']?.first;
    if (blockedUser == null) return const SizedBox.shrink();

    final username = blockedUser.getStringValue('username');
    final fullName = blockedUser.getStringValue('full_name');
    final displayName = username.isNotEmpty ? username : fullName;

    return Semantics(
      label: "Engellenen kullanıcı $displayName. Engeli kaldırmak için tıklayın.",
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?'),
        ),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('@$username'),
        trailing: Semantics(
          label: 'Engeli kaldır',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.lock_open, color: Colors.blue),
            onPressed: () => _unblockUser(blockRecord),
          ),
        ),
      ),
    );
  }
}
