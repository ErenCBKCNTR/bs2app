import 'package:flutter/material.dart';
import 'package:blind_social/features/admin/data/services/admin_service.dart';
import 'package:blind_social/features/admin/presentation/screens/upload_quiz_questions_screen.dart';
import 'package:blind_social/features/admin/presentation/screens/manage_quiz_questions_screen.dart';

class QuizManagementScreen extends StatelessWidget {
  const QuizManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AdminService().isAdmin()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erişim Engellendi')),
        body: const Center(child: Text('Bu sayfayı görüntülemek için yetkiniz yok.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilgi Yarışması Yönetimi'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UploadQuizQuestionsScreen()),
                  );
                },
                icon: const Icon(Icons.upload_file, size: 32),
                label: const Text('Soru Yükle', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: const Color(0xFF075E54),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageQuizQuestionsScreen()),
                  );
                },
                icon: const Icon(Icons.list_alt, size: 32),
                label: const Text('Soruları Göster', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
