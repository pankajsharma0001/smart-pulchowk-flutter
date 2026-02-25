import 'dart:math';

import 'package:maplibre_gl/maplibre_gl.dart';

/// Offline campus router using Dijkstra's shortest path algorithm.
///
/// The walkway graph is defined using real campus **road and path intersections**
/// (not building locations). This ensures routes follow actual walkable paths.
class CampusRouter {
  CampusRouter._();

  // ── Walkway Graph Nodes ──────────────────────────────────────────────────
  // These are points on actual campus roads and footpaths (NOT buildings).
  // Format: [longitude, latitude]
  static const List<List<double>> _nodes = [
    // ── Main Road (south, entrance road going east) ──
    // 0: Main gate (road start)
    [85.31775, 27.68137],
    // 1: Road bend near cave
    [85.31795, 27.68095],
    // 2: Road junction near Architecture/E Block
    [85.31840, 27.68055],
    // 3: Road junction near MSC Hostel / Hydro Lab
    [85.31920, 27.68020],
    // 4: Road junction near Dean Office
    [85.31860, 27.68105],
    // 5: Road junction near High Voltage Lab
    [85.31935, 27.68095],
    // 6: Road junction near Workshop / Mess
    [85.31950, 27.68110],
    // 7: Road junction near Machine Workshop
    [85.31906, 27.68130],

    // ── Central Walkway (west to east, main internal path) ──
    // 8: Path junction near main gate (inside, going north)
    [85.31790, 27.68150],
    // 9: Path junction near Badminton/Electrical Dept
    [85.31850, 27.68180],
    // 10: Path junction near ICTC building
    [85.31900, 27.68200],
    // 11: Path junction near Continuing Ed / Robotics
    [85.31905, 27.68150],
    // 12: Path junction near Library / Clinic
    [85.31940, 27.68160],
    // 13: Path junction near Water Vending / ICT
    [85.31950, 27.68175],
    // 14: Path junction near Om Stationery
    [85.31985, 27.68185],

    // ── North-South Central Road ──
    // 15: Road junction near First Entrance / Siddhartha ATM
    [85.31945, 27.68210],
    // 16: Road junction near Second Entrance
    [85.31960, 27.68215],
    // 17: Road junction near Parking / Heavy Lab Block
    [85.31995, 27.68215],
    // 18: Road junction near Helicopter Parking
    [85.31970, 27.68230],

    // ── Upper campus walkways ──
    // 19: Path junction near Fountain / Block C area
    [85.31888, 27.68235],
    // 20: Path junction near Nabil ATM / Central Material Lab
    [85.31855, 27.68270],
    // 21: Path junction near Embark College
    [85.31890, 27.68270],
    // 22: Path junction near Saraswati Mandir
    [85.31940, 27.68258],
    // 23: Path junction near Civil Dept / Saheed Shukra Park
    [85.31890, 27.68310],
    // 24: Path junction near D Block / Mech Dept
    [85.31990, 27.68250],
    // 25: Path junction near F Block
    [85.31960, 27.68280],
    // 26: Path junction near PI Chautari
    [85.31990, 27.68270],
    // 27: Path junction near CIDS
    [85.31990, 27.68300],
    // 28: Path junction near G Block / Applied Sciences
    [85.32005, 27.68310],
    // 29: Path junction near Dept Applied Sciences
    [85.32005, 27.68295],

    // ── East campus road (labs area) ──
    // 30: Road junction near Heavy Lab Block (east)
    [85.32035, 27.68210],
    // 31: Road junction near Heavy Lab / Hydraulic Lab
    [85.32050, 27.68220],
    // 32: Road junction near Mech Dept (east)
    [85.32080, 27.68240],
    // 33: Road junction near Helm / Suspension Bridge
    [85.32085, 27.68265],
    // 34: Road junction near Suspension Bridge
    [85.32130, 27.68260],
    // 35: Road junction near FSU Office / Parking
    [85.32080, 27.68285],
    // 36: Road junction near Paraphet
    [85.32150, 27.68290],
    // 37: Road junction near Science & Humanities
    [85.32055, 27.68305],
    // 38: Road junction near Center for Energy Studies
    [85.32085, 27.68320],
    // 39: Road junction near Hydropower Testing / SEDS
    [85.32050, 27.68350],
    // 40: Road junction near NTBNS / Pulchowk Girls
    [85.32070, 27.68300],

    // ── Sports area roads ──
    // 41: Road junction near Changing Room
    [85.32170, 27.68265],
    // 42: Road junction near Football Ground (west edge)
    [85.32230, 27.68270],
    // 43: Road junction near Cricket Ground (south)
    [85.32215, 27.68320],
    // 44: Road junction near Basketball Court
    [85.32260, 27.68185],
    // 45: Road junction near Volleyball Court
    [85.32320, 27.68230],
    // 46: Road junction near Calisthenics / Gym path
    [85.32280, 27.68195],

    // ── Hostel area roads ──
    // 47: Road junction near Canteen / Exam Control
    [85.32105, 27.68110],
    // 48: Road junction near Music Club / Niraula Store
    [85.32322, 27.68185],
    // 49: Road junction near Chem Lab / Badminton (east)
    [85.32340, 27.68175],
    // 50: Road junction near Gym Hall / Garden
    [85.32355, 27.68155],
    // 51: Road junction near Hostel Block C
    [85.32390, 27.68150],
    // 52: Road junction near Hostel Block B
    [85.32390, 27.68185],
    // 53: Road junction near Hostel Block A / Volleyball
    [85.32393, 27.68220],
    // 54: Road junction near Staff Quarter
    [85.32410, 27.68250],
    // 55: Road junction near Girls Hostel
    [85.32405, 27.68310],
    // 56: Road junction near Teacher's Quarter
    [85.32470, 27.68305],
    // 57: Road junction near Football Ground (east)
    [85.32340, 27.68280],
    // 58: Road junction near Cricket pitch
    [85.32345, 27.68300],

    // ── Additional connector nodes ──
    // 59: Path junction near Exam Control / Dept of Roads
    [85.32000, 27.68085],
    // 60: Path going to canteen area
    [85.32100, 27.68125],
    // 61: Path junction near Locus Office / Electrical Dept
    [85.31855, 27.68140],
  ];

