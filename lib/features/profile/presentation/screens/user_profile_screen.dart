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
        // Check friends
        final friends = await PocketBaseService.client.collection('friendships').getFullList(
          filter: '(user1 = "$currentUserId" && user2 = "${widget.userId}") || (user1 = "${widget.userId}" && user2 = "$currentUserId")',
        );
        if (friends.isNotEmpty) {
          status = 1;
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

    final username = _userProfile!.getStringValue('username');
    final displayName = ProfanityFilter.filter(username.isNotEmpty ? username : 'İsimsiz');
    final dobRaw = _userProfile!.getStringValue('dob');
    final hideBirthday = _userProfile!.getBoolValue('hide_birthday');
    final hideLastSeen = _userProfile!.getBoolValue('hide_last_seen');
    final isOnline = _userProfile!.getBoolValue('is_online');
    
    String formattedDob = "Belirtilmemiş";
    if (hideBirthday) {
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
      child: Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Semantics(
              label: "$displayName adlı kullanıcının profil fotoğrafı",
              child: Hero(
                tag: 'avatar_${widget.userId}',
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(fontSize: 48, color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              displayName,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: statusText,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 40),
            _buildInfoCard(
              icon: Icons.cake,
              title: "Doğum Tarihi",
              value: formattedDob,
            ),
            _buildInfoCard(
              icon: Icons.calendar_today,
              title: "Katılma Tarihi",
              value: formattedJoined,
            ),
            const SizedBox(height: 40),
            _buildFriendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendButton() {
    final currentUserId = PocketBaseService.client.authStore.model?.id;
    if (currentUserId == null || currentUserId == widget.userId) {
      return const SizedBox.shrink();
    }
    
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(iconData),
        label: Text(labelText, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: bgColor,
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          backgroundColor: bgColor,
          foregroundColor: Colors.black,
        ),
      ),
    );
  }

  Future<void> _sendFriendRequest() async {
    try {
      final currentUserId = PocketBaseService.client.authStore.model!.id;
      
      // İstek oluştur
      await PocketBaseService.client.collection('friend_requests').create(body: {
        'from_user': currentUserId,
        'to_user': widget.userId,
      });

      if (mounted) {
        setState(() {
          _friendshipStatus = 2; // Yolladik
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

  Widget _buildInfoCard({required IconData icon, required String title, required String value}) {
    return Semantics(
      label: "$title. $value",
      child: ExcludeSemantics(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          child: ListTile(
            leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            subtitle: Text(value, style: const TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
