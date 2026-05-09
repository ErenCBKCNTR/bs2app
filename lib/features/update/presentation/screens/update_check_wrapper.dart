import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class UpdateCheckWrapper extends StatefulWidget {
  final Widget child;
  const UpdateCheckWrapper({super.key, required this.child});

  @override
  State<UpdateCheckWrapper> createState() => _UpdateCheckWrapperState();
}

class _UpdateCheckWrapperState extends State<UpdateCheckWrapper> {
  bool _isLoading = true;
  bool _needsUpdate = false;
  String _apkUrl = '';
  String _currentVersion = '';
  String _dbVersion = '';
  
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';

  final FocusNode _headerFocusNode = FocusNode();

  @override
  void dispose() {
    _headerFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version; // e.g., "1.4.0" (without the build number)
      
      final records = await PocketBaseService.client.collection('app_settings').getList(page: 1, perPage: 1);
      
      if (records.items.isNotEmpty) {
        final setting = records.items.first;
        final dbVersion = setting.getStringValue('current_version');
        final apkUrl = setting.getStringValue('apk_url');
        
        AppLogger.instance.info("Güncelleme Kontrolü: Cihaz sürümü = $currentVersion, DB Sürümü = $dbVersion");
        
        if (dbVersion.isNotEmpty && _compareVersions(currentVersion, dbVersion) < 0) {
          if (mounted) {
            setState(() {
              _needsUpdate = true;
              _apkUrl = apkUrl;
              _currentVersion = currentVersion;
              _dbVersion = dbVersion;
              _isLoading = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _headerFocusNode.requestFocus();
            });
          }
          return;
        }
      }
    } catch (e) {
      AppLogger.instance.error("Update check failed: $e");
      debugPrint("Update check failed: $e");
    }
    
    if (mounted) {
      setState(() {
        _needsUpdate = false;
        _isLoading = false;
      });
    }
  }

  // Returns < 0 if v1 < v2
  int _compareVersions(String v1, String v2) {
    List<int> p1 = v1.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    List<int> p2 = v2.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    
    for (int i = 0; i < p1.length || i < p2.length; i++) {
      int p1v = i < p1.length ? p1[i] : 0;
      int p2v = i < p2.length ? p2[i] : 0;
      if (p1v < p2v) return -1;
      if (p1v > p2v) return 1;
    }
    return 0;
  }

  Future<void> _startDownload() async {
    if (_apkUrl.isEmpty) return;

    if (!Platform.isAndroid) {
      // iOS and Web will still use url launcher
      final Uri url = Uri.parse(_apkUrl);
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint("Guncelleme linki acilamadi: $e");
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'İndiriliyor...';
    });

    try {
      final dir = await getExternalStorageDirectory();
      final filePath = '${dir?.path}/update_$_dbVersion.apk';

      final dio = Dio();
      await dio.download(
        _apkUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
              _downloadStatus = 'İndiriliyor: %${(_downloadProgress * 100).toStringAsFixed(0)}';
            });
          }
        },
      );

      setState(() {
        _downloadStatus = 'İndirme tamamlandı! Kurulum başlatılıyor...';
      });

      final result = await OpenFilex.open(filePath);
      
      if (result.type != ResultType.done) {
        setState(() {
          _downloadStatus = 'Kurulum başlatılamadı: ${result.message}';
          _isDownloading = false;
        });
      }
    } catch (e) {
      AppLogger.instance.error("İndirme hatası: $e");
      setState(() {
        _isDownloading = false;
        _downloadStatus = 'İndirme başarısız oldu. Lütfen tekrar deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_needsUpdate) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Güncelleme Gerekli"),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Focus(
                    focusNode: _headerFocusNode,
                    child: const Text(
                      "Yeni Bir Sürüm Var!",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Şu anda kullandığınız sürüm: $_currentVersion\nGüncel sürüm: $_dbVersion\n\nUygulamayı kullanmaya devam etmek için lütfen en güncel sürüme güncelleyin.\n\nÖNEMLİ: Yeni uygulamayı kurmadan önce yaşanabilecek çakışmaları önlemek için lütfen eski uygulamayı cihazınızdan kaldırın.",
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                if (_isDownloading)
                  Column(
                    children: [
                      LinearProgressIndicator(value: _downloadProgress),
                      const SizedBox(height: 8),
                      Text(
                        _downloadStatus,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _startDownload,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Uygulamayı Güncelle", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (_downloadStatus.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          _downloadStatus,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        )
                      ]
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
