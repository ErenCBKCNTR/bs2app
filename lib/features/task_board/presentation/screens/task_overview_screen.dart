import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/features/task_board/data/models/task_item.dart';
import 'package:pocketbase/pocketbase.dart';

class TaskOverviewScreen extends StatefulWidget {
  const TaskOverviewScreen({super.key});

  @override
  State<TaskOverviewScreen> createState() => _TaskOverviewScreenState();
}

class _TaskOverviewScreenState extends State<TaskOverviewScreen> {
  bool _isLoading = true;
  List<TaskItem> _tasks = [];

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    final userId = PocketBaseService.client.authStore.model?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Get all tasks assigned to me or created by me
      // Because we don't have board-level task fetch easily without joins,
      // we just filter by assignees contains me OR created_by = me.
      final records = await PocketBaseService.client.collection('task_items').getFullList(
        filter: 'assignees ~ "$userId" || created_by = "$userId"',
        sort: '-created',
      );
      
      final tasks = records.map((e) => TaskItem.fromRecord(e)).toList();
      
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Görev Özeti ve Geçmişi')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final completedTasks = _tasks.where((t) => t.isCompleted).toList();
    final pendingTasks = _tasks.where((t) => !t.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Görev Özeti ve Geçmişi'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: 'Genel İstatistikler. Toplam ${_tasks.length} görev içerisinde, ${completedTasks.length} adet tamamlanan ve ${pendingTasks.length} adet bekleyen görev bulunuyor',
                child: ExcludeSemantics(
                  child: Card(
                    color: Colors.blue.shade900,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('Genel İstatistikler', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem('Toplam', _tasks.length.toString(), Colors.blue),
                              _buildStatItem('Tamamlanan', completedTasks.length.toString(), Colors.green),
                              _buildStatItem('Bekleyen', pendingTasks.length.toString(), Colors.orange),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Bekleyen Görevlerim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (pendingTasks.isEmpty)
                const Text('Bekleyen göreviniz bulunmuyor.', style: TextStyle(color: Colors.grey))
              else
                ...pendingTasks.map((t) => _buildTaskTile(t)).toList(),
                
              const SizedBox(height: 24),
              const Text('Geçmiş (Tamamlanan) Görevlerim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (completedTasks.isEmpty)
                const Text('Hiç tamamlanmış göreviniz bulunmuyor.', style: TextStyle(color: Colors.grey))
              else
                ...completedTasks.map((t) => _buildTaskTile(t)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70)),
      ],
    );
  }

  Widget _buildTaskTile(TaskItem task) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(task.isCompleted ? Icons.check_circle : Icons.pending, color: task.isCompleted ? Colors.green : Colors.orange),
        title: Text(task.title, style: TextStyle(decoration: task.isCompleted ? TextDecoration.lineThrough : null)),
        subtitle: Text(
          'Oluşturulma: ${task.created.day}/${task.created.month}/${task.created.year}',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
