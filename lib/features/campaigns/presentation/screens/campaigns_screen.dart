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
      String filter = '';
      if (_searchQuery.isNotEmpty) {
        filter = 'title ~ "$_searchQuery" || duration_text ~ "$_searchQuery"';
      }

      final records = await PocketBaseService.client.collection('campaigns').getFullList(
        filter: filter,
        expand: 'source_id',
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
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _fetchCampaigns();
              },
              decoration: InputDecoration(
                hintText: 'Kampanya ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _campaigns.isEmpty
                    ? const Center(child: Text('Henüz kampanya bulunamadı.'))
                    : _buildCampaignGrid(),
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
