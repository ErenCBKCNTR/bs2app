import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/features/task_board/data/models/task_board.dart';
import 'package:blind_social/features/task_board/data/models/task_list_model.dart';
import 'package:blind_social/features/task_board/data/models/task_item.dart';

class TaskBoardService {
  final PocketBase _pb = PocketBaseService.client;

  // BOARDS
  Future<List<TaskBoard>> getMyBoards() async {
    final userId = _pb.authStore.model?.id;
    if (userId == null) return [];

    final records = await _pb.collection('task_boards').getFullList(
      filter: 'owner_id = "$userId" || members ~ "$userId"',
      sort: '-created',
    );
    return records.map((e) => TaskBoard.fromRecord(e)).toList();
  }

  Future<TaskBoard> createBoard(String name, String description) async {
    final userId = _pb.authStore.model?.id;
    if (userId == null) throw Exception("Oturum bulunamadı");

    final record = await _pb.collection('task_boards').create(body: {
      'name': name,
      'description': description,
      'owner_id': userId,
    });
    return TaskBoard.fromRecord(record);
  }

  Future<void> deleteBoard(String boardId) async {
    await _pb.collection('task_boards').delete(boardId);
  }

  // LISTS
  Future<List<TaskListM>> getLists(String boardId) async {
    final records = await _pb.collection('task_lists').getFullList(
      filter: 'board_id = "$boardId"',
      sort: 'order, created',
    );
    return records.map((e) => TaskListM.fromRecord(e)).toList();
  }

  Future<TaskListM> createList(String boardId, String name, int order) async {
    final record = await _pb.collection('task_lists').create(body: {
      'board_id': boardId,
      'name': name,
      'order': order,
    });
    return TaskListM.fromRecord(record);
  }

  Future<void> deleteList(String listId) async {
    await _pb.collection('task_lists').delete(listId);
  }

  // TASKS
  Future<List<TaskItem>> getTasks(String listId) async {
    final records = await _pb.collection('task_items').getFullList(
      filter: 'list_id = "$listId"',
      sort: 'order, created',
    );
    return records.map((e) => TaskItem.fromRecord(e)).toList();
  }

  Future<TaskItem> createTask(String listId, String title, String description, int order) async {
    final userId = _pb.authStore.model?.id;
    if (userId == null) throw Exception("Oturum bulunamadı");

    final record = await _pb.collection('task_items').create(body: {
      'list_id': listId,
      'title': title,
      'description': description,
      'created_by': userId,
      'order': order,
      'is_completed': false,
    });
    return TaskItem.fromRecord(record);
  }

  Future<TaskItem> updateTaskState(String taskId, bool isCompleted) async {
    final record = await _pb.collection('task_items').update(taskId, body: {
      'is_completed': isCompleted,
    });
    return TaskItem.fromRecord(record);
  }

  Future<void> deleteTask(String taskId) async {
    await _pb.collection('task_items').delete(taskId);
  }
}
