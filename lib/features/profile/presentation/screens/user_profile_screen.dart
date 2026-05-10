import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  RecordModel? _userProfile;
  String? _errorMessage;
  int _friendshipStatus = 0; // 0: None, 1: Friends, 2: Pending Outgoing, 3: Pending Incoming
  bool _hasBlocked = false;
  bool _isBlockedBy = false;
  String? _blockRecordId;
  String? _friendshipRecordId;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await PocketBaseService.client.collection('users').getOne(widget.userId);

      final currentUserId = PocketBaseService.client.authStore.model?.id;
      int status = 0;

      if (currentUserId != null && currentUserId != widget.userId) {
        // Check blocks first
        final blocksByMe = await PocketBaseService.client.collection('user_blocks').getFullList(
          filter: 'blocker = "$currentUserId" && blocked = "${widget.userId}"',
        );
        if (blocksByMe.isNotEmpty) {
          _hasBlocked = true;
          _blockRecordId = blocksByMe[0].id;
        }

        final blocksToMe = await PocketBaseService.client.collection('user_blocks').getFullList(
          filter: 'blocker = "${widget.userId}" && blocked = "$currentUserId"',
        );
        if (blocksToMe.isNotEmpty) {
          _isBlockedBy = true;
        }

        // Check friends
        final friends = await PocketBaseService.client.collection('friendships').getFullList(
          filter: '(user1 = "$currentUserId" && user2 = "${widget.userId}") || (user1 = "${widget.userId}" && user2 = "$currentUserId")',
        );
        if (friends.isNotEmpty) {
          status = 1;
          _friendshipRecordId = friends[0].id;
        } else {
          // Check requests
          final requests = await PocketBaseService.client.collection('friend_requests').getFullList(
            filter: '(from_user = "$currentUserId" && to_user = "${widget.userId}") || (from_user = "${widget.userId}" && to_user = "$currentUserId")',
          );
          if (requests.isNotEmpty) {
            final fromUser = requests[0].getStringValue('from_user');
            if (fromUser == currentUserId) {
              status = 2; // Pending Outgoing
            } else {
              status = 3; // Pending Incoming
            }
          }
        }
      }

      setState(() {
        _userProfile = response;
        _friendshipStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Profil yüklenemedi: $e";
        _isLoading = false;
      });
    }
  }

  Widget _buildRemoveFriendButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: _removeFriend,
        icon: const Icon(Icons.person_remove),
        label: const Text('Arkadaş Listemden Çıkar', style: TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Future<void> _removeFriend() async {
    if (_friendshipRecordId == null) return;
    try {
      await PocketBaseService.client.collection('friendships').delete(_friendshipRecordId!);
      if (mounted) {
        setState(() {
          _friendshipStatus = 0;
          _friendshipRecordId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arkadaşlıktan çıkarıldı.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e')),
        );
      }
    }
  }

  Widget _buildBlockButton() {
    final labelText = _hasBlocked ? 'Engellemeyi Kaldır' : 'Kullanıcıyı Engelle';
    final bgColor = _hasBlocked ? Colors.grey.shade600 : Colors.red.shade900;
    final iconData = _hasBlocked ? Icons.lock_open : Icons.block;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        label: labelText,
        button: true,
        child: ElevatedButton.icon(
          onPressed: _toggleBlock,
          icon: Icon(iconData),
          label: Text(labelText, style: const TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: bgColor,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _toggleBlock() async {
    final currentUserId = PocketBaseService.client.authStore.model!.id;
    try {
      if (_hasBlocked) {
        if (_blockRecordId != null) {
          await PocketBaseService.client.collection('user_blocks').delete(_blockRecordId!);
          if (mounted) {
            setState(() {
              _hasBlocked = false;
              _blockRecordId = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kullanıcının engeli kaldırıldı.')),
            );
          }
        }
      } else {
        // Engellemeden once eger arkadaslik varsa onu da sil
        if (_friendshipRecordId != null) {
          try {
            await PocketBaseService.client.collection('friendships').delete(_friendshipRecordId!);
          } catch (_) {}
        }
        final record = await PocketBaseService.client.collection('user_blocks').create(body: {
          'blocker': currentUserId,
          'blocked': widget.userId,
        });
        if (mounted) {
          setState(() {
            _hasBlocked = true;
            _blockRecordId = record.id;
            _friendshipStatus = 0; // Reset friendship status as well
            _friendshipRecordId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kullanıcı engellendi.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşlem başarısız: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Bilgileri'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (_userProfile == null) {
      return const Center(child: Text("Kullanıcı bulunamadı."));
    }

    final currentUserId = PocketBaseService.client.authStore.model?.id;
    final username = _userProfile!.getStringValue('username');
    final displayName = ProfanityFilter.filter(username.isNotEmpty ? username : 'İsimsiz');
    final dobRaw = _userProfile!.getStringValue('dob');
    final hideLastSeen = _userProfile!.getBoolValue('hide_last_seen');
    final fullName = _userProfile!.getStringValue('full_name');
    final isOnline = _userProfile!.getBoolValue('is_online');
    
    // Privacy Logic for Birthday
    // Handle both legacy (bool) and new (select) fields
    String birthdayPrivacy = 'everyone';
    if (_userProfile!.data.containsKey('birthday_privacy')) {
      birthdayPrivacy = _userProfile!.getStringValue('birthday_privacy');
      if (birthdayPrivacy.isEmpty) birthdayPrivacy = 'everyone';
    } else {
      birthdayPrivacy = _userProfile!.getBoolValue('hide_birthday') ? 'none' : 'everyone';
    }

    bool showBirthday = false;
    if (birthdayPrivacy == 'everyone') {
      showBirthday = true;
    } else if (birthdayPrivacy == 'friends' && _friendshipStatus == 1) {
      showBirthday = true;
    } else if (widget.userId == currentUserId) {
      showBirthday = true; // Always show own info
    }

    // Privacy Logic for Full Name
    String fullnamePrivacy = 'everyone';
    if (_userProfile!.data.containsKey('fullname_privacy')) {
      fullnamePrivacy = _userProfile!.getStringValue('fullname_privacy');
      if (fullnamePrivacy.isEmpty) fullnamePrivacy = 'everyone';
    } else {
      fullnamePrivacy = _userProfile!.getBoolValue('hide_full_name') ? 'none' : 'everyone';
    }

    bool showFullName = false;
    if (fullnamePrivacy == 'everyone') {
      showFullName = true;
    } else if (fullnamePrivacy == 'friends' && _friendshipStatus == 1) {
      showFullName = true;
    } else if (widget.userId == currentUserId) {
      showFullName = true; // Always show own info
    }
    
    String formattedDob = "Belirtilmemiş";
    if (!showBirthday) {
      formattedDob = "Gizli";
    } else if (dobRaw.isNotEmpty) {
      try {
        final date = DateTime.parse(dobRaw);
        formattedDob = DateFormat('dd.MM.yyyy').format(date);
      } catch (_) {}
    }

    final createdAtRaw = _userProfile!.created;
    String formattedJoined = "Bilinmiyor";
    if (createdAtRaw.isNotEmpty) {
      try {
        final date = DateTime.parse(createdAtRaw).toLocal();
        formattedJoined = DateFormat('dd.MM.yyyy').format(date);
      } catch (_) {}
    }

    final bio = _userProfile!.getStringValue('bio');
    final hasBio = bio.isNotEmpty;

    String statusText = "Son görülme bilinmiyor";
    Color statusColor = Colors.grey;
    if (hideLastSeen) {
       statusText = "Son görülme gizli";
       statusColor = Colors.grey;
    } else if (isOnline) {
       statusText = "Şu an aktif";
       statusColor = Colors.green;
    } else {
       final lastSeenRaw = _userProfile!.getStringValue('last_seen');
       final targetRaw = lastSeenRaw.isNotEmpty ? lastSeenRaw : _userProfile!.updated;
       if (targetRaw.isNotEmpty) {
           final lastSeenDate = DateTime.parse(targetRaw).toLocal();
           final now = DateTime.now();
           if (lastSeenDate.year == now.year && lastSeenDate.month == now.month && lastSeenDate.day == now.day) {
               statusText = "Son görülme bugün ${DateFormat('HH:mm').format(lastSeenDate)}";
           } else {
               statusText = "Son görülme ${DateFormat('dd.MM.yyyy HH:mm').format(lastSeenDate)}";
           }
       }
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Semantics(
                  label: "$displayName adlı kullanıcının profil fotoğrafı",
                  child: Hero(
                    tag: 'avatar_${widget.userId}',
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: username.isNotEmpty 
                        ? Text(
                            username[0].toUpperCase(),
                            style: const TextStyle(fontSize: 48, color: Colors.black, fontWeight: FontWeight.bold),
                          )
                        : const Icon(Icons.person, size: 48, color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  displayName,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                if (showFullName && fullName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      ProfanityFilter.filter(fullName),
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 12),
                Semantics(
                  label: statusText,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasBio) ...[
                  const Text('Hakkında', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(ProfanityFilter.filter(bio), style: const TextStyle(fontSize: 16, height: 1.4)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text('Detaylar', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildCompactInfoCard(Icons.cake_outlined, "Doğum Günü", formattedDob)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCompactInfoCard(Icons.calendar_today_outlined, "Katılım", formattedJoined)),
                  ],
                ),
                const SizedBox(height: 32),
                if (!_isBlockedBy) _buildFriendButton(),
                if (_friendshipStatus == 1 && !_isBlockedBy) const SizedBox(height: 12),
                if (_friendshipStatus == 1 && !_isBlockedBy) _buildRemoveFriendButton(),
                if (currentUserId != widget.userId) const SizedBox(height: 12),
                if (currentUserId != widget.userId) _buildBlockButton(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendButton() {
    String labelText = 'Arkadaş Olarak Ekle';
    IconData iconData = Icons.person_add;
    VoidCallback? onPressed = _sendFriendRequest;
    Color bgColor = Theme.of(context).colorScheme.primary;

    if (_friendshipStatus == 1) {
      labelText = 'Arkadaşsınız';
      iconData = Icons.people;
      onPressed = null;
      bgColor = Colors.grey.shade800;
    } else if (_friendshipStatus == 2) {
      labelText = 'Arkadaşlık İsteği Gönderildi';
      iconData = Icons.check;
      onPressed = null;
      bgColor = Colors.grey.shade800;
    } else if (_friendshipStatus == 3) {
      labelText = 'Sizi Eklemek İstiyor';
      iconData = Icons.person_add_alt_1;
      onPressed = null;
      bgColor = Colors.grey.shade800;
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(iconData),
      label: Text(labelText, style: const TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        disabledBackgroundColor: bgColor,
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        backgroundColor: bgColor,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _sendFriendRequest() async {
    try {
      final currentUserId = PocketBaseService.client.authStore.model!.id;
      await PocketBaseService.client.collection('friend_requests').create(body: {
        'from_user': currentUserId,
        'to_user': widget.userId,
      });

      if (mounted) {
        setState(() {
          _friendshipStatus = 2;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arkadaşlık isteği gönderildi!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e')),
        );
      }
    }
  }

  Widget _buildCompactInfoCard(IconData icon, String title, String value) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
