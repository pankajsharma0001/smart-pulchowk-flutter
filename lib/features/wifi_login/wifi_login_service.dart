import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Represents a single build step from the API
class BuildStep {
  final String name;
  final String status; // "queued", "in_progress", "completed"
  final String? conclusion; // "success", "failure", "skipped", null

  BuildStep({required this.name, required this.status, this.conclusion});

  factory BuildStep.fromJson(Map<String, dynamic> json) {
    return BuildStep(
      name: json['name'] ?? '',
      status: json['status'] ?? 'queued',
      conclusion: json['conclusion'],
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isSuccess => conclusion == 'success';
  bool get isFailed => conclusion == 'failure';
}

/// Represents the current state of an APK build
class BuildStatus {
  final String status; // "queued", "in_progress", "completed"
  final String? conclusion; // "success", "failure"
  final String? runId;

  BuildStatus({required this.status, this.conclusion, this.runId});

  bool get isCompleted => status == 'completed';
  bool get isSuccess => conclusion == 'success';
  bool get isFailed => conclusion == 'failure';
}

/// Service to interact with the pcampus-login APK builder API
class WifiLoginService {
  static const String _baseUrl = 'https://pcampus-login.vercel.app';

  /// Start a new APK build with the given credentials
  /// Returns the buildId on success
  static Future<String> startBuild({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/build'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final buildId = data['buildId'];
        if (buildId == null) {
          throw Exception('No buildId returned from server');
        }
        return buildId.toString();
      } else {
        final errorBody = response.body;
        throw Exception('Failed to start build (${response.statusCode}): $errorBody');
      }
    } catch (e) {
      debugPrint('WifiLoginService: Error starting build: $e');
      rethrow;
    }
  }

  /// Check the status of a build
  static Future<BuildStatus> checkStatus(String buildId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/status?build_id=$buildId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BuildStatus(
          status: data['status'] ?? 'queued',
          conclusion: data['conclusion'],
          runId: data['runId']?.toString(),
        );
      } else {
        throw Exception('Failed to check status (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('WifiLoginService: Error checking status: $e');
      rethrow;
    }
  }

  /// Fetch the build steps for progress display
  static Future<List<BuildStep>> fetchSteps(String runId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/steps?run_id=$runId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((s) => BuildStep.fromJson(s)).toList();
        }
        // Sometimes the API wraps steps in a 'steps' key
        if (data is Map && data['steps'] is List) {
          return (data['steps'] as List)
              .map((s) => BuildStep.fromJson(s))
              .toList();
        }
        return [];
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('WifiLoginService: Error fetching steps: $e');
      return [];
    }
  }

  /// Get the download URL for the completed APK
  static Future<Map<String, String>?> getApkDownloadUrl(String buildId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/latest-apk?build_id=$buildId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true && data['url'] != null) {
          return {
            'url': data['url'].toString(),
            'name': data['name']?.toString() ?? 'pcampus-login.apk',
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('WifiLoginService: Error getting APK URL: $e');
      return null;
    }
  }
}
