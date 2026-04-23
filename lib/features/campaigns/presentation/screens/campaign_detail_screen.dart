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
    final durationText = campaign.getStringValue('duration_text');
    final usageText = campaign.getStringValue('usage_text');
    final originalUrl = campaign.getStringValue('original_url');
    
    // JSON verilerini işle
    final detailsMap = campaign.getDataValue<Map<String, dynamic>>('details_json');
    final brandsList = campaign.getDataValue<List<dynamic>>('brands_json');
    final conditionsList = campaign.getDataValue<List<dynamic>>('conditions_json');

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kampanya Detayı'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kampanya Görseli
            if (imageUrl.isNotEmpty)
              Container(
                width: double.infinity,
                height: 250,
                color: Colors.white,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kaynak Etiketi
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sourceName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Güncel Kampanya',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Başlık
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tarih/Süre Bilgisi
                  if (durationText.isNotEmpty)
                    _buildInfoBox('KAMPANYA KATILIMI', durationText, Icons.calendar_today_outlined, Colors.blue),
                  
                  if (usageText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoBox('KAZANCIN KULLANIMI', usageText, Icons.stars_rounded, Colors.orange),
                  ],
                  
                  const SizedBox(height: 24),

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
                  if (originalUrl.isNotEmpty)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Kampanya Sayfasına Git'),
                      onPressed: () => _launchURL(originalUrl),
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

  Widget _buildInfoBox(String label, String text, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
