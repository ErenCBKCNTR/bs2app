import 'package:shared_preferences/shared_preferences.dart';

class FavoriteStationsService {
  static const String _favoritesKey = 'favorite_stations';
  static const String _isFavoritesViewActiveKey = 'is_favorites_view_active';

  // Singleton pattern
  static final FavoriteStationsService _instance = FavoriteStationsService._internal();
  factory FavoriteStationsService() => _instance;
  FavoriteStationsService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  List<String> getFavoriteStationNames() {
    return _prefs?.getStringList(_favoritesKey) ?? [];
  }

  Future<void> toggleFavorite(String stationName) async {
    if (_prefs == null) await init();
    
    final favorites = getFavoriteStationNames().toList();
    if (favorites.contains(stationName)) {
      favorites.remove(stationName);
    } else {
      favorites.add(stationName);
    }
    
    await _prefs?.setStringList(_favoritesKey, favorites);
  }

  bool isFavorite(String stationName) {
    return getFavoriteStationNames().contains(stationName);
  }

  bool get isFavoritesViewActive {
    return _prefs?.getBool(_isFavoritesViewActiveKey) ?? false;
  }

  Future<void> setFavoritesViewActive(bool active) async {
    if (_prefs == null) await init();
    await _prefs?.setBool(_isFavoritesViewActiveKey, active);
  }
}
