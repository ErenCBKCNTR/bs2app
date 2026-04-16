import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', widget.userId)
          .single();

      setState(() {
        _userProfile = response;
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

    final username = _userProfile!['username'] ?? 'İsimsiz';
    final dobRaw = _userProfile!['dob'];
    
    String formattedDob = "Belirtilmemiş";
    if (dobRaw != null) {
      try {
        final date = DateTime.parse(dobRaw);
        formattedDob = DateFormat('dd.MM.yyyy').format(date);
      } catch (_) {}
    }

    final createdAtRaw = _userProfile!['created_at'];
    String formattedJoined = "Bilinmiyor";
    if (createdAtRaw != null) {
      try {
        final date = DateTime.parse(createdAtRaw);
        formattedJoined = DateFormat('dd.MM.yyyy').format(date);
      } catch (_) {}
    }

    return SingleChildScrollView(
      child: Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Semantics(
              label: "$username adlı kullanıcının profil fotoğrafı",
              child: Hero(
                tag: 'avatar_${widget.userId}',
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    username.toString().isNotEmpty ? username.toString().substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(fontSize: 48, color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              username,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Aktif Kullanıcı', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
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
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String value}) {
    return Semantics(
      label: "$title: $value",
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
    );
  }
}
