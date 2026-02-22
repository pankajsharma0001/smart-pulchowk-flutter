import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';

/// A model representing a map location category.
class MapCategory {
  final String id; // Matches icon type key, e.g. 'food', 'library'
  final String label;
  final IconData icon;
  final Color color;

  const MapCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// All available map categories, including the "All" wildcard.
const List<MapCategory> kMapCategories = [
  MapCategory(
    id: 'all',
    label: 'All',
    icon: Icons.apps_rounded,
    color: Color(0xFF6366F1),
  ),
  MapCategory(
    id: 'department',
    label: 'Departments',
    icon: Icons.school_rounded,
    color: Color(0xFF3B82F6),
  ),
  MapCategory(
    id: 'food',
    label: 'Food',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFF59E0B),
  ),
  MapCategory(
    id: 'lab',
    label: 'Labs',
    icon: Icons.science_rounded,
    color: Color(0xFF6366F1),
  ),
  MapCategory(
    id: 'hostel',
    label: 'Hostels',
    icon: Icons.hotel_rounded,
    color: Color(0xFF14B8A6),
  ),
  MapCategory(
    id: 'library',
    label: 'Library',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF8B5CF6),
  ),
  MapCategory(
    id: 'sports',
    label: 'Sports',
    icon: Icons.sports_soccer_rounded,
    color: Color(0xFF22C55E),
  ),
  MapCategory(
    id: 'gym',
    label: 'Gym',
    icon: Icons.fitness_center_rounded,
    color: Color(0xFF22C55E),
  ),
  MapCategory(
    id: 'office',
    label: 'Offices',
    icon: Icons.business_rounded,
    color: Color(0xFF64748B),
  ),
  MapCategory(
    id: 'parking',
    label: 'Parking',
    icon: Icons.local_parking_rounded,
    color: Color(0xFF6B7280),
  ),
  MapCategory(
    id: 'clinic',
    label: 'Clinic',
    icon: Icons.local_hospital_rounded,
    color: Color(0xFFEF4444),
  ),
  MapCategory(
    id: 'bank',
    label: 'Bank/ATM',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF2563EB),
  ),
  MapCategory(
    id: 'toilet',
    label: 'Washroom',
    icon: Icons.wc_rounded,
    color: Color(0xFF92400E),
  ),
];

/// Horizontally scrollable filter bar for campus map categories.
class CategoryFilterBar extends StatelessWidget {
  final String selectedCategoryId;
  final ValueChanged<String> onCategorySelected;

  const CategoryFilterBar({
    super.key,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kMapCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = kMapCategories[index];
          final isActive = cat.id == selectedCategoryId;

          return GestureDetector(
            onTap: () {
              haptics.selectionClick();
              onCategorySelected(cat.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? cat.color.withValues(alpha: isDark ? 0.25 : 0.12)
                    : (isDark
                          ? const Color(0xFF1E293B).withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.9)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? cat.color.withValues(alpha: isDark ? 0.6 : 0.4)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06)),
                  width: isActive ? 1.5 : 1,
                ),
                boxShadow: isActive
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat.icon,
                    size: 14,
                    color: isActive
                        ? cat.color
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.black54),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? cat.color
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
