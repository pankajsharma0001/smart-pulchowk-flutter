import 'dart:math';

import 'package:maplibre_gl/maplibre_gl.dart';

/// Offline campus router using Dijkstra's shortest path algorithm.
///
/// The walkway graph is hand-defined using real campus intersection coordinates.
/// Each node represents a walkway intersection/junction, and edges represent
/// walkable paths between them with Haversine distances.
class CampusRouter {
  CampusRouter._();

  // ── Walkway Graph Nodes ──────────────────────────────────────────────────
  // Key intersections on Pulchowk Campus walkways.
  // Format: [longitude, latitude]
  static const List<List<double>> _nodes = [
    // 0: Main Entrance gate
    [85.31775, 27.68137],
    // 1: Cave junction (near main entrance road)
    [85.31795, 27.68085],
    // 2: Dean Office road junction
    [85.31861, 27.68103],
    // 3: Architecture Dept junction
    [85.31831, 27.68045],
    // 4: Central road – near ICTC
    [85.31915, 27.68224],
    // 5: E Block / Workshop area
    [85.31840, 27.68060],
    // 6: Electrical Dept / Block C junction
    [85.31834, 27.68214],
    // 7: Fountain area / Central testing lab
    [85.31888, 27.68236],
    // 8: Badminton court junction (west)
    [85.31850, 27.68195],
    // 9: Continuing Education / Robotics area
    [85.31905, 27.68147],
    // 10: Machine Workshop / Parking junction
    [85.31907, 27.68127],
    // 11: Library / Clinic area
    [85.31943, 27.68158],
    // 12: Water Vending / ICT Building
    [85.31951, 27.68173],
    // 13: Om Stationery / Water Tap junction
    [85.31985, 27.68184],
    // 14: First Entrance / Siddhartha Bank junction
    [85.31946, 27.68207],
    // 15: Second Entrance
    [85.31960, 27.68215],
    // 16: Parking area (central)
    [85.31993, 27.68215],
    // 17: Helicopter Parking / Mech Dept
    [85.31969, 27.68229],
    // 18: Saraswati Mandir junction
    [85.31940, 27.68256],
    // 19: PI Chautari / D Block
    [85.31988, 27.68268],
    // 20: Civil Dept / Embark junction
    [85.31936, 27.68297],
    // 21: F Block junction
    [85.31961, 27.68279],
    // 22: Dept of Applied Sciences junction
    [85.32004, 27.68295],
    // 23: G Block junction
    [85.32018, 27.68310],
    // 24: CIDS / heavy labs road
    [85.31990, 27.68301],
    // 25: Heavy Lab Block / Hydraulic Lab
    [85.32034, 27.68217],
    // 26: Heavy Lab
    [85.32050, 27.68221],
    // 27: Mech Dept (east block)
    [85.32078, 27.68239],
    // 28: The Helm / FSU Office area
    [85.32083, 27.68263],
    // 29: FSU / Parking junction (east)
    [85.32076, 27.68285],
    // 30: Science & Humanities junction
    [85.32054, 27.68304],
    // 31: Center for Energy Studies
    [85.32086, 27.68322],
    // 32: Hydropower Testing Lab / SEDS
    [85.32053, 27.68347],
    // 33: Paraphet junction
    [85.32149, 27.68291],
    // 34: Suspension Bridge / Changing Room
    [85.32131, 27.68261],
    // 35: Cricket Ground junction
    [85.32215, 27.68333],
    // 36: Volleyball Court junction
    [85.32322, 27.68225],
    // 37: Basketball Court area
    [85.32259, 27.68182],
    // 38: Gym area / Calisthenics park
    [85.32278, 27.68190],
    // 39: Music Club / Niraula Store
    [85.32322, 27.68183],
    // 40: Chemical Eng Lab junction
    [85.32329, 27.68178],
    // 41: Canteen / Gym Hall area
    [85.32355, 27.68125],
    // 42: Garden area / Badminton court (east)
    [85.32367, 27.68169],
    // 43: Hostel Block C junction
    [85.32391, 27.68149],
    // 44: Hostel Block B junction
    [85.32390, 27.68184],
    // 45: Staff Quarter junction
    [85.32411, 27.68250],
    // 46: Hostel Block A junction
    [85.32393, 27.68219],
    // 47: Girls Hostel junction
    [85.32406, 27.68307],
    // 48: Teacher's Quarter junction
    [85.32471, 27.68303],
    // 49: Football Ground junction
    [85.32293, 27.68263],
    // 50: Saheed Shukra Park
    [85.31887, 27.68318],
    // 51: High Voltage Lab / Campus Mess
    [85.31935, 27.68094],
    // 52: Hydro Lab / MSC Hostel
    [85.31902, 27.68009],
    // 53: Dept of Roads
    [85.31987, 27.68075],
    // 54: Exam Control Office area
    [85.32103, 27.68107],
    // 55: NTBNS office junction
    [85.32070, 27.68302],
    // 56: Pulchowk Girls office junction
    [85.32067, 27.68292],
    // 57: Nabil Bank ATM junction
    [85.31854, 27.68283],
  ];

