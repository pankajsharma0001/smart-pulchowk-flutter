import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/core/models/search_result.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:flutter/material.dart';

class GlobalSearchService {
  final ApiService _api = ApiService();

  Future<List<SearchResult>> searchAll(String query) async {
    if (query.trim().isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();

    // Call all search sources in parallel
    final results = await Future.wait([
      _searchNotices(normalizedQuery),
      _searchBooks(normalizedQuery),
      _searchLostFound(normalizedQuery),
      _searchEvents(normalizedQuery),
      _searchLocations(normalizedQuery),
    ]);

    // Flatten results
    return results.expand((x) => x).toList();
  }

  Future<List<SearchResult>> _searchNotices(String query) async {
    try {
      final notices = await _api.getNotices(search: query, limit: 10);
      return notices
          .map(
            (n) => SearchResult(
              id: 'notice_${n.id}',
              title: n.title,
              subtitle: n.categoryDisplay,
              type: SearchResultType.notice,
              icon: n.icon,
              color: n.color,
              date: n.createdAt,
              originalObject: n,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<SearchResult>> _searchBooks(String query) async {
    try {
      final response = await _api.getBookListings(
        filters: BookFilters(search: query, limit: 10),
      );
      if (response == null) return [];
      return response.listings
          .map(
            (b) => SearchResult(
              id: 'book_${b.id}',
              title: b.title,
              subtitle: b.author,
              type: SearchResultType.book,
              icon: Icons.book_rounded,
              color: const Color(0xFF6366F1),
              imageUrl: b.primaryImageUrl,
              originalObject: b,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<SearchResult>> _searchLostFound(String query) async {
    try {
      final items = await _api.getLostFoundItems(q: query);
      return items
          .take(10)
          .map(
            (i) => SearchResult(
              id: 'lostfound_${i.id}',
              title: i.title,
              subtitle: i.itemType.name.toUpperCase(),
              type: SearchResultType.lostFound,
              icon: Icons.search_rounded,
              color: const Color(0xFF8B5CF6),
              imageUrl: i.images.isNotEmpty ? i.images.first.imageUrl : null,
              date: i.createdAt,
              originalObject: i,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<SearchResult>> _searchEvents(String query) async {
    try {
      final events = await _api.getAllEvents();
      return events
          .where(
            (e) =>
                e.title.toLowerCase().contains(query) ||
                (e.description?.toLowerCase().contains(query) ?? false),
          )
          .take(10)
          .map(
            (e) => SearchResult(
              id: 'event_${e.id}',
              title: e.title,
              subtitle: e.club?.name ?? 'University Event',
              type: SearchResultType.event,
              icon: Icons.event_rounded,
              color: const Color(0xFFEC4899),
              imageUrl: e.bannerUrl,
              date: e.eventStartTime,
              originalObject: e,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<SearchResult>> _searchLocations(String query) async {
    try {
      final String jsonStr = await rootBundle.loadString(
        'assets/geojson/pulchowk.json',
      );
      final Map<String, dynamic> geojson = jsonDecode(jsonStr);
      final List<dynamic> features = geojson['features'] ?? [];
      final results = <SearchResult>[];

      for (var feature in features) {
        final props = feature['properties'] ?? {};
        final title = (props['description'] ?? props['title'] ?? '').toString();
        final about = props['about']?.toString() ?? '';

        if (title.toLowerCase().contains(query) ||
            about.toLowerCase().contains(query)) {
          results.add(
            SearchResult(
              id: 'loc_${title.hashCode}',
              title: title,
              subtitle: about.length > 50
                  ? '${about.substring(0, 50)}...'
                  : about,
              type: SearchResultType.location,
              icon: Icons.location_on_rounded,
              color: const Color(0xFF10B981),
              originalObject: feature,
            ),
          );
        }
        if (results.length >= 10) break;
      }
      return results;
    } catch (e) {
      return [];
    }
  }
}
