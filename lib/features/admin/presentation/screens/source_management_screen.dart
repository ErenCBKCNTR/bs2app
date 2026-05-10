import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';

class SourceManagementScreen extends StatefulWidget {
  const SourceManagementScreen({super.key});

  @override
  State<SourceManagementScreen> createState() => _SourceManagementScreenState();
}

class _SourceManagementScreenState extends State<SourceManagementScreen> {
  List<RecordModel> _sources = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSources();
  }

  Future<void> _fetchSources() async {
    try {
      final records = await PocketBaseService.client.collection('campaign_sources').getFullList(
        sort: '-created',
      );
      if (mounted) {
        setState(() {
          _sources = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.instance.error('Kaynaklar yüklenemedi: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSourceDialog([RecordModel? source]) {
    final nameController = TextEditingController(text: source?.getStringValue('name'));
    final urlController = TextEditingController(text: source?.getStringValue('url'));
    
    final categories = [
      'Akaryakıt', 'Araç', 'E-Ticaret', 'Eğitim & Kırtasiye', 'Eğlence', 
      'Elektronik', 'Dekorasyon', 'Moda & Kozmetik', 'Market', 'Sağlık', 
      'Seyahat', 'Yeme-İçme', 'Yurt Dışı', 'Diğer'
    ];
    
    // Select initial category or default to Market
    String selectedCategory = categories.contains(source?.getStringValue('category')) 
        ? source!.getStringValue('category') 
        : categories[8]; // 'Market'

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(source == null ? 'Yeni Kaynak Ekle' : 'Kaynağı Düzenle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    hint: 'Seçenekleri görmek ve değiştirmek için çift tıklayın',
                    child: DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Kategori Seçimi',
                        border: OutlineInputBorder(),
                      ),
                      items: categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          if (val != null) selectedCategory = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Kaynak Adı',
                      hintText: 'Örn: GetKampania Market',
                    ),
                    maxLength: 100,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Tarama URL (Kategori Linki)',
                      hintText: 'https://...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final url = urlController.text.trim();
                  if (name.isEmpty || url.isEmpty) return;

                  try {
                    final body = {
                      'name': name,
                      'url': url,
                      'category': selectedCategory,
                    };

                    if (source == null) {
                      await PocketBaseService.client.collection('campaign_sources').create(body: body);
                    } else {
                      await PocketBaseService.client.collection('campaign_sources').update(source.id, body: body);
                    }
                    
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kaynak başarıyla kaydedildi.')),
                      );
                    }
                    _fetchSources();
                  } catch (e) {
                    AppLogger.instance.error('Kaynak kaydedilemedi: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Hata: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _cleanExpiredCampaigns() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Temizlik Onayı'),
        content: const Text('Bitiş tarihi dün veya daha eski olan, ayrıca başlangıç/bitiş tarihi hiç girilmemiş tüm kampanyalar silinecek. Onaylıyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Temizle', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      int deletedCount = 0;
      int page = 1;
      
      final Map<String, int> trMonths = {
        'ocak': 1, 'şubat': 2, 'subat': 2, 'mart': 3, 'nisan': 4,
        'mayıs': 5, 'mayis': 5, 'may': 5, 'haziran': 6, 'temmuz': 7,
        'ağustos': 8, 'agustos': 8, 'eylül': 9, 'eylul': 9, 'ekim': 10,
        'kasım': 11, 'kasim': 11, 'aralık': 12, 'aralik': 12,
      };

      DateTime? parseTurkishDate(String text) {
        if (text.isEmpty) return null;
        text = text.trim().toLowerCase();
        // remove extra spaces
        final parts = text.split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          final day = int.tryParse(parts[0]);
          final monthStr = parts[1];
          final year = int.tryParse(parts[2]);
          if (day != null && year != null) {
             final month = trMonths[monthStr] ?? int.tryParse(monthStr);
             if (month != null) {
               return DateTime(year, month, day);
             }
          }
        } else if (parts.length == 1) {
           // Maybe ISO format?
           return DateTime.tryParse(text);
        }
        return null;
      }

      while (true) {
        final result = await PocketBaseService.client.collection('campaigns').getList(
          page: page,
          perPage: 100,
        );

        if (result.items.isEmpty) break;

        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day); // 00:00:00 today

        for (final camp in result.items) {
          final campStart = camp.getStringValue('camp_start');
          final campEnd = camp.getStringValue('camp_end');

          bool shouldDelete = false;

          if (campStart.trim().isEmpty && campEnd.trim().isEmpty) {
            shouldDelete = true;
          } else if (campEnd.trim().isNotEmpty) {
            final endDate = parseTurkishDate(campEnd);
            if (endDate != null) {
              if (endDate.isBefore(todayStart)) {
                shouldDelete = true;
              }
            } else {
              // Could not parse the date, leave it alone to be safe
            }
          }

          if (shouldDelete) {
            try {
              await PocketBaseService.client.collection('campaigns').delete(camp.id);
              deletedCount++;
            } catch (e) {
              AppLogger.instance.error('Kampanya silinirken hata: ${camp.id} - $e');
            }
          }
        }
        page++; 
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Temizlik tamamlandı. Toplam $deletedCount kampanya silindi.')),
        );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Hata oluştu: $e')),
         );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kampanya Kaynakları')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Semantics(
              button: true,
              child: ElevatedButton.icon(
                onPressed: _cleanExpiredCampaigns,
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Tarihi Geçenleri Temizle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    itemCount: _sources.length,
                    itemBuilder: (context, index) {
                      final source = _sources[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.link)),
                        title: Text("${source.getStringValue('name')} [${source.getStringValue('category').isEmpty ? 'Kategori Seçilmemiş' : source.getStringValue('category')}]"),
                        subtitle: Text(source.getStringValue('url')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit), 
                              onPressed: () => _showSourceDialog(source),
                              tooltip: 'Düzenle',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Sil',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Kaynağı Sil'),
                                    content: const Text('Bu kaynağı silmek istediğinize emin misiniz? (Bot artık bu adresi taramayacaktır)'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await PocketBaseService.client.collection('campaign_sources').delete(source.id);
                                  _fetchSources();
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSourceDialog(),
        tooltip: 'Yeni Kaynak Ekle',
        child: const Icon(Icons.add),
      ),
    );
  }
}
