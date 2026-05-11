import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/localization_provider.dart';

class FriendRequestsScreen extends ConsumerStatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  ConsumerState<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends ConsumerState<FriendRequestsScreen> {
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
    final lang = ref.read(localizationProvider);
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
          SnackBar(content: Text(lang.friendRequestAccepted)),
        );
        _fetchRequests();
      }
    } catch (e) {
      AppLogger.instance.error('Arkadaşlık isteği kabul edilirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lang.error}: $e')),
        );
      }
    }
  }

  Future<void> _rejectRequest(RecordModel request) async {
    final lang = ref.read(localizationProvider);
    try {
      await PocketBaseService.client.collection('friend_requests').delete(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.friendRequestRejected)),
        );
        _fetchRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lang.error}: $e')),
        );
      }
    }
  }

  Future<void> _unblockUser(RecordModel blockRecord) async {
    final lang = ref.read(localizationProvider);
    try {
      await PocketBaseService.client.collection('user_blocks').delete(blockRecord.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.userUnblocked)),
        );
        _fetchRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lang.error}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localizationProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.friendRequestsAndBlocks),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(lang.incomingRequestsHeader, _incomingRequests.length),
                  if (_incomingRequests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(lang.noIncomingRequests, style: const TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._incomingRequests.map((req) => _buildIncomingRequestItem(req)),

                  const Divider(height: 32),

                  _buildSectionHeader(lang.outgoingRequestsHeader, _outgoingRequests.length),
                  if (_outgoingRequests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(lang.noOutgoingRequests, style: const TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._outgoingRequests.map((req) => _buildOutgoingRequestItem(req)),

                  const Divider(height: 32),

                  _buildSectionHeader(lang.blockedUsersHeader, _blockedUsers.length),
                  if (_blockedUsers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(lang.noBlockedUsers, style: const TextStyle(color: Colors.grey)),
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
    final lang = ref.watch(localizationProvider);
    final fromUser = request.expand['from_user']?.first;
    if (fromUser == null) return const SizedBox.shrink();

    final username = fromUser.getStringValue('username');
    final displayName = username.isNotEmpty ? username : lang.unnamed;

    return Semantics(
      label: "$displayName ${lang.friendRequestFrom}",
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: username.isNotEmpty 
            ? Text(username[0].toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold))
            : Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('@$username'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _acceptRequest(request),
              tooltip: lang.markAsCompleted, // Using markAsCompleted as "Accept" placeholder if not specific, or I should add it
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => _rejectRequest(request),
              tooltip: lang.no,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutgoingRequestItem(RecordModel request) {
    final lang = ref.watch(localizationProvider);
    final toUser = request.expand['to_user']?.first;
    if (toUser == null) return const SizedBox.shrink();

    final username = toUser.getStringValue('username');
    final displayName = username.isNotEmpty ? username : lang.unnamed;

    return Semantics(
      label: "$displayName ${lang.friendRequestTo}",
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: username.isNotEmpty 
            ? Text(username[0].toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold))
            : Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('@$username'),
        trailing: IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: () => _rejectRequest(request),
          tooltip: lang.cancelOutgoingRequest,
        ),
      ),
    );
  }

  Widget _buildBlockedUserItem(RecordModel blockRecord) {
    final lang = ref.watch(localizationProvider);
    final blockedUser = blockRecord.expand['blocked']?.first;
    if (blockedUser == null) return const SizedBox.shrink();

    final username = blockedUser.getStringValue('username');
    final displayName = username.isNotEmpty ? username : lang.unnamed;

    return Semantics(
      label: displayName + " " + lang.blockedUserInfo,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: username.isNotEmpty 
            ? Text(username[0].toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold))
            : Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('@$username'),
        trailing: IconButton(
          icon: const Icon(Icons.lock_open, color: Colors.blue),
          onPressed: () => _unblockUser(blockRecord),
          tooltip: lang.unblockUserTooltip,
        ),
      ),
    );
  }
}
