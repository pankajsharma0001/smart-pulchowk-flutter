import 'package:flutter/material.dart';

enum SearchResultType { notice, event, book, lostFound, location }

class SearchResult {
  final String id;
  final String title;
  final String subtitle;
  final SearchResultType type;
  final IconData icon;
  final Color color;
  final String? imageUrl;
  final DateTime? date;
  final dynamic originalObject; // The source object (Notice, ClubEvent, etc.)

  SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.icon,
    required this.color,
    this.imageUrl,
    this.date,
    this.originalObject,
  });
}
