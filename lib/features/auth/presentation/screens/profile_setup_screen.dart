import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:blind_social/features/update/presentation/screens/update_check_wrapper.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _dobController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Mevcut kullanıcı adını otomatik doldur (PB tarafından rastgele oluşturulmuş olsa bile)
    final user = PocketBaseService.client.authStore.model;
    if (user != null) {
      String currentFullName = user.getStringValue('full_name');
      String currentUsername = user.getStringValue('username');
      String email = user.getStringValue('email');
      
      if (currentFullName.isNotEmpty) {
        _fullNameController.text = currentFullName;
      }
      
      // Eğer username PocketBase'in atadığı otomatik "users..." şeklindeyse, 
      // ve elimizde e-posta adresi varsa, e-postanın ilk kısmını alıp username olarak gösterelim.
      if (currentUsername.startsWith('users') && email.isNotEmpty) {
        // erencs87@gmail.com -> erencs87
        _usernameController.text = email.split('@').first;
      } else {
        _usernameController.text = currentUsername;
      }
    }
  }

  Future<void> _saveProfile() async {
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    String dob = _dobController.text.trim();

    if (fullName.isEmpty || username.isEmpty || dob.isEmpty) {
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
      final user = PocketBaseService.client.authStore.model;
      if (user == null || !PocketBaseService.client.authStore.isValid) {
        throw Exception('Kullanıcı bulunamadı');
      }

      // Tarihi veritabanı formatına çevir (YYYY-MM-DD)
      final parts = dob.split('/');
      final formattedDate = '${parts[2]}-${parts[1]}-${parts[0]} 12:00:00Z'; // Timezone eklendi PB Date nesnesi için

      await PocketBaseService.client.collection('users').update(user.id, body: {
        'full_name': fullName,
        'username': username,
        'dob': formattedDate,
      });

      // PocketBase modelini yenilemek için token güncelliyoruz
      await PocketBaseService.client.collection('users').authRefresh();

      // İşlem başarılı olunca AuthWrapper'a geri dönüyoruz.
      // AuthWrapper yeni durumu algılayıp ChatListScreen'e yönlendirecek.
      if (mounted) {
        // Redundant navigation can cause loops, but here we want to reset the home screen
        // Instead of pushAndRemoveUntil, we can try to just pop if we came from somewhere,
        // but AuthWrapper uses state, so just updating PB model might be enough.
        // However, pushAndRemoveUntil ensures a clean slate.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const UpdateCheckWrapper(child: AuthWrapper())),
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
            Semantics(
              label: 'Kör Sosyal Ağına Hoş Geldiniz. Lütfen profil bilgilerinizi tamamlayın.',
              child: const Text(
                'Kayıt İşlemini Tamamlayın',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Semantics(
              label: 'İsim ve Soyisminizi giriniz.',
              child: TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'İsim Soyisim',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Kendinize boşluksuz ve en az 3 karakterden oluşan bir kullanıcı adı belirleyin.',
              child: TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Doğum tarihinizi gün, ay ve yıl olarak bitişik şekilde giriniz veya araya eğik çizgi ekleyiniz. Örneğin 15081995.',
              child: TextFormField(
                controller: _dobController,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Doğum Tarihi (GG/AA/YYYY)',
                  hintText: 'Örn: 15/08/1995 veya 15081995',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _saveProfile(),
              ),
            ),
            const SizedBox(height: 32),
            Semantics(
              label: 'Kaydet ve Başla. Profil bilgilerinizi kaydederek uygulamayı kullanmaya başlayın.',
              button: true,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Kaydet ve Başla'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
