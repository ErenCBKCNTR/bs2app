import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:blind_social/core/widgets/expandable_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blind_social/core/providers/localization_provider.dart';

class CampaignDetailScreen extends ConsumerStatefulWidget {
  final List<RecordModel>? campaigns;
  final int initialIndex;
  
  // Geriye dönük uyumluluk için optional yaptık
  final RecordModel? campaign;

  const CampaignDetailScreen({super.key, this.campaigns, this.initialIndex = 0, this.campaign});

  @override
  ConsumerState<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends ConsumerState<CampaignDetailScreen> {
  late PageController _pageController;
  late List<RecordModel> _campaignList;
  bool _expandedBrands = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    if (widget.campaigns != null && widget.campaigns!.isNotEmpty) {
      _campaignList = widget.campaigns!;
    } else if (widget.campaign != null) {
      _campaignList = [widget.campaign!];
    } else {
      _campaignList = [];
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _shareCampaign(RecordModel campaign, String finalUrl) {
    final lang = ref.read(localizationProvider);
    final title = campaign.getStringValue('title');
    final campStart = campaign.getStringValue('camp_start');
    final campEnd = campaign.getStringValue('camp_end');
    
    // Tarih kontrolü
    String startTxt = (campStart.isEmpty || campStart == '-') ? lang.unknown : campStart;
    String endTxt = (campEnd.isEmpty || campEnd == '-') ? lang.unknown : campEnd;

    String shareText = '📌 $title\n\n'
        '📅 Başlangıç: $startTxt\n'
        '📅 Bitiş: $endTxt\n\n';

    if (finalUrl.isNotEmpty) {
      shareText += '🔗 Link: $finalUrl\n\n';
    }
    
    shareText += '📱 Blind Social uygulaması aracılığıyla paylaşılmıştır';
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localizationProvider);
    if (_campaignList.isEmpty) return Scaffold(body: Center(child: Text("${lang.error}: ${lang.noCampaignFound}")));

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.taskDetail), // Or use a specific campaign detail string if I had one, taskDetail is close enough for breadcrumb style
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _campaignList.length,
        onPageChanged: (index) {
          setState(() {
            _expandedBrands = false;
          });
        },
        itemBuilder: (context, index) {
          final campaign = _campaignList[index];
          return _buildCampaignView(campaign);
        },
      ),
    );
  }

  Widget _buildCampaignView(RecordModel campaign) {
    final lang = ref.watch(localizationProvider);
    final sourceName = campaign.expand['source_id']?.first.getStringValue('name') ?? 'Genel';
    
    final title = campaign.getStringValue('title');
    final imageUrl = campaign.getStringValue('image_url');
    
    // Yeni tarih yapısı
    final campStart = campaign.getStringValue('camp_start');
    final campEnd = campaign.getStringValue('camp_end');
    final usageStart = campaign.getStringValue('usage_start');
    final usageEnd = campaign.getStringValue('usage_end');
    
    // Öncelik: Botun bulduğu asıl sayfa URL'si, yoksa getkampania detay linki
    final actualUrl = campaign.getStringValue('actual_source_url');
    final originalUrl = campaign.getStringValue('original_url');
    final finalUrl = actualUrl.isNotEmpty ? actualUrl : originalUrl;
    
    // JSON verilerini işle
    final detailsMap = campaign.getDataValue<Map<String, dynamic>>('details_json');
    final brandsList = campaign.getDataValue<List<dynamic>>('brands_json');
    final conditionsList = campaign.getDataValue<List<dynamic>>('conditions_json');

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (imageUrl.isNotEmpty)
                  Container(
                    width: double.infinity,
                    height: 250,
                    color: Colors.white,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 250,
                    color: Colors.grey[200],
                    child: const Icon(Icons.campaign, size: 80, color: Colors.grey),
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FloatingActionButton.small(
                    heroTag: "share_btn_${campaign.id}",
                    onPressed: () => _shareCampaign(campaign, finalUrl),
                    tooltip: lang.shareCampaign,
                    child: const Icon(Icons.share),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Kampanya Tarihleri
                  if (campStart.isNotEmpty || campEnd.isNotEmpty) ...[
                    const Text('KAMPANYA KATILIMI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDateBadge(lang.startDate, campStart, Colors.blue),
                        const SizedBox(width: 8),
                        _buildDateBadge(lang.endDate, campEnd, Colors.red),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Kazanç Kullanım Tarihleri
                  if (usageStart.isNotEmpty || usageEnd.isNotEmpty) ...[
                    const Text('KAZANCIN KULLANIMI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDateBadge(lang.startDate, usageStart, Colors.orange),
                        const SizedBox(width: 8),
                        _buildDateBadge(lang.endDate, usageEnd, Colors.deepOrange),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Markalar (Varsa)
                  if (brandsList.isNotEmpty) ...[
                    Text(lang.includedBrands, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: (_expandedBrands || brandsList.length < 5 
                          ? brandsList 
                          : brandsList.take(4).toList())
                        .map((b) => Semantics(
                            button: true,
                            label: '$b${lang.otherCampaignsForBrand}',
                            excludeSemantics: true,
                            child: ActionChip(
                              label: Text(b.toString(), style: const TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.pop(context, b.toString());
                              },
                            ),
                          ))
                        .toList(),
                    ),
                    if (brandsList.length >= 5)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _expandedBrands = !_expandedBrands;
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                        child: Text(_expandedBrands ? lang.showLess : '${lang.showAll} (${brandsList.length})'),
                      ),
                    const SizedBox(height: 24),
                  ],

                  // Detaylı Bölümler (Her biri için bir kart)
                  if (detailsMap.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    ...detailsMap.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(entry.value.toString(), style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[600])),
                        ],
                      ),
                    )),
                  ],

                  // Koşullar (Maddeler halinde)
                  if (conditionsList.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(lang.campaignConditions, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...conditionsList.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text(c.toString(), style: const TextStyle(fontSize: 13, height: 1.4))),
                        ],
                      ),
                    )),
                    const SizedBox(height: 24),
                  ],

                  // Buton
                  if (finalUrl.isNotEmpty)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: Text(lang.viewOnWeb),
                      onPressed: () => _launchURL(finalUrl),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBadge(String label, String date, Color color) {
    final lang = ref.watch(localizationProvider);
    String finalDateStr = (date.isEmpty || date == '-') ? lang.unknown : date;
    return Semantics(
      label: '$label tarihi $finalDateStr',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              finalDateStr,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final lang = ref.read(localizationProvider);
    final url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication).catchError((_) async {
        await launchUrl(url, mode: LaunchMode.platformDefault);
        return true;
      });
    } catch (e) {
      AppLogger.instance.error('URL açılamadı: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lang.error}: ${lang.tryAgain}')),
        );
      }
    }
  }
}
