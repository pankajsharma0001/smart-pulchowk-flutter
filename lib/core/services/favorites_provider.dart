import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/services/storage_service.dart';
import 'package:smart_pulchowk/core/constants/app_constants.dart';

class FavoritesProvider extends ChangeNotifier {
  Set<int> _favoriteClubIds = {};
  Set<int> _favoriteEventIds = {};
  bool _isInitialized = false;

  Set<int> get favoriteClubIds => _favoriteClubIds;
  Set<int> get favoriteEventIds => _favoriteEventIds;
  bool get isInitialized => _isInitialized;

  FavoritesProvider() {
    _loadFavorites();
  }

  static FavoritesProvider of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<InheritedFavoritesProvider>();
    assert(inherited != null, 'No InheritedFavoritesProvider found in context');
    return inherited!.notifier!;
  }

  Future<void> _loadFavorites() async {
    final clubs = StorageService.readCache(AppConstants.cacheFavoriteClubs);
    final events = StorageService.readCache(AppConstants.cacheFavoriteEvents);

    if (clubs is List) {
      _favoriteClubIds = clubs.cast<int>().toSet();
    }
    if (events is List) {
      _favoriteEventIds = events.cast<int>().toSet();
    }

    _isInitialized = true;
    notifyListeners();
  }

  bool isClubFavorite(int id) => _favoriteClubIds.contains(id);
  bool isEventFavorite(int id) => _favoriteEventIds.contains(id);

  Future<void> toggleClubFavorite(int id) async {
    if (_favoriteClubIds.contains(id)) {
      _favoriteClubIds.remove(id);
    } else {
      _favoriteClubIds.add(id);
    }
    notifyListeners();
    await StorageService.writeCache(
      AppConstants.cacheFavoriteClubs,
      _favoriteClubIds.toList(),
    );
  }

  Future<void> toggleEventFavorite(int id) async {
    if (_favoriteEventIds.contains(id)) {
      _favoriteEventIds.remove(id);
    } else {
      _favoriteEventIds.add(id);
    }
    notifyListeners();
    await StorageService.writeCache(
      AppConstants.cacheFavoriteEvents,
      _favoriteEventIds.toList(),
    );
  }

  Future<void> clearAll() async {
    _favoriteClubIds.clear();
    _favoriteEventIds.clear();
    notifyListeners();
    await StorageService.deleteCache(AppConstants.cacheFavoriteClubs);
    await StorageService.deleteCache(AppConstants.cacheFavoriteEvents);
  }
}

class InheritedFavoritesProvider extends InheritedNotifier<FavoritesProvider> {
  const InheritedFavoritesProvider({
    super.key,
    required super.notifier,
    required super.child,
  });
}