  // ── Walkway Edges ─────────────────────────────────────────────────────────
  // Each pair [a, b] means nodes a and b are connected by a walkable path.
  // Distances are computed automatically via Haversine.
  static const List<List<int>> _edges = [
    // Main entrance road → Dean Office / Cave
    [0, 1], // Main Entrance → Cave
    [0, 8], // Main Entrance → Badminton court junction
    [1, 2], // Cave → Dean Office
    [1, 3], // Cave → Architecture
    [1, 5], // Cave → E Block
    [2, 51], // Dean Office → High Voltage Lab
    [2, 10], // Dean Office → Machine Workshop
    [3, 5], // Architecture → E Block
    [3, 52], // Architecture → MSC Hostel / Hydro Lab
    [5, 52], // E Block → MSC Hostel
    [51, 53], // High Voltage Lab → Dept of Roads
    [51, 10], // High Voltage Lab → Machine Workshop
    [53, 54], // Dept of Roads → Exam Control Office
    // Central campus walkways
    [6, 7], // Electrical/Block C → Fountain
    [6, 8], // Electrical → Badminton court
    [7, 4], // Fountain → ICTC
    [7, 18], // Fountain → Saraswati Mandir
    [7, 57], // Fountain → Nabil ATM
    [57, 20], // Nabil ATM → Civil Dept
    [57, 50], // Nabil ATM → Saheed Shukra Park
    [50, 20], // Saheed Shukra Park → Civil Dept
    [4, 14], // ICTC → First Entrance
    [4, 6], // ICTC → Block C
    [8, 9], // Badminton → Continuing Education
    [9, 10], // Continuing Education → Machine Workshop
    [9, 11], // Continuing Education → Library
    [10, 11], // Machine Workshop → Library / Clinic
    [11, 12], // Library → Water Vending
    [12, 13], // Water Vending → Om Stationery
    [13, 15], // Om Stationery → Second Entrance
    [14, 15], // First Entrance → Second Entrance
    [14, 18], // First Entrance → Saraswati Mandir
    [15, 16], // Second Entrance → Parking
    [15, 17], // Second Entrance → Helicopter Parking
    [16, 17], // Parking → Helicopter Parking
    [16, 25], // Parking → Heavy Lab Block
    [17, 19], // Helicopter Parking → PI Chautari
    [18, 21], // Saraswati Mandir → F Block
    [18, 20], // Saraswati Mandir → Civil Dept
    [19, 21], // PI Chautari → F Block
    [19, 22], // PI Chautari → Applied Sciences
    [20, 21], // Civil Dept → F Block
    [21, 24], // F Block → CIDS
    [22, 23], // Applied Sciences → G Block
    [22, 24], // Applied Sciences → CIDS
    [23, 32], // G Block → Hydropower Testing Lab
    [24, 30], // CIDS → Science & Humanities
    [23, 30], // G Block → Science & Humanities
    // East campus (labs and departments)
    [25, 26], // Heavy Lab Block → Heavy Lab
    [26, 27], // Heavy Lab → Mech Dept (east)
    [27, 28], // Mech Dept → The Helm
    [28, 34], // The Helm → Suspension Bridge
    [28, 29], // The Helm → FSU / Parking
    [29, 55], // FSU → NTBNS
    [29, 56], // FSU → Pulchowk Girls
    [55, 30], // NTBNS → Science & Humanities
    [56, 33], // Pulchowk Girls → Paraphet
    [30, 31], // Science & Humanities → Energy Studies
    [31, 32], // Energy Studies → Hydropower
    [33, 34], // Paraphet → Suspension Bridge
    [33, 35], // Paraphet → Cricket Ground
    [34, 49], // Suspension Bridge → Football Ground
    // Sports / east-central area
    [35, 47], // Cricket Ground → Girls Hostel
    [36, 37], // Volleyball Court → Basketball Court
    [37, 38], // Basketball → Calisthenics
    [38, 39], // Calisthenics → Niraula Store
    [39, 40], // Niraula Store → Chem Lab
    [40, 42], // Chem Lab → Garden Area
    [42, 43], // Garden → Hostel Block C
    [41, 43], // Canteen → Hostel Block C
    [43, 44], // Hostel C → Hostel B
    [44, 46], // Hostel B → Hostel A
    [46, 45], // Hostel A → Staff Quarter
    [45, 47], // Staff Quarter → Girls Hostel
    [47, 48], // Girls Hostel → Teacher's Quarter
    [49, 36], // Football → Volleyball
    [49, 33], // Football → Paraphet
    [36, 46], // Volleyball → Hostel A
    [25, 13], // Heavy Lab Block → Om Stationery
    // Cross connections for better routing
    [13, 16], // Om Stationery → Parking
    [27, 34], // Mech Dept → Suspension Bridge area
    [29, 33], // FSU → Paraphet
    [54, 41], // Exam Control → Canteen
    [37, 34], // Basketball → Suspension Bridge
    [35, 31], // Cricket Ground → Energy Studies
    [19, 25], // PI Chautari → Heavy Lab Block
    [41, 54], // Canteen → Exam Control
  ];

