import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:share_plus/share_plus.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/features/task_board/data/models/task_item.dart';
import 'package:blind_social/features/task_board/data/models/task_checklist.dart';
import 'package:blind_social/features/task_board/data/models/task_list_model.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';
import 'package:blind_social/features/task_board/presentation/widgets/task_stopwatch_widget.dart';
import 'package:blind_social/features/task_board/presentation/widgets/task_voice_notes_widget.dart';
import 'package:blind_social/features/task_board/presentation/widgets/task_comments_widget.dart';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class TaskDetailScreen extends StatefulWidget {
  final TaskItem task;
  final List<TaskListM> allLists;

  const TaskDetailScreen({
    Key? key,
    required this.task,
    required this.allLists,
  }) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TaskBoardService _service = TaskBoardService();
  late TaskItem _task;
  List<TaskChecklist> _checklists = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _assigneesData = [];

  final FocusNode _addLabelBtnFocusNode = FocusNode();
  final FocusNode _addChecklistBtnFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _fetchDataCombined();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceRemainingDays();
    });
  }

  void _announceRemainingDays() {
    if (_task.dueDate != null) {
      final diff = _task.dueDate!.difference(DateTime.now());
      final d = diff.inDays;
      if (d > 0) {
        SemanticsService.announce('Bu görevin tamamlanması için $d gün kaldı.', TextDirection.ltr);
      } else if (d == 0) {
        SemanticsService.announce('Bu görevin tamamlanması için bugün son gün.', TextDirection.ltr);
      } else {
        SemanticsService.announce('Bu görevin süresi ${d.abs()} gün gecikti.', TextDirection.ltr);
      }
    }
  }

  Future<void> _selectDueDate() async {
    final ctrl = TextEditingController();
    
    if (_task.dueDate != null) {
      final dt = _task.dueDate!.toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      ctrl.text = '$day/$month/${dt.year}';
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bitiş Tarihini Belirle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Bitiş tarihini gün, ay ve yıl olarak araya eğik çizgi ekleyerek giriniz. Eğik çizgi koymazsanız sistem otomatik olarak ekleyecektir. Örneğin 15082026.',
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Bitiş Tarihi (GG/AA/YYYY)',
                    hintText: 'Örn: 30/12/2026 veya 30122026',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Silmek için alanı boş bırakarak "Kaydet"e basabilirsiniz.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('İptal')
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, ctrl.text.trim());
              }, 
              child: const Text('Kaydet')
            ),
          ],
        );
      }
    );

    if (result != null) {
      DateTime? selectedDate;
      String dob = result;
      if (dob.isNotEmpty) {
        if (dob.length == 8 && !dob.contains('/')) {
          dob = '${dob.substring(0, 2)}/${dob.substring(2, 4)}/${dob.substring(4, 8)}';
        }
        final dateRegExp = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
        final match = dateRegExp.firstMatch(dob);
        if (match != null) {
          final int? day = int.tryParse(match.group(1)!);
          final int? month = int.tryParse(match.group(2)!);
          final int? year = int.tryParse(match.group(3)!);
          if (day != null && month != null && year != null) {
            try {
              selectedDate = DateTime(year, month, day);
            } catch (_) {}
          }
        }
        
        if (selectedDate == null) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçersiz tarih formatı. Lütfen GG/AA/YYYY formatında giriniz.')));
          return;
        }
      }

      setState(() => _isLoading = true);
      try {
        final updated = await _service.updateTaskDates(_task.id, _task.startDate, selectedDate);
        setState(() => _task = updated);
        if (selectedDate != null) {
          SemanticsService.announce('Bitiş tarihi başarıyla eklendi.', TextDirection.ltr);
          _announceRemainingDays();
        } else {
          SemanticsService.announce('Bitiş tarihi silindi.', TextDirection.ltr);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _addLabelBtnFocusNode.dispose();
    _addChecklistBtnFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchDataCombined() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchChecklists(),
      _fetchAssignees(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }
  
  Future<void> _fetchAssignees() async {
    List<Map<String, dynamic>> users = [];
    for (String id in _task.assignees) {
      try {
        final rec = await PocketBaseService.client.collection('_pb_users_auth_').getOne(id);
        users.add(rec.toJson());
      } catch (e) {
        // ignore
      }
    }
    if (mounted) {
      setState(() {
        _assigneesData = users;
      });
    }
  }

  Future<void> _fetchChecklists() async {
    try {
      final items = await _service.getChecklist(_task.id);
      setState(() {
        _checklists = items;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _refreshTask() async {
    try {
      final updatedTaskRecord = await PocketBaseService.client.collection('task_items').getOne(_task.id);
      setState(() {
        _task = TaskItem.fromRecord(updatedTaskRecord);
      });
      await _fetchAssignees();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Görev yenilenemedi: $e')));
    }
  }

  Future<void> _editDescription() async {
    final ctrl = TextEditingController(text: _task.description);
    final isSaved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Açıklama Düzenle'),
          content: TextField(
            controller: ctrl,
            maxLines: 5,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Açıklama giriniz...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (isSaved == true) {
      try {
        final updated = await _service.updateTaskDetails(_task.id, description: ctrl.text);
        setState(() {
          _task = updated;
        });
        SemanticsService.announce('Açıklama güncellendi', TextDirection.ltr);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _addLabel() async {
    final ctrl = TextEditingController();
    String? selectedColor = 'blue';
    final colors = ['blue', 'red', 'green', 'purple', 'orange'];

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Etiket Ekle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(labelText: 'Etiket Adı'),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: colors.map((c) {
                      final colorObj = _getColor(c);
                      final cTr = _getColorNameTr(c);
                      return Semantics(
                        label: '$cTr renk seçimi',
                        selected: selectedColor == c,
                        child: ExcludeSemantics(
                          child: ChoiceChip(
                            label: const Text(' '),
                            selected: selectedColor == c,
                            selectedColor: colorObj.withOpacity(0.5),
                            backgroundColor: colorObj,
                            onSelected: (val) {
                              setDialogState(() => selectedColor = c);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (ctrl.text.isEmpty) return;
                    Navigator.pop(context, {'text': ctrl.text, 'color': selectedColor!});
                  },
                  child: const Text('Ekle'),
                ),
              ],
            );
          }
        );
      },
    );

    if (result != null) {
      try {
        final newLabels = List.from(_task.labels)..add(result);
        final updated = await _service.updateTaskLabels(_task.id, newLabels);
        setState(() {
          _task = updated;
        });
        SemanticsService.announce('Etiket eklendi', TextDirection.ltr);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _removeLabel(dynamic label) async {
    try {
      final newLabels = List.from(_task.labels)..remove(label);
      final updated = await _service.updateTaskLabels(_task.id, newLabels);
      setState(() {
        _task = updated;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addLabelBtnFocusNode.requestFocus();
        SemanticsService.announce('Etiket silindi', TextDirection.ltr);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _shareTaskInformation() {
    final buffer = StringBuffer();
    buffer.writeln('Görev Adı: ${_task.title}');
    buffer.writeln('Durum: ${_task.isCompleted ? "Tamamlandı" : "Devam Ediyor"}');
    
    buffer.writeln('Oluşturulma Tarihi: ${_formatDt(_task.created)}');
    if (_task.dueDate != null) {
      buffer.writeln('Bitiş Tarihi (Hedef): ${_formatDt(_task.dueDate!)}');
      final diff = _task.dueDate!.difference(DateTime.now());
      final d = diff.inDays;
      if (d > 0) {
        buffer.writeln('Kalan Süre: $d gün kaldı.');
      } else if (d == 0) {
        buffer.writeln('Kalan Süre: Bugün bitiyor.');
      } else {
        buffer.writeln('Kalan Süre: Süresi ${d.abs()} gün geçti.');
      }
    }
    buffer.writeln();

    if (_task.description.isNotEmpty) {
      buffer.writeln('Açıklama:');
      buffer.writeln(_task.description);
      buffer.writeln();
    }

    if (_task.labels.isNotEmpty) {
      buffer.writeln('Etiketler:');
      for (var lbl in _task.labels) {
        buffer.writeln('- ${lbl['text']}');
      }
      buffer.writeln();
    }

    if (_assigneesData.isNotEmpty) {
      buffer.writeln('Sorumlular (Atananlar):');
      final assigneesStr = _assigneesData.map((u) => (u['full_name'] as String? ?? '').isNotEmpty == true ? u['full_name'] : u['username']).join(', ');
      buffer.writeln(assigneesStr);
      buffer.writeln();
    }

    if (_checklists.isNotEmpty) {
      buffer.writeln('Kontrol Listesi:');
      for (var c in _checklists) {
        buffer.writeln('- ${c.title} (${c.isCompleted ? "Tamamlandı" : "Tamamlanmadı"})');
      }
      buffer.writeln();
    }

    if (_task.resources.isNotEmpty) {
      buffer.writeln('Kaynaklar:');
      for (var res in _task.resources) {
        final urlString = res is Map ? (res['url']?.toString() ?? '') : res.toString();
        final titleString = res is Map ? (res['title']?.toString() ?? urlString) : urlString;
        
        if (titleString != urlString) {
          buffer.writeln('- $titleString: $urlString');
        } else {
          buffer.writeln('- $urlString');
        }
      }
      buffer.writeln();
    }

    if (_task.voiceNotes.isNotEmpty) {
      buffer.writeln('Sesli Notlar: ${_task.voiceNotes.length} adet sesli not mevcut.');
      buffer.writeln();
    }

    if (_task.timeLogs.isNotEmpty) {
      Duration total = Duration.zero;
      for (var log in _task.timeLogs) {
        final start = DateTime.parse(log['start']);
        final end = log['end'] != null ? DateTime.parse(log['end']) : DateTime.now().toUtc();
        total += end.difference(start);
      }
      if (total.inSeconds > 0) {
        int days = total.inDays;
        int hours = total.inHours % 24;
        int mins = total.inMinutes % 60;
        List<String> p = [];
        if(days > 0) p.add("$days gün");
        if(hours > 0) p.add("$hours saat");
        if(mins > 0) p.add("$mins dakika");
        if(p.isEmpty) p.add("1 dakikadan az");
        buffer.writeln("Görev Kronometresi: Bu görev üzerinde toplam ${p.join(" ")} çalışıldı.");
        buffer.writeln();
      }
    }

    buffer.writeln('--------------------');
    buffer.writeln('Blind Social - Görev Planlayıcısı ile oluşturulmuştur.');

    Share.share(buffer.toString());
  }

  Future<void> _moveList() async {
    final newListId = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Listeyi Değiştir'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
              shrinkWrap: true,
              itemCount: widget.allLists.length,
              itemBuilder: (context, index) {
                final list = widget.allLists[index];
                if (list.id == _task.listId) return const SizedBox.shrink();
                return ListTile(
                  title: Text(list.name),
                  onTap: () => Navigator.pop(context, list.id),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('İptal'),
            ),
          ],
        );
      },
    );

    if (newListId != null) {
      try {
        final updated = await _service.updateTaskDetails(_task.id, listId: newListId);
        setState(() {
          _task = updated;
        });
        SemanticsService.announce('Görev başka listeye taşındı', TextDirection.ltr);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Color _getColor(String c) {
    switch (c) {
      case 'red': return Colors.red;
      case 'green': return Colors.green;
      case 'purple': return Colors.purple;
      case 'orange': return Colors.orange;
      case 'blue':
      default: return Colors.blue;
    }
  }

  String _getColorNameTr(String c) {
    switch (c) {
      case 'red': return 'Kırmızı';
      case 'green': return 'Yeşil';
      case 'purple': return 'Mor';
      case 'orange': return 'Turuncu';
      case 'blue': return 'Mavi';
      default: return 'Mavi';
    }
  }

  void _announceChecklistProgress() {
    if (_checklists.isEmpty) return;
    int completedCount = _checklists.where((c) => c.isCompleted).length;
    int total = _checklists.length;
    int percentage = ((completedCount / total) * 100).round();
    SemanticsService.announce('$total işten $completedCount bitti, yüzde $percentage tamamlandı', TextDirection.ltr);
  }

  Future<void> _addChecklistItem() async {
    final ctrl = TextEditingController();
    final isSaved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Kontrol Maddesi'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Başlık')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
        ],
      )
    );

    if (isSaved == true && ctrl.text.isNotEmpty) {
      try {
        final order = _checklists.isEmpty ? 1 : _checklists.last.order + 1;
        final newItem = await _service.createChecklistItem(_task.id, ctrl.text, order);
        setState(() {
          _checklists.add(newItem);
        });
        _announceChecklistProgress();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _toggleChecklist(TaskChecklist item) async {
    try {
      final updated = await _service.updateChecklistState(item.id, !item.isCompleted);
      setState(() {
        final idx = _checklists.indexWhere((c) => c.id == item.id);
        if (idx != -1) _checklists[idx] = updated;
      });
      _announceChecklistProgress();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _deleteChecklistItem(TaskChecklist item) async {
    try {
      await _service.deleteChecklistItem(item.id);
      setState(() {
        _checklists.removeWhere((c) => c.id == item.id);
      });
      _announceChecklistProgress();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addChecklistBtnFocusNode.requestFocus();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Görevi Sil'),
        content: const Text('Bu görevi silmek istediğinize emin misiniz? Bu işlem geri alınamaz ve göreve ait tüm veriler (ses kayıtları, notlar vb.) silinir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _service.deleteTask(_task.id);
        SemanticsService.announce('Görev başarıyla silindi', TextDirection.ltr);
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _fetchPageTitle(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.isAbsolute) return null;
      
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final match = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false).firstMatch(response.body);
        if (match != null && match.groupCount > 0) {
          final title = match.group(1)?.trim();
          if (title != null && title.isNotEmpty) {
            return title.replaceAll('&nbsp;', ' ')
                        .replaceAll('&amp;', '&')
                        .replaceAll('&lt;', '<')
                        .replaceAll('&gt;', '>')
                        .replaceAll('&quot;', '"')
                        .replaceAll('&#39;', "'")
                        .replaceAll('\n', '')
                        .replaceAll('\r', '');
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _addResource() async {
    final ctrl = TextEditingController();
    final isSaved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni URL/Kaynak Ekle'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: 'URL Adresi', hintText: 'https://...'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.paste),
              tooltip: 'Panodan Yapıştır',
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data != null && data.text != null) {
                  ctrl.text = data.text!;
                }
              },
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
        ],
      )
    );

    if (isSaved == true && ctrl.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final url = ctrl.text.trim();
        final title = await _fetchPageTitle(url);
        final resObj = {
          'url': url,
          'title': title
        };
        final newResources = List.from(_task.resources)..add(resObj);
        final updated = await _service.updateTaskResources(_task.id, newResources);
        setState(() {
          _task = updated;
        });
        SemanticsService.announce('Kaynak eklendi', TextDirection.ltr);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeResource(dynamic res) async {
    try {
      final newResources = List.from(_task.resources)..remove(res);
      final updated = await _service.updateTaskResources(_task.id, newResources);
      setState(() {
        _task = updated;
      });
      SemanticsService.announce('Kaynak silindi', TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _copyResource(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    SemanticsService.announce('URL panoya kopyalandı', TextDirection.ltr);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL kopyalandı')));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true); // Her zaman değişiklik var kabul edip sayfayı yenilemek için true dönüyoruz
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Focus(
            autofocus: true,
            child: Text('${_task.title} isimli görevin detayları'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Kartı Paylaş',
              onPressed: _shareTaskInformation,
            ),
            IconButton(
              icon: const Icon(Icons.drive_file_move),
              tooltip: 'Listeyi Değiştir',
              onPressed: _moveList,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Görevi Sil',
              onPressed: _deleteTask,
            )
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_task.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Oluşturulma: ${_formatDt(_task.created)}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(_task.dueDate != null ? 'Bitiş (Hedef): ${_formatDt(_task.dueDate!)}' : 'Bitiş tarihi eklenmemiş', style: const TextStyle(color: Colors.grey)),
                    IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      tooltip: 'Bitiş Tarihi Belirle',
                      onPressed: _selectDueDate,
                    )
                  ]
                ),
                const SizedBox(height: 16),
                
                // Etiketler
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._task.labels.map((lbl) {
                        final colorName = lbl['color'] ?? 'blue';
                        final cTr = _getColorNameTr(colorName);
                        return Semantics(
                          label: '${lbl['text']} isimli $cTr renkli etiket. Etiketi silmek için işlemler menüsünü açın ve özellikleri kullanın.',
                          button: true,
                          customSemanticsActions: {
                            const CustomSemanticsAction(label: 'Etiketi Sil'): () => _removeLabel(lbl),
                          },
                          child: ExcludeSemantics(
                            child: Chip(
                              label: Text(lbl['text'] ?? '', style: const TextStyle(color: Colors.white)),
                              backgroundColor: _getColor(colorName),
                              onDeleted: () => _removeLabel(lbl),
                              deleteIconColor: Colors.white,
                            ),
                          ),
                        );
                    }).toList(),
                    ActionChip(
                      focusNode: _addLabelBtnFocusNode,
                      label: const Text('Etiket Ekle'),
                      avatar: const Icon(Icons.add, size: 16),
                      onPressed: _addLabel,
                    )
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sorumlular (Atananlar)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ActionChip(
                      label: Text(_task.assignees.contains(PocketBaseService.client.authStore.model?.id) ? 'Sorumluluğu Bırak' : 'Beni Sorumlu Yap'),
                      onPressed: () async {
                        final uId = PocketBaseService.client.authStore.model?.id;
                        if (uId == null) return;
                        try {
                          final updated = await _service.toggleAssignee(_task.id, uId);
                          setState(() {
                            _task = updated;
                          });
                          await _fetchAssignees();
                          SemanticsService.announce("Sorumluluk durumu güncellendi", TextDirection.ltr);
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                        }
                      },
                    )
                  ],
                ),
                if (_assigneesData.isEmpty)
                  const Text('Bu göreve henüz kimse atanmadı.')
                else
                  Text('${_assigneesData.map((u) => (u['full_name'] as String? ?? '').isNotEmpty == true ? u['full_name'] : u['username']).join(', ')} isimli kullanıcılar bu görev için atandı.'),
                const SizedBox(height: 24),

                // Açıklama
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Açıklama', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Açıklamayı Düzenle',
                      onPressed: _editDescription,
                    )
                  ],
                ),
                Text(
                  _task.description.isEmpty ? 'Açıklama eklenmemiş.' : _task.description,
                ),
                const SizedBox(height: 24),
                const Divider(),

                // Kaynaklar (Resources)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kaynaklar (URL)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'URL Ekle',
                      onPressed: _addResource,
                    )
                  ],
                ),
                if (_task.resources.isEmpty)
                  const Text('Henüz kaynak eklenmemiş.')
                else
                  ..._task.resources.map((res) {
                    final String urlString = res is Map ? (res['url']?.toString() ?? '') : res.toString();
                    final String titleString = res is Map ? (res['title']?.toString() ?? urlString) : urlString;
                    
                    return Card(
                      child: Semantics(
                        label: titleString != urlString ? 'Kaynak Başlığı: $titleString' : 'Kaynak URL: $urlString',
                        button: true,
                        customSemanticsActions: {
                          const CustomSemanticsAction(label: 'URL Kopyala'): () => _copyResource(urlString),
                          const CustomSemanticsAction(label: 'URL Sil'): () => _removeResource(res),
                        },
                        child: ExcludeSemantics(
                          child: ListTile(
                            leading: const Icon(Icons.link),
                            title: Text(titleString, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: titleString != urlString ? Text(urlString, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  tooltip: 'Kopyala',
                                  onPressed: () => _copyResource(urlString),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Sil',
                                  onPressed: () => _removeResource(res),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                const SizedBox(height: 24),
                const Divider(),

                // Kontrol Listesi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kontrol Listesi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (_checklists.isNotEmpty)
                          Builder(
                            builder: (context) {
                              int completedCount = _checklists.where((c) => c.isCompleted).length;
                              int total = _checklists.length;
                              int percentage = ((completedCount / total) * 100).round();
                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('Yüzde $percentage Tamamlandı ($completedCount/$total)', style: const TextStyle(fontSize: 14, color: Colors.white70)),
                              );
                            }
                          ),
                      ],
                    ),
                    IconButton(
                      focusNode: _addChecklistBtnFocusNode,
                      icon: const Icon(Icons.add),
                      tooltip: 'Madde Ekle',
                      onPressed: _addChecklistItem,
                    )
                  ],
                ),
                if (_isLoading) const Center(child: CircularProgressIndicator())
                else if (_checklists.isEmpty) const Text('Kontrol listesi boş.')
                else ..._checklists.map((c) {
                  return Card(
                    child: Semantics(
                      label: '${c.title}. ${c.isCompleted ? "Tamamlandı" : "Tamamlanmadı"}. İşlem seçenekleri için parmağınızı yukarı veya aşağı kaydırın.',
                      button: true,
                      customSemanticsActions: {
                        CustomSemanticsAction(label: c.isCompleted ? 'Tamamlanmadı Olarak İşaretle' : 'Tamamlandı Olarak İşaretle'): () => _toggleChecklist(c),
                        const CustomSemanticsAction(label: 'Maddeyi Sil'): () => _deleteChecklistItem(c),
                      },
                      child: ExcludeSemantics(
                        child: ListTile(
                          leading: Checkbox(
                            value: c.isCompleted,
                            onChanged: (v) => _toggleChecklist(c),
                          ),
                          title: Text(
                            c.title,
                            style: TextStyle(
                              decoration: c.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Sil',
                            onPressed: () => _deleteChecklistItem(c),
                          ),
                          onTap: () => _toggleChecklist(c),
                        ),
                      ),
                    ),
                  );
                }).toList(),
                
                const SizedBox(height: 24),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.chat),
                  title: const Text('Bu Görevdeki Mesajlar', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Diğer üyelerle sohbet edin veya sesli mesaj bırakın.'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => Scaffold(
                          appBar: AppBar(
                            title: Semantics(
                              label: '${_task.title} isimli görev için mesajlaşmaktasınız',
                              child: Text(
                                '${_task.title} - Mesajlar',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          body: SafeArea(
                            child: TaskCommentsWidget(taskId: _task.id),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                const Divider(),
                TaskVoiceNotesWidget(
                  task: _task,
                  service: _service,
                  onChanged: () => _refreshTask(),
                ),
                
                const SizedBox(height: 24),
                const Divider(),
                TaskStopwatchWidget(
                  task: _task,
                  service: _service,
                  onChanged: () => _refreshTask(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDt(DateTime dt) {
    final now = DateTime.now();
    final dLocal = dt.toLocal();
    const months = ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
    if (now.year == dLocal.year) return "${dLocal.day} ${months[dLocal.month]}";
    return "${dLocal.day} ${months[dLocal.month]} ${dLocal.year}";
  }
}
