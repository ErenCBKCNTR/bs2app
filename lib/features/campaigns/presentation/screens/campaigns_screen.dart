import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
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
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Food',
    'Transport',
    'Finance',
    'Clothing',
    'Cosmetics',
    'Other'
  ];

  String _getCategoryTurkish(String cat) {
    switch (cat) {
      case 'All': return 'Tümü';
      case 'Food': return 'Gıda';
      case 'Transport': return 'Ulaşım';
      case 'Finance': return 'Finans';
      case 'Clothing': return 'Giyim';
      case 'Cosmetics': return 'Kozmetik';
      default: return 'Diğer';
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCampaigns();
  }

  Future<void> _fetchCampaigns() async {
    setState(() => _isLoading = true);
    try {
      String filter = 'is_active = true';
      if (_selectedCategory != 'All') {
        filter += ' && source_id.category = "$_selectedCategory"';
      }
      if (_searchQuery.isNotEmpty) {
        // Hem başlıkta, hem kaynak adında hem de ilintili marka isimlerinde ara
        filter += ' && (title ~ "$_searchQuery" || source_id.name ~ "$_searchQuery" || brand_ids.name ~ "$_searchQuery")';
      }

      final records = await PocketBaseService.client.collection('campaigns').getFullList(
        filter: filter,
        expand: 'source_id,brand_ids',
        sort: '-created',
      );
      
      if (mounted) {
        setState(() {
          _campaigns = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.instance.error('Kampanyalar yüklenemedi: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Güncel Kampanyalar'),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _campaigns.isEmpty
                    ? const Center(child: Text('Kampanya bulunamadı.'))
                    : _buildCampaignGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      child: Column(
        children: [
          TextField(
            onChanged: (val) {
              setState(() => _searchQuery = val);
              _fetchCampaigns();
            },
            decoration: InputDecoration(
              hintText: 'Marka veya kampanya ara...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_getCategoryTurkish(cat)),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                      _fetchCampaigns();
                    },
                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.82,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _campaigns.length,
      itemBuilder: (context, index) {
        final campaign = _campaigns[index];
        final source = campaign.expand['source_id']?.first;
        final brands = campaign.expand['brand_ids'] ?? [];
        
        // Gösterilecek ana isim: Varsa ilk marka, yoksa kaynak adı
        final displayName = (brands.isNotEmpty ? brands.first.getStringValue('name') : source?.getStringValue('name')) ?? 'Kampanya';
        final title = campaign.getStringValue('title');
        
        final campaignImage = campaign.getStringValue('image_url');

        return Card(
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CampaignDetailScreen(campaign: campaign),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.white,
                    child: campaignImage.isNotEmpty 
                      ? Image.network(
                          campaignImage, 
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                        )
                      : const Icon(Icons.campaign_outlined, size: 40, color: Colors.grey),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: Theme.of(context).primaryColor,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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