  // ── Haversine Distance ────────────────────────────────────────────────────
  static double _haversine(List<double> a, List<double> b) {
    const R = 6371e3; // Earth radius in meters
    final lat1 = a[1] * pi / 180;
    final lat2 = b[1] * pi / 180;
    final dLat = (b[1] - a[1]) * pi / 180;
    final dLng = (b[0] - a[0]) * pi / 180;
    final h =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  /// Find the route between two arbitrary [lng, lat] points.
  ///
  /// Returns `null` if no path can be found.
  /// The result is a [CampusRoute] containing the path as [LatLng] list,
  /// total distance in meters, and estimated walk time.
  static CampusRoute? findRoute(
    List<double> startCoords,
    List<double> endCoords,
  ) {
    // 1. Snap start and end to nearest graph nodes
    final startNode = _findNearestNode(startCoords);
    final endNode = _findNearestNode(endCoords);

    if (startNode == endNode) {
      // Same node — return direct line
      final dist = _haversine(startCoords, endCoords);
      return CampusRoute(
        points: [
          LatLng(startCoords[1], startCoords[0]),
          LatLng(endCoords[1], endCoords[0]),
        ],
        distanceMeters: dist,
      );
    }

    // 2. Build adjacency list
    final int n = _nodes.length;
    final adj = List.generate(n, (_) => <_Edge>[]);
    for (final edge in _edges) {
      final a = edge[0], b = edge[1];
      final dist = _haversine(_nodes[a], _nodes[b]);
      adj[a].add(_Edge(b, dist));
      adj[b].add(_Edge(a, dist));
    }

    // 3. Dijkstra's algorithm
    final dist = List.filled(n, double.infinity);
    final prev = List.filled(n, -1);
    final visited = List.filled(n, false);
    dist[startNode] = 0;

    // Simple priority queue using a sorted list
    final pq = <_PQEntry>[_PQEntry(startNode, 0)];

    while (pq.isNotEmpty) {
      // Extract min
      pq.sort((a, b) => a.dist.compareTo(b.dist));
      final current = pq.removeAt(0);
      final u = current.node;

      if (visited[u]) continue;
      visited[u] = true;

      if (u == endNode) break;

      for (final edge in adj[u]) {
        final newDist = dist[u] + edge.weight;
        if (newDist < dist[edge.to]) {
          dist[edge.to] = newDist;
          prev[edge.to] = u;
          pq.add(_PQEntry(edge.to, newDist));
        }
      }
    }

    if (dist[endNode] == double.infinity) return null; // No path

    // 4. Reconstruct path
    final path = <int>[];
    int current = endNode;
    while (current != -1) {
      path.add(current);
      current = prev[current];
    }
    path.reversed; // in-place won't work, need to create reversed list

    final pathNodes = path.reversed.toList();

    // 5. Build LatLng list: start → graph nodes → end
    final points = <LatLng>[LatLng(startCoords[1], startCoords[0])];
    for (final nodeIdx in pathNodes) {
      points.add(LatLng(_nodes[nodeIdx][1], _nodes[nodeIdx][0]));
    }
    points.add(LatLng(endCoords[1], endCoords[0]));

    // Total distance = snap-to-start + graph path + snap-to-end
    final snapStartDist = _haversine(startCoords, _nodes[startNode]);
    final snapEndDist = _haversine(_nodes[endNode], endCoords);
    final totalDist = snapStartDist + dist[endNode] + snapEndDist;

    return CampusRoute(points: points, distanceMeters: totalDist);
  }

  /// Find the graph node nearest to the given coordinates.
  static int _findNearestNode(List<double> coords) {
    int nearest = 0;
    double minDist = double.infinity;
    for (int i = 0; i < _nodes.length; i++) {
      final d = _haversine(coords, _nodes[i]);
      if (d < minDist) {
        minDist = d;
        nearest = i;
      }
    }
    return nearest;
  }
}

/// Result of a campus route calculation.
class CampusRoute {
  final List<LatLng> points;
  final double distanceMeters;

  /// Estimated walking time in seconds (assuming 1.2 m/s walking speed).
  double get walkTimeSeconds => distanceMeters / 1.2;

  String get formattedDistance => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';

  String get formattedDuration => walkTimeSeconds < 60
      ? '${walkTimeSeconds.round()} sec'
      : '${(walkTimeSeconds / 60).round()} min';

  const CampusRoute({required this.points, required this.distanceMeters});
}

/// Internal edge representation for the adjacency list.
class _Edge {
  final int to;
  final double weight;
  const _Edge(this.to, this.weight);
}

/// Internal priority queue entry.
class _PQEntry {
  final int node;
  final double dist;
  const _PQEntry(this.node, this.dist);
}
