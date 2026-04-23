import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';

class BrandManagementScreen extends StatefulWidget {
  const BrandManagementScreen({super.key});

  @override
  State<BrandManagementScreen> createState() => _BrandManagementScreenState();
}

class _BrandManagementScreenState extends State<BrandManagementScreen> {
  List<RecordModel> _brands = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBrands();
  }

  Future<void> _fetchBrands() async {
    try {
      final records = await PocketBaseService.client.collection('brands').getFullList(
        sort: '-created',
      );
      if (mounted) {
        setState(() {
          _brands = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.instance.error('Markalar yüklenemedi: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showBrandDialog([RecordModel? brand]) {
    final nameController = TextEditingController(text: brand?.getStringValue('name'));
    final urlController = TextEditingController(text: brand?.getStringValue('campaign_url'));
    String selectedCategory = brand?.getStringValue('category') ?? 'Other';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(brand == null ? 'Yeni Marka Ekle' : 'Markayı Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Marka Adı'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: ['Food', 'Transport', 'Finance', 'Clothing', 'Cosmetics', 'Other']
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) selectedCategory = val;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Kampanya Kaynak URL (Bot için)',
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
              if (name.isEmpty) return;

              try {
                final body = {
                  'name': name,
                  'category': selectedCategory,
                  'campaign_url': url,
                };

                if (brand == null) {
                  await PocketBaseService.client.collection('brands').create(body: body);
                } else {
                  await PocketBaseService.client.collection('brands').update(brand.id, body: body);
                }
                
                Navigator.pop(context);
                _fetchBrands();
              } catch (e) {
                AppLogger.instance.error('Marka kaydedilemedi: $e');
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marka & Kaynak Yönetimi')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _brands.length,
              itemBuilder: (context, index) {
                final brand = _brands[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.business)),
                  title: Text(brand.getStringValue('name')),
                  subtitle: Text('${brand.getStringValue('category')} - ${brand.getStringValue('campaign_url')}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showBrandDialog(brand)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Markayı Sil'),
                              content: const Text('Bu markayı ve markaya ait tüm kampanyaları silmek istediğinize emin misiniz?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await PocketBaseService.client.collection('brands').delete(brand.id);
                            _fetchBrands();
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBrandDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
