import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blind_social/core/widgets/expandable_text.dart';

class CampaignDetailScreen extends StatefulWidget {
  final RecordModel campaign;

  const CampaignDetailScreen({super.key, required this.campaign});

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final campaign = widget.campaign;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kampanya Detayı'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sourceName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Kampanya Tarihleri
                  if (campStart.isNotEmpty) ...[
                    const Text('KAMPANYA KATILIMI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDateBadge('Başlangıç', campStart, Colors.blue),
                        if (campEnd.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildDateBadge('Bitiş', campEnd, Colors.red),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Kazanç Kullanım Tarihleri
                  if (usageStart.isNotEmpty) ...[
                    const Text('KAZANCIN KULLANIMI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDateBadge('Başlangıç', usageStart, Colors.orange),
                        if (usageEnd.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildDateBadge('Bitiş', usageEnd, Colors.deepOrange),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Markalar (Varsa)
                  if (brandsList.isNotEmpty) ...[
                    const Text('Dahil Markalar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: brandsList.map((b) => Chip(label: Text(b.toString(), style: const TextStyle(fontSize: 12)))).toList(),
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
                    const Text('Kampanya Koşulları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      label: const Text('Kampanya Sayfasına Git'),
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
    return Container(
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
            date,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.instance.error('URL açılamadı: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı açılamadı.')),
        );
      }
    }
  }
}
