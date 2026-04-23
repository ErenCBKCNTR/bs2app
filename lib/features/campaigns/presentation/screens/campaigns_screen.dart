import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:blind_social/features/campaigns/presentation/screens/campaign_detail_screen.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  List<RecordModel> _allCachedCampaigns = [];
  List<RecordModel> _campaigns = [];
  bool _isLoading = true;
  String _selectedCategory = 'Tümü';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'Tümü', 'Akaryakıt', 'Araç', 'E-Ticaret', 'Eğitim & Kırtasiye', 'Eğlence', 
    'Elektronik', 'Dekorasyon', 'Moda & Kozmetik', 'Market', 'Sağlık', 
    'Seyahat', 'Yeme-İçme', 'Yurt Dışı', 'Diğer', 'Kredi Kartı', 'Rehber'
  ];

  @override
  void initState() {
    super.initState();
    _fetchCampaigns();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCampaigns({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_campaigns_data');
      final cachedTime = prefs.getInt('cached_campaigns_time') ?? 0;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      // 12 hours cache
      final isCacheValid = (now - cachedTime) < (12 * 60 * 60 * 1000); 

      if (!forceRefresh && isCacheValid && cachedData != null) {
        List<dynamic> jsonList = jsonDecode(cachedData);
        _allCachedCampaigns = jsonList.map((e) => RecordModel.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        final records = await PocketBaseService.client.collection('campaigns').getFullList(
          expand: 'source_id',
          sort: '-created',
        );
        _allCachedCampaigns = records;
        
        final jsonList = records.map((r) => r.toJson()).toList();
        prefs.setString('cached_campaigns_data', jsonEncode(jsonList));
        prefs.setInt('cached_campaigns_time', now);
      }
      
      _applyLocalFilters();
    } catch (e) {
      AppLogger.instance.error('Kampanyalar yüklenemedi: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyLocalFilters() {
    if (!mounted) return;
    
    List<RecordModel> filtered = _allCachedCampaigns;
    
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        final title = c.getStringValue('title').toLowerCase();
        final duration = c.getStringValue('duration_text').toLowerCase();
        final brandsList = c.getDataValue<List<dynamic>>('brands_json');
        final brandsStr = brandsList.join(" ").toLowerCase();
        
        return title.contains(q) || duration.contains(q) || brandsStr.contains(q);
      }).toList();
    }
    
    if (_selectedCategory != 'Tümü') {
      filtered = filtered.where((c) => c.getStringValue('category') == _selectedCategory).toList();
    }
    
    setState(() {
      _campaigns = filtered;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Güncel Kampanyalar'),
      ),
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! > 0) {
              // Swipe Right (Önceki kategori)
              int currentIndex = _categories.indexOf(_selectedCategory);
              if (currentIndex > 0) {
                _changeCategory(_categories[currentIndex - 1]);
              }
            } else if (details.primaryVelocity! < 0) {
              // Swipe Left (Sonraki kategori)
              int currentIndex = _categories.indexOf(_selectedCategory);
              if (currentIndex < _categories.length - 1) {
                _changeCategory(_categories[currentIndex + 1]);
              }
            }
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Semantics(
                  button: true,
                  hint: 'Toplam ${_allCachedCampaigns.length} kampanya arasında aramak için tıklayın',
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                      _applyLocalFilters();
                    },
                    decoration: InputDecoration(
                      hintText: 'Aramak istediğiniz markayı girin...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _applyLocalFilters();
                            },
                          ) 
                        : null,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          _changeCategory(cat);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _campaigns.isEmpty
                        ? const Center(child: Text('Henüz kampanya bulunamadı.'))
                        : _buildCampaignGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _changeCategory(String cat) {
    setState(() => _selectedCategory = cat);
    _applyLocalFilters();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$cat kategorisini incelemektesiniz.'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildCampaignGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.78,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _campaigns.length,
      itemBuilder: (context, index) {
        final campaign = _campaigns[index];
        final sourceName = campaign.expand['source_id']?.first.getStringValue('name') ?? 'Genel';
        final title = campaign.getStringValue('title');
        final imageUrl = campaign.getStringValue('image_url');
        final duration = campaign.getStringValue('duration_text');

        return Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CampaignDetailScreen(
                    campaigns: _campaigns,
                    initialIndex: index,
                  ),
                ),
              );

              if (result != null && result is String) {
                // Return from detail screen with a specific brand name to search
                _searchController.text = result;
                setState(() => _searchQuery = result);
                _fetchCampaigns();
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.white,
                    child: imageUrl.isNotEmpty 
                      ? Image.network(
                          imageUrl, 
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                        )
                      : const Icon(Icons.campaign_outlined, size: 40, color: Colors.grey),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sourceName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: Theme.of(context).primaryColor,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (duration.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            duration,
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
