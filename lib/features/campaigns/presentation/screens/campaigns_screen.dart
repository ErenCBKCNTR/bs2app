import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';

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
        filter += ' && brand_id.category = "$_selectedCategory"';
      }
      if (_searchQuery.isNotEmpty) {
        filter += ' && (title ~ "$_searchQuery" || brand_id.name ~ "$_searchQuery")';
      }

      final records = await PocketBaseService.client.collection('campaigns').getFullList(
        filter: filter,
        expand: 'brand_id',
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
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _campaigns.length,
      itemBuilder: (context, index) {
        final campaign = _campaigns[index];
        final brand = campaign.expand['brand_id']?.first;
        final brandName = brand?.getStringValue('name') ?? 'Marka';
        final title = campaign.getStringValue('title');
        final baseUrl = PocketBaseService.client.baseUrl;
        final logo = brand?.getStringValue('logo');
        final logoUrl = logo != null ? '$baseUrl/api/files/${brand!.collectionId}/${brand.id}/$logo' : null;

        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _showCampaignDetail(campaign, brandName),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: logoUrl != null 
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.network(logoUrl, fit: BoxFit.contain),
                        )
                      : const Icon(Icons.business, size: 50, color: Colors.grey),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brandName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCampaignDetail(RecordModel campaign, String brandName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brandName,
                    style: TextStyle(fontSize: 14, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    campaign.getStringValue('title'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 32),
                  Text(
                    campaign.getStringValue('description'),
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  if (campaign.getStringValue('source_url').isNotEmpty)
                    ElevatedButton(
                      onPressed: () {
                        // Launch URL logic
                      },
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      child: const Text('Kampanya Detayına Git'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
