import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:blind_social/core/utils/json_utils.dart';
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
  List<RecordModel> _campaigns = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _perPage = 20;

  String _selectedCategory = 'Tümü';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  final List<String> _categories = [
    'Tümü', 'Akaryakıt', 'Araç', 'E-Ticaret', 'Eğitim & Kırtasiye', 'Eğlence', 
    'Elektronik', 'Dekorasyon', 'Moda & Kozmetik', 'Market', 'Sağlık', 
    'Seyahat', 'Yeme-İçme', 'Yurt Dışı', 'Diğer', 'Kredi Kartı', 'Rehber'
  ];

  @override
  void initState() {
    super.initState();
    _fetchCampaigns(refresh: true);
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _fetchCampaigns();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCampaigns({bool refresh = false}) async {
    if (refresh) {
      if (mounted) {
        setState(() {
          _currentPage = 1;
          _isLoading = true;
          _hasMore = true;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingMore = true);
    }

    try {
      String filter = '';
      List<String> conditions = [];
      
      if (_selectedCategory != 'Tümü') {
        conditions.add('category = "$_selectedCategory"');
      }
      
      if (_searchQuery.isNotEmpty) {
        final safeQ = _searchQuery.replaceAll('"', '\\"');
        conditions.add('(title ~ "$safeQ" || duration_text ~ "$safeQ" || brands_json ~ "$safeQ")');
      }
      
      if (conditions.isNotEmpty) {
        filter = conditions.join(' && ');
      }

      final result = await PocketBaseService.client.collection('campaigns').getList(
        page: _currentPage,
        perPage: _perPage,
        expand: 'source_id',
        sort: '-created',
        filter: filter,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _campaigns = result.items;
          } else {
            _campaigns.addAll(result.items);
          }
          
          _hasMore = result.items.length == _perPage;
          if (_hasMore) {
            _currentPage++;
          }
          
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      AppLogger.instance.error('Kampanyalar yüklenemedi: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _searchQuery = val);
        _fetchCampaigns(refresh: true);
      }
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
          behavior: HitTestBehavior.opaque,
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
                  hint: 'Kampanyalar arasında aramak için tıklayın',
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
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
                              _onSearchChanged('');
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
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
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
    _fetchCampaigns(refresh: true);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$cat kategorisini incelemektesiniz.'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildCampaignGrid() {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
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
                      _onSearchChanged(result);
                    }
                  },
                  child: Semantics(
                    button: true,
                    label: '$title. $duration',
                    excludeSemantics: true,
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
                ),
              );
            },
          ),
        ),
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}
