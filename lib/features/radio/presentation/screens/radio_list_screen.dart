
import 'package:flutter/material.dart';
import '../../data/radio_stations.dart';
import '../../services/favorite_stations_service.dart';
import 'radio_player_screen.dart';
import 'saved_recordings_screen.dart';

class RadioListScreen extends StatefulWidget {
  const RadioListScreen({super.key});

  @override
  State<RadioListScreen> createState() => _RadioListScreenState();
}

class _RadioListScreenState extends State<RadioListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FavoriteStationsService _favoriteService = FavoriteStationsService();
  List<RadioStation> _filteredStations = radioStations;
  bool _isFavoritesView = false;

  @override
  void initState() {
    super.initState();
    _initFavorites();
  }

  Future<void> _initFavorites() async {
    await _favoriteService.init();
    setState(() {
      _isFavoritesView = _favoriteService.isFavoritesViewActive;
    });
    _filterStations(_searchController.text);
  }

  void _filterStations(String query) {
    setState(() {
      _filteredStations = radioStations.where((station) {
        final matchesSearch = station.name.toLowerCase().contains(query.toLowerCase());
        final matchesFavorite = !_isFavoritesView || _favoriteService.isFavorite(station.name);
        return matchesSearch && matchesFavorite;
      }).toList();
    });
  }

  Future<void> _toggleFavoritesView() async {
    final newState = !_isFavoritesView;
    await _favoriteService.setFavoritesViewActive(newState);
    setState(() {
      _isFavoritesView = newState;
    });
    _filterStations(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canlı Radyo'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterStations,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Kanal Ara...',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 1,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SavedRecordingsScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        child: Semantics(
                          label: "Kaydedilen Canlı Yayınlar",
                          excludeSemantics: true,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.album, size: 20),
                              SizedBox(height: 4),
                              Text(
                                'Kayıtlar',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: ElevatedButton(
                        onPressed: _toggleFavoritesView,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFavoritesView ? Colors.teal : Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        child: Semantics(
                          label: _isFavoritesView ? "Tüm Kanallar" : "Favori Kanallar",
                          excludeSemantics: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_isFavoritesView ? Icons.list : Icons.favorite, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                _isFavoritesView ? 'Tüm Kanallar' : 'Favoriler',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                itemCount: _filteredStations.length,
                itemBuilder: (context, index) {
                  final station = _filteredStations[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      child: const Icon(Icons.radio, color: Colors.blueAccent),
                    ),
                    title: Text(station.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white24),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RadioPlayerScreen(
                            initialIndex: radioStations.indexOf(station),
                            stations: radioStations,
                          ),
                        ),
                      );
                      // Refresh favorites list if we came back from player screen
                      _filterStations(_searchController.text);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
