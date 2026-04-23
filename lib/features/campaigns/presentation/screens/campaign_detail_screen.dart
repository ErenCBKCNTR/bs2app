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
    final source = campaign.expand['source_id']?.first;
    final brands = campaign.expand['brand_ids'] ?? [];
    
    final title = campaign.getStringValue('title');
    final description = campaign.getStringValue('description');
    final imageUrl = campaign.getStringValue('image_url');
    final sourceUrl = campaign.getStringValue('source_url');
    
    // Tarihler
    final startDateStr = campaign.getStringValue('start_date');
    final endDateStr = campaign.getStringValue('end_date');
    
    final displayStart = startDateStr.isNotEmpty 
        ? startDateStr.split(' ')[0] 
        : 'Belirtilmedi';
    final displayEnd = endDateStr.isNotEmpty 
        ? endDateStr.split(' ')[0] 
        : 'Süresiz';

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
                  // Kaynak ve Markalar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          source?.getStringValue('name') ?? 'Genel Kaynak',
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

                  // Tarih Kutuları
                  Row(
                    children: [
                      _buildDateBox('BAŞLANGIÇ', displayStart, Icons.calendar_today_outlined, Colors.blue),
                      const SizedBox(width: 12),
                      _buildDateBox('BİTİŞ', displayEnd, Icons.event_available, Colors.red),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // İlgili Markalar (Chips)
                  if (brands.isNotEmpty) ...[
                    const Text(
                      'İlgili Markalar',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      children: brands.map<Widget>((brand) {
                        return Chip(
                          label: Text(
                            brand.getStringValue('name'),
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Divider(),
                  const SizedBox(height: 16),

                  // Açıklama
                  const Text(
                    'Kampanya Hakkında',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  ExpandableText(
                    text: description,
                    maxLines: 5,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Buton
                  if (sourceUrl.isNotEmpty)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Kampanya Detayına Git'),
                      onPressed: () => _launchURL(sourceUrl),
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

  Widget _buildDateBox(String label, String date, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              date,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
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
