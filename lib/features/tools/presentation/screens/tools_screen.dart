import 'package:flutter/material.dart';
import 'package:blind_social/features/task_board/presentation/screens/task_boards_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Araçlar'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.assignment_outlined, size: 40, color: Colors.blueAccent),
                title: const Text('Görev Panosu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: const Text('Kişisel ve ekip görevlerinizi organize edin, listeler oluşturun ve ilerlemenizi takip edin.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskBoardsScreen()));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
