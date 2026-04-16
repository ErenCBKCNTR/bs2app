import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:blind_social/features/auth/presentation/screens/auth_wrapper.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _usernameController = TextEditingController();
  final _dobController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveProfile() async {
    final username = _usernameController.text.trim();
    String dob = _dobController.text.trim();

    if (username.isEmpty || dob.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun.')),
      );
      return;
    }

    // Eğer kullanıcı araya eğik çizgi koymadan 8 rakam girdiyse (örn: 16071996), biz aralara çizgi ekleyelim.
    if (dob.length == 8 && !dob.contains('/')) {
      dob = '${dob.substring(0, 2)}/${dob.substring(2, 4)}/${dob.substring(4, 8)}';
      _dobController.text = dob; // Ekranda da düzeltilmiş halini gösterelim
    }

    // Basit tarih formatı kontrolü (GG/AA/YYYY)
    final dateRegExp = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!dateRegExp.hasMatch(dob)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tarihi GG/AA/YYYY formatında girin (Örn: 15/08/1995 veya 15081995).')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Kullanıcı bulunamadı');

      // Tarihi veritabanı formatına çevir (YYYY-MM-DD)
      final parts = dob.split('/');
      final formattedDate = '${parts[2]}-${parts[1]}-${parts[0]}';

      await Supabase.instance.client.from('users').upsert({
        'id': user.id,
        'username': username,
        'dob': formattedDate,
        'created_at': DateTime.now().toIso8601String(),
      });

      // İşlem başarılı olunca AuthWrapper'a geri dönüyoruz.
      // AuthWrapper yeni durumu algılayıp ChatListScreen'e yönlendirecek.
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil kaydedilirken hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili Tamamla'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Kayıt İşlemini Tamamlayın',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Kullanıcı Adı',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dobController,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: 'Doğum Tarihi (GG/AA/YYYY)',
                hintText: 'Örn: 15/08/1995',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _saveProfile(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Kaydet ve Başla'),
            ),
          ],
        ),
      ),
    );
  }
}
