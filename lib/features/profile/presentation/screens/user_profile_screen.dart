import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/localization_provider.dart';
import 'package:blind_social/core/localization/languages/language.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
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
    final lang = ref.read(localizationProvider);
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
        _errorMessage = "${lang.profileLoadError}: $e";
        _isLoading = false;
      });
    }
  }

  Widget _buildRemoveFriendButton() {
    final lang = ref.watch(localizationProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: _removeFriend,
        icon: const Icon(Icons.person_remove),
        label: Text(lang.removeFromFriends, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Future<void> _removeFriend() async {
    final lang = ref.read(localizationProvider);
    if (_friendshipRecordId == null) return;
    try {
      await PocketBaseService.client.collection('friendships').delete(_friendshipRecordId!);
      if (mounted) {
        setState(() {
          _friendshipStatus = 0;
          _friendshipRecordId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.removedFromFriends)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lang.error}: $e')),
        );
      }
    }
  }

  Widget _buildBlockButton() {
    final lang = ref.watch(localizationProvider);
    final labelText = _hasBlocked ? lang.unblockUserTooltip : lang.blockUser;
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
    final lang = ref.read(localizationProvider);
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
              SnackBar(content: Text(lang.userUnblocked)),
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
            SnackBar(content: Text(lang.userBlocked)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lang.operationFailed}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localizationProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.profileInfo),
      ),
      body: _buildBody(lang),
    );
  }

  Widget _buildBody(BaseLanguage lang) {
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
      return Center(child: Text(lang.userNotFound));
    }

    final currentUserId = PocketBaseService.client.authStore.model?.id;
    final username = _userProfile!.getStringValue('username');
    final displayName = ProfanityFilter.filter(username.isNotEmpty ? username : lang.unnamed);
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
    
    String formattedDob = lang.unspecified;
    if (!showBirthday) {
      formattedDob = lang.hidden;
    } else if (dobRaw.isNotEmpty) {
      try {
        final date = DateTime.parse(dobRaw);
        formattedDob = DateFormat('dd.MM.yyyy').format(date);
      } catch (_) {}
    }

    final createdAtRaw = _userProfile!.created;
    String formattedJoined = lang.unknown;
    if (createdAtRaw.isNotEmpty) {
      try {
        final date = DateTime.parse(createdAtRaw).toLocal();
        formattedJoined = DateFormat('dd.MM.yyyy').format(date);
      } catch (_) {}
    }

    final bio = _userProfile!.getStringValue('bio');
    final hasBio = bio.isNotEmpty;

    String statusText = lang.lastSeenUnknown;
    Color statusColor = Colors.grey;
    if (hideLastSeen) {
       statusText = lang.lastSeenHidden;
       statusColor = Colors.grey;
    } else if (isOnline) {
       statusText = lang.currentlyActive;
       statusColor = Colors.green;
    } else {
       final lastSeenRaw = _userProfile!.getStringValue('last_seen');
       final targetRaw = lastSeenRaw.isNotEmpty ? lastSeenRaw : _userProfile!.updated;
       if (targetRaw.isNotEmpty) {
           final lastSeenDate = DateTime.parse(targetRaw).toLocal();
           final now = DateTime.now();
           if (lastSeenDate.year == now.year && lastSeenDate.month == now.month && lastSeenDate.day == now.day) {
               statusText = "${lang.lastSeenToday} ${DateFormat('HH:mm').format(lastSeenDate)}";
           } else {
               statusText = "${lang.lastSeen} ${DateFormat('dd.MM.yyyy HH:mm').format(lastSeenDate)}";
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
                  label: "$displayName ${lang.userProfilePhoto}",
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
                  Text(lang.about, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
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
                Text(lang.details, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildCompactInfoCard(Icons.cake_outlined, lang.birthday, formattedDob)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCompactInfoCard(Icons.calendar_today_outlined, lang.joined, formattedJoined)),
                  ],
                ),
                const SizedBox(height: 32),
                if (!_isBlockedBy) _buildFriendButton(lang),
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

  Widget _buildFriendButton(BaseLanguage lang) {
    String labelText = lang.addAsFriend;
    IconData iconData = Icons.person_add;
    VoidCallback? onPressed = _sendFriendRequest;
    Color bgColor = Theme.of(context).colorScheme.primary;

    if (_friendshipStatus == 1) {
      labelText = lang.youAreFriends;
      iconData = Icons.people;
      onPressed = null;
      bgColor = Colors.grey.shade800;
    } else if (_friendshipStatus == 2) {
      labelText = lang.friendRequestSent;
      iconData = Icons.check;
      onPressed = null;
      bgColor = Colors.grey.shade800;
    } else if (_friendshipStatus == 3) {
      labelText = lang.wantsToAddYou;
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
    final lang = ref.read(localizationProvider);
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
          SnackBar(content: Text(lang.friendRequestSentSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lang.error}: $e')),
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