  // ── Walkway Edges ─────────────────────────────────────────────────────────
  // Each pair [a, b] means nodes a and b are connected by a walkable road/path.
  static const List<List<int>> _edges = [
    // Main gate area
    [0, 8], // Gate → internal path north
    [0, 1], // Gate → road south (cave direction)
    [8, 9], // Internal path → Badminton junction
    [8, 61], // Internal path → Locus junction
    // South road (entrance road)
    [1, 4], // Cave → Dean Office junction
    [1, 2], // Cave → Architecture junction
    [2, 3], // Architecture → MSC Hostel road
    [4, 5], // Dean Office → HV Lab junction
    [4, 7], // Dean Office → Machine Workshop
    [4, 61], // Dean Office → Locus junction
    [5, 6], // HV Lab → Workshop / Mess
    [5, 59], // HV Lab → Dept of Roads road
    [6, 7], // Workshop → Machine Workshop
    [6, 12], // Workshop → Library path
    [7, 11], // Machine Workshop → Continuing Ed
    [7, 61], // Machine Workshop → Locus junction
    // Central walkways
    [9, 10], // Badminton → ICTC
    [9, 19], // Badminton → Fountain area
    [9, 61], // Badminton → Locus junction
    [10, 11], // ICTC → Continuing Ed
    [10, 15], // ICTC → First Entrance
    [10, 19], // ICTC → Fountain area
    [11, 12], // Continuing Ed → Library
    [12, 13], // Library → Water Vending
    [13, 14], // Water Vending → Om Stationery
    [14, 16], // Om Stationery → Second Entrance
    [14, 17], // Om Stationery → Parking
    [15, 16], // First Entrance → Second Entrance
    [15, 22], // First Entrance → Saraswati Mandir
    [16, 17], // Second Entrance → Parking
    [16, 18], // Second Entrance → Helicopter Parking
    [17, 18], // Parking → Helicopter
    [17, 30], // Parking → Heavy Lab Block
    // Upper campus (north)
    [18, 24], // Helicopter → D Block / Mech
    [19, 20], // Fountain → Nabil ATM area
    [19, 21], // Fountain → Embark area
    [19, 22], // Fountain → Saraswati Mandir path
    [20, 23], // Nabil ATM → Civil / Park
    [20, 21], // Nabil ATM → Embark
    [21, 22], // Embark → Saraswati Mandir
    [22, 25], // Saraswati Mandir → F Block
    [22, 24], // Saraswati Mandir → D Block
    [23, 25], // Civil / Park → F Block
    [24, 26], // D Block → PI Chautari
    [24, 30], // D Block → Heavy Lab Block road
    [25, 26], // F Block → PI Chautari
    [25, 27], // F Block → CIDS
    [26, 27], // PI Chautari → CIDS
    [26, 29], // PI Chautari → Applied Sciences
    [27, 28], // CIDS → G Block
    [28, 29], // G Block → Applied Sciences
    [28, 39], // G Block → Hydropower Testing
    [29, 37], // Applied Sciences → Science & Humanities
    // East campus (labs road)
    [30, 31], // Heavy Lab Block → Heavy Lab
    [31, 32], // Heavy Lab → Mech Dept (east)
    [32, 33], // Mech Dept → Helm area
    [33, 34], // Helm → Suspension Bridge
    [33, 35], // Helm → FSU junction
    [34, 41], // Suspension Bridge → Changing Room
    [35, 40], // FSU → NTBNS/Girls office
    [35, 36], // FSU → Paraphet
    [36, 41], // Paraphet → Changing Room
    [36, 43], // Paraphet → Cricket Ground
    [37, 38], // Science & Humanities → Energy Studies
    [37, 40], // Science & Humanities → NTBNS junction
    [38, 39], // Energy Studies → Hydropower
    [38, 43], // Energy Studies → Cricket Ground
    // Sports area
    [41, 42], // Changing Room → Football (west)
    [42, 44], // Football → Basketball
    [42, 57], // Football → Football (east)
    [44, 46], // Basketball → Calisthenics
    [46, 48], // Calisthenics → Music Club / Niraula
    [45, 53], // Volleyball → Hostel A
    [45, 57], // Volleyball → Football (east)
    [57, 58], // Football (east) → Cricket pitch
    [58, 55], // Cricket pitch → Girls Hostel
    [43, 38], // Cricket Ground → Energy Studies
    [43, 55], // Cricket Ground → Girls Hostel
    // Hostel / canteen area roads
    [47, 60], // Exam Control → canteen path
    [59, 47], // Dept of Roads road → Exam Control
    [60, 50], // Canteen path → Gym Hall
    [48, 49], // Music Club → Chem Lab
    [49, 50], // Chem Lab → Gym Hall
    [50, 51], // Gym Hall → Hostel C
    [51, 52], // Hostel C → Hostel B
    [52, 53], // Hostel B → Hostel A
    [53, 54], // Hostel A → Staff Quarter
    [54, 55], // Staff Quarter → Girls Hostel
    [55, 56], // Girls Hostel → Teacher's Quarter
    // Cross connections
    [36, 57], // Paraphet → Football east
    [44, 34], // Basketball → Suspension Bridge area
    [46, 45], // Calisthenics → Volleyball
    [42, 36], // Football west → Paraphet
    [48, 46], // Music Club → Calisthenics
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
  static CampusRoute? findRoute(
    List<double> startCoords,
    List<double> endCoords,
  ) {
    // 1. Snap start and end to nearest graph nodes
    final startNode = _findNearestNode(startCoords);
    final endNode = _findNearestNode(endCoords);

    if (startNode == endNode) {
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

    final pq = <_PQEntry>[_PQEntry(startNode, 0)];

    while (pq.isNotEmpty) {
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

    if (dist[endNode] == double.infinity) return null;

    // 4. Reconstruct path
    final path = <int>[];
    int current = endNode;
    while (current != -1) {
      path.add(current);
      current = prev[current];
    }

    final pathNodes = path.reversed.toList();

    // 5. Build LatLng list: start point → graph path nodes → end point
    final points = <LatLng>[LatLng(startCoords[1], startCoords[0])];
    for (final nodeIdx in pathNodes) {
      points.add(LatLng(_nodes[nodeIdx][1], _nodes[nodeIdx][0]));
    }
    points.add(LatLng(endCoords[1], endCoords[0]));

    final snapStartDist = _haversine(startCoords, _nodes[startNode]);
    final snapEndDist = _haversine(_nodes[endNode], endCoords);
    final totalDist = snapStartDist + dist[endNode] + snapEndDist;

    return CampusRoute(points: points, distanceMeters: totalDist);
  }

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

  double get walkTimeSeconds => distanceMeters / 1.2;

  String get formattedDistance => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';

  String get formattedDuration => walkTimeSeconds < 60
      ? '${walkTimeSeconds.round()} sec'
      : '${(walkTimeSeconds / 60).round()} min';

  const CampusRoute({required this.points, required this.distanceMeters});
}

class _Edge {
  final int to;
  final double weight;
  const _Edge(this.to, this.weight);
}

class _PQEntry {
  final int node;
  final double dist;
  const _PQEntry(this.node, this.dist);
}
