
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
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Semantics(
                      label: "Kaydedilen Canlı Yayınlar",
                      button: true,
                      hint: "Önceden kaydettiğiniz yayınları görmek için çift dokunun",
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SavedRecordingsScreen()),
                          );
                        },
                        icon: const Icon(Icons.album, color: Colors.white, size: 18),
                        label: const Text(
                          'Kayıtlar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: Colors.blueAccent.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: Semantics(
                      label: _isFavoritesView ? "Tüm Kanallar" : "Favori Kanallar",
                      button: true,
                      child: ElevatedButton.icon(
                        onPressed: _toggleFavoritesView,
                        icon: Icon(
                          _isFavoritesView ? Icons.list : Icons.favorite, 
                          color: Colors.white, 
                          size: 18
                        ),
                        label: Text(
                          _isFavoritesView ? 'Tüm Kanallar' : 'Favoriler',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFavoritesView ? Colors.teal : Colors.deepOrange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: (_isFavoritesView ? Colors.teal : Colors.deepOrange).withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
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
