import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'package:blind_social/features/task_board/data/models/task_board.dart';
import 'package:blind_social/features/task_board/data/models/task_list_model.dart';
import 'package:blind_social/features/task_board/data/models/task_item.dart';
import 'package:blind_social/features/task_board/data/models/task_checklist.dart';
import 'package:blind_social/features/task_board/data/models/task_comment.dart';

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

  Future<TaskBoard> updateBoard(String boardId, String name) async {
    final record = await _pb.collection('task_boards').update(boardId, body: {
      'name': name,
    });
    return TaskBoard.fromRecord(record);
  }

  Future<void> deleteBoard(String boardId) async {
    await _pb.collection('task_boards').delete(boardId);
  }

  Future<TaskBoard> toggleFavoriteBoard(TaskBoard board) async {
    final userId = _pb.authStore.model?.id;
    if (userId == null) throw Exception("Oturum bulunamadı");

    final List<String> favorites = List.from(board.favoritedBy);
    if (favorites.contains(userId)) {
      favorites.remove(userId);
    } else {
      favorites.add(userId);
    }

    final record = await _pb.collection('task_boards').update(board.id, body: {
      'favorited_by': favorites,
    });
    return TaskBoard.fromRecord(record);
  }

  Future<void> addMember(String boardId, String identifier) async {
    // 1. Find user by email or username
    final userRes = await _pb.collection('users').getList(filter: 'email = "$identifier" || username = "$identifier"', page: 1, perPage: 1);
    if (userRes.items.isEmpty) throw Exception("Bu bilgilere (e-posta veya kullanıcı adı) sahip kayıtlı bir kullanıcı bulunamadı.");

    final newUserId = userRes.items.first.id;

    // 2. Fetch current board
    final boardRecord = await _pb.collection('task_boards').getOne(boardId);
    final members = boardRecord.getListValue<String>('members');
    final ownerId = boardRecord.getStringValue('owner_id');

    if (ownerId == newUserId) throw Exception("Kullanıcı zaten bu panonun sahibi.");
    if (members.contains(newUserId)) throw Exception("Kullanıcı zaten bu panoya üye.");

    members.add(newUserId);

    await _pb.collection('task_boards').update(boardId, body: {
      'members': members,
    });
  }

  Future<void> removeMember(String boardId, String userId) async {
    final boardRecord = await _pb.collection('task_boards').getOne(boardId);
    final members = boardRecord.getListValue<String>('members');
    
    if (members.contains(userId)) {
      members.remove(userId);
      await _pb.collection('task_boards').update(boardId, body: {
        'members': members,
      });
    }
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

  Future<TaskListM> toggleListCollapsed(TaskListM listM) async {
    final userId = _pb.authStore.model?.id;
    if (userId == null) throw Exception("Oturum bulunamadı");

    final List<String> collapsed = List.from(listM.collapsedBy);
    if (collapsed.contains(userId)) {
      collapsed.remove(userId);
    } else {
      collapsed.add(userId);
    }

    final record = await _pb.collection('task_lists').update(listM.id, body: {
      'collapsed_by': collapsed,
    });
    return TaskListM.fromRecord(record);
  }

  Future<TaskListM> toggleListPinned(TaskListM listM) async {
    final userId = _pb.authStore.model?.id;
    if (userId == null) throw Exception("Oturum bulunamadı");

    final List<String> pinned = List.from(listM.pinnedBy);
    if (pinned.contains(userId)) {
      pinned.remove(userId);
    } else {
      pinned.add(userId);
    }

    final record = await _pb.collection('task_lists').update(listM.id, body: {
      'pinned_by': pinned,
    });
    return TaskListM.fromRecord(record);
  }

  Future<TaskListM> updateListOrder(String listId, int newOrder) async {
    final record = await _pb.collection('task_lists').update(listId, body: {
      'order': newOrder,
    });
    return TaskListM.fromRecord(record);
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

    // Fetch highest task_number
    int nextNumber = 1001;
    try {
      final res = await _pb.collection('task_items').getList(page: 1, perPage: 1, sort: '-task_number');
      if (res.items.isNotEmpty) {
        final highest = res.items.first.getIntValue('task_number');
        if (highest >= 1000) {
          nextNumber = highest + 1;
        }
      }
    } catch (_) {}

    final record = await _pb.collection('task_items').create(body: {
      'list_id': listId,
      'title': title,
      'description': description,
      'created_by': userId,
      'order': order,
      'is_completed': false,
      'task_number': nextNumber,
    });
    return TaskItem.fromRecord(record);
  }

  Future<TaskItem> updateTaskState(String taskId, bool isCompleted) async {
    final record = await _pb.collection('task_items').update(taskId, body: {
      'is_completed': isCompleted,
    });
    return TaskItem.fromRecord(record);
  }

  Future<TaskItem> updateTaskDetails(String taskId, {String? title, String? description, String? listId}) async {
    final Map<String, dynamic> body = {};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (listId != null) body['list_id'] = listId;

    if (body.isEmpty) throw Exception("Güncellenecek veri yok");

    final record = await _pb.collection('task_items').update(taskId, body: body);
    return TaskItem.fromRecord(record);
  }

  Future<TaskItem> updateTaskTimeLogs(String taskId, List<dynamic> timeLogs) async {
    final Map<String, dynamic> body = {
      'time_logs': timeLogs,
    };
    final record = await _pb.collection('task_items').update(taskId, body: body);
    return TaskItem.fromRecord(record);
  }

  Future<TaskItem> updateTaskDates(String taskId, DateTime? startDate, DateTime? dueDate) async {
    final Map<String, dynamic> body = {
      'start_date': startDate?.toIso8601String() ?? '',
      'due_date': dueDate?.toIso8601String() ?? '',
    };
    final record = await _pb.collection('task_items').update(taskId, body: body);
    return TaskItem.fromRecord(record);
  }

  Future<TaskItem> uploadVoiceNote(String taskId, String path) async {
    final multipartFile = await http.MultipartFile.fromPath('voice_notes', path);
    final record = await _pb.collection('task_items').update(taskId, files: [multipartFile]);
    return TaskItem.fromRecord(record);
  }

  Future<TaskItem> deleteVoiceNote(String taskId, String fileName) async {
    // To delete a file from a list, we send null for that specific filename using the minus suffix or we just update the record with other files?
    // Wait, in PocketBase you can't just delete a single array file easily without doing `-voice_notes`. Let's use the minus suffix.
    // pocketbase provides removing specific array item like body: { 'voice_notes': null } would clear all.
    // wait, actually in pb `record` we can send `field-` modifier or just use `minus` suffix? No, usually `update` takes a `fileName` to remove. Let's just do `{'voice_notes-': fileName}` map.
    // Actually pb dart SDK supports it, or we might need to be careful. The new standard is `{"voice_notes.delete": fileName}` in PB > 0.17? No it's `{"voice_notes-": [fileName]}`?
    // Let's check PB API: to delete a file from array, PB < 0.22 uses 'voice_notes-': fileName. But blind_social uses pocketbase ^0.20.0
    // Actually the standard way is: `{"voice_notes": null}` deletes ALL files. Wait, if it's an array, it's safer to not delete specific unless we know. Or we can just use `{'voice_notes-': fileName}`.
    // Alternatively we can use `{'voice_notes-': fileName}` 
    final record = await _pb.collection('task_items').update(taskId, body: {
      'voice_notes-': fileName,
    });
    return TaskItem.fromRecord(record);
  }

  Future<TaskItem> updateTaskLabels(String taskId, List<dynamic> labels) async {
    final record = await _pb.collection('task_items').update(taskId, body: {
      'labels': labels,
    });
    return TaskItem.fromRecord(record);
  }

  Future<TaskItem> updateTaskResources(String taskId, List<dynamic> resources) async {
    final record = await _pb.collection('task_items').update(taskId, body: {
      'resources': resources,
    });
    return TaskItem.fromRecord(record);
  }

  Future<TaskItem> toggleAssignee(String taskId, String userId) async {
    final taskRecord = await _pb.collection('task_items').getOne(taskId);
    final assignees = taskRecord.getListValue<String>('assignees');
    
    if (assignees.contains(userId)) {
      assignees.remove(userId);
    } else {
      assignees.add(userId);
    }

    final record = await _pb.collection('task_items').update(taskId, body: {
      'assignees': assignees,
    });
    return TaskItem.fromRecord(record);
  }

  Future<void> deleteTask(String taskId) async {
    await _pb.collection('task_items').delete(taskId);
  }

  // CHECKLISTS
  Future<List<TaskChecklist>> getChecklist(String taskId) async {
    final records = await _pb.collection('task_checklists').getFullList(
      filter: 'task_id = "$taskId"',
      sort: 'order, created',
    );
    return records.map((e) => TaskChecklist.fromRecord(e)).toList();
  }

  Future<TaskChecklist> createChecklistItem(String taskId, String title, int order) async {
    final record = await _pb.collection('task_checklists').create(body: {
      'task_id': taskId,
      'title': title,
      'is_completed': false,
      'order': order,
    });
    return TaskChecklist.fromRecord(record);
  }

  Future<TaskChecklist> updateChecklistState(String itemId, bool isCompleted) async {
    final record = await _pb.collection('task_checklists').update(itemId, body: {
      'is_completed': isCompleted,
    });
    return TaskChecklist.fromRecord(record);
  }

  Future<void> deleteChecklistItem(String itemId) async {
    await _pb.collection('task_checklists').delete(itemId);
  }

  // COMMENTS
  Future<List<TaskComment>> getComments(String taskId) async {
    final records = await _pb.collection('task_comments').getFullList(
      filter: 'task_id = "$taskId"',
      sort: '-created', // En yeniler en üstte veya +created eski aşağıda? Thumbs up to user.
      expand: 'user_id',
    );
    return records.map((e) => TaskComment.fromRecord(e)).toList();
  }

  Future<TaskComment> createComment(String taskId, String content) async {
    final userId = _pb.authStore.model?.id;
    if (userId == null) throw Exception("Oturum bulunamadı");
    
    final record = await _pb.collection('task_comments').create(
      body: {
        'task_id': taskId,
        'user_id': userId,
        'content': content,
      },
      expand: 'user_id',
    );
    return TaskComment.fromRecord(record);
  }

  Future<TaskComment> createVoiceComment(String taskId, String path) async {
    final userId = _pb.authStore.model?.id;
    if (userId == null) throw Exception("Oturum bulunamadı");

    http.MultipartFile file;
    if (kIsWeb) {
      final res = await http.get(Uri.parse(path));
      file = http.MultipartFile.fromBytes('voice_note', res.bodyBytes, filename: kIsWeb ? 'ses.webm' : 'ses.m4a');
    } else {
      file = await http.MultipartFile.fromPath('voice_note', path);
    }
    
    final record = await _pb.collection('task_comments').create(
      body: {
        'task_id': taskId,
        'user_id': userId,
        'content': '🎤 Sesli Mesaj', // Content required to pass Pocketbase validation
      },
      files: [file],
      expand: 'user_id',
    );
    return TaskComment.fromRecord(record);
  }

  Future<void> deleteComment(String commentId) async {
    await _pb.collection('task_comments').delete(commentId);
  }
}
