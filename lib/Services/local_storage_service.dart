// import 'dart:convert';
// import 'dart:io';
// import 'package:path_provider/path_provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:farmer_app/bee_counter/bee_counter_model.dart';
// import 'package:farmer_app/bee_counter/bee_video_analysis_result.dart';

// /// Service for storing bee counter data locally
// class LocalStorageService {
//   // Singleton instance
//   static final LocalStorageService _instance = LocalStorageService._internal();
//   factory LocalStorageService() => _instance;
//   LocalStorageService._internal();

//   // File paths
//   static const String _analysisResultsFile = 'bee_analysis_results.json';
//   static const String _beeVideosFile = 'bee_videos.json';
//   static const String _beeCountsFile = 'bee_counts.json';
//   static const String _processedVideoIdsKey = 'processed_video_ids';

//   /// Save a bee analysis result
//   Future<String> saveAnalysisResult(BeeAnalysisResult result) async {
//     try {
//       // Load existing results
//       final results = await getAnalysisResults();

//       // Generate a new ID if needed
//       final String resultId =
//           result.id.isEmpty
//               ? 'result_${DateTime.now().millisecondsSinceEpoch}'
//               : result.id;

//       // Create a copy with the new ID
//       final resultWithId = result.copyWith(id: resultId);

//       // Add or update the result
//       final index = results.indexWhere((r) => r.id == resultId);
//       if (index >= 0) {
//         results[index] = resultWithId;
//       } else {
//         results.add(resultWithId);
//       }

//       // Save the updated list
//       await _saveToFile(
//         _analysisResultsFile,
//         jsonEncode(results.map((r) => r.toJson()).toList()),
//       );

//       return resultId;
//     } catch (e) {
//       print('Error saving analysis result: $e');
//       rethrow;
//     }
//   }

//   /// Get all analysis results
//   Future<List<BeeAnalysisResult>> getAnalysisResults({
//     String? hiveId,
//     DateTime? startDate,
//     DateTime? endDate,
//   }) async {
//     try {
//       final jsonString = await _readFromFile(_analysisResultsFile);
//       if (jsonString.isEmpty) return [];

//       final List<dynamic> jsonList = jsonDecode(jsonString);
//       List<BeeAnalysisResult> results =
//           jsonList.map((json) {
//             return BeeAnalysisResult.fromJson(json, json['id'] ?? '');
//           }).toList();

//       // Apply filters if provided
//       if (hiveId != null) {
//         results = results.where((r) => r.videoId.contains(hiveId)).toList();
//       }

//       if (startDate != null) {
//         results = results.where((r) => r.timestamp.isAfter(startDate)).toList();
//       }

//       if (endDate != null) {
//         final endDateTime = endDate.add(Duration(days: 1));
//         results =
//             results.where((r) => r.timestamp.isBefore(endDateTime)).toList();
//       }

//       // Sort by timestamp (newest first)
//       results.sort((a, b) => b.timestamp.compareTo(a.timestamp));

//       return results;
//     } catch (e) {
//       print('Error getting analysis results: $e');
//       return [];
//     }
//   }

//   /// Get a specific analysis result by ID
//   Future<BeeAnalysisResult?> getAnalysisResult(String resultId) async {
//     try {
//       final results = await getAnalysisResults();
//       return results.firstWhere((r) => r.id == resultId);
//     } catch (e) {
//       print('Error getting analysis result: $e');
//       return null;
//     }
//   }

//   /// Delete an analysis result
//   Future<void> deleteAnalysisResult(String resultId) async {
//     try {
//       final results = await getAnalysisResults();
//       results.removeWhere((r) => r.id == resultId);

//       await _saveToFile(
//         _analysisResultsFile,
//         jsonEncode(results.map((r) => r.toJson()).toList()),
//       );
//     } catch (e) {
//       print('Error deleting analysis result: $e');
//       rethrow;
//     }
//   }

//   /// Save a bee video
//   Future<void> saveBeeVideo(BeeVideo video) async {
//     try {
//       final videos = await getBeeVideos();

//       final index = videos.indexWhere((v) => v.id == video.id);
//       if (index >= 0) {
//         videos[index] = video;
//       } else {
//         videos.add(video);
//       }

//       await _saveToFile(
//         _beeVideosFile,
//         jsonEncode(videos.map((v) => v.toJson()).toList()),
//       );
//     } catch (e) {
//       print('Error saving bee video: $e');
//       rethrow;
//     }
//   }

//   /// Get all bee videos
//   Future<List<BeeVideo>> getBeeVideos({String? hiveId}) async {
//     try {
//       final jsonString = await _readFromFile(_beeVideosFile);
//       if (jsonString.isEmpty) return [];

//       final List<dynamic> jsonList = jsonDecode(jsonString);
//       List<BeeVideo> videos =
//           jsonList.map((json) {
//             return BeeVideo.fromJson(json);
//           }).toList();

//       // Filter by hive ID if provided
//       if (hiveId != null) {
//         videos = videos.where((v) => v.hiveId == hiveId).toList();
//       }

//       // Sort by recorded date (newest first)
//       videos.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

//       return videos;
//     } catch (e) {
//       print('Error getting bee videos: $e');
//       return [];
//     }
//   }

//   /// Get a specific bee video by ID
//   Future<BeeVideo?> getBeeVideo(String videoId) async {
//     try {
//       final videos = await getBeeVideos();
//       return videos.firstWhere((v) => v.id == videoId);
//     } catch (e) {
//       print('Error getting bee video: $e');
//       return null;
//     }
//   }

//   /// Save a bee count
//   Future<void> saveBeeCount(BeeCount count) async {
//     try {
//       final counts = await getBeeCounts();

//       // Add the new count
//       counts.add(count);

//       await _saveToFile(
//         _beeCountsFile,
//         jsonEncode(counts.map((c) => c.toJson()).toList()),
//       );
//     } catch (e) {
//       print('Error saving bee count: $e');
//       rethrow;
//     }
//   }

//   /// Get all bee counts
//   Future<List<BeeCount>> getBeeCounts({
//     String? hiveId,
//     DateTime? startDate,
//     DateTime? endDate,
//   }) async {
//     try {
//       final jsonString = await _readFromFile(_beeCountsFile);
//       if (jsonString.isEmpty) return [];

//       final List<dynamic> jsonList = jsonDecode(jsonString);
//       List<BeeCount> counts =
//           jsonList.map((json) {
//             return BeeCount.fromJson(json);
//           }).toList();

//       // Filter by hive ID if provided
//       if (hiveId != null) {
//         counts = counts.where((c) => c.hiveId == hiveId).toList();
//       }

//       // Sort by timestamp (newest first)
//       counts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

//       return counts;
//     } catch (e) {
//       print('Error getting bee counts: $e');
//       return [];
//     }
//   }

//   /// Get bee counts for a specific video
//   Future<BeeCount?> getBeeCountForVideo(String videoId) async {
//     try {
//       final counts = await getBeeCounts();
//       return counts.firstWhere((c) => c.videoId == videoId);
//     } catch (e) {
//       print('Error getting bee count for video: $e');
//       return null;
//     }
//   }

//   /// Get processed video IDs
//   Future<Set<String>> getProcessedVideoIds() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final ids = prefs.getStringList(_processedVideoIdsKey) ?? [];
//       return ids.toSet();
//     } catch (e) {
//       print('Error getting processed video IDs: $e');
//       return {};
//     }
//   }

//   /// Save processed video IDs
//   Future<void> saveProcessedVideoIds(Set<String> ids) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setStringList(_processedVideoIdsKey, ids.toList());
//     } catch (e) {
//       print('Error saving processed video IDs: $e');
//       rethrow;
//     }
//   }

//   /// Add a processed video ID
//   Future<void> addProcessedVideoId(String id) async {
//     try {
//       final ids = await getProcessedVideoIds();
//       ids.add(id);
//       await saveProcessedVideoIds(ids);
//     } catch (e) {
//       print('Error adding processed video ID: $e');
//       rethrow;
//     }
//   }

//   /// Clear processed video IDs
//   Future<void> clearProcessedVideoIds() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.remove(_processedVideoIdsKey);
//     } catch (e) {
//       print('Error clearing processed video IDs: $e');
//       rethrow;
//     }
//   }

//   /// Save data to a file
//   Future<void> _saveToFile(String fileName, String data) async {
//     try {
//       final directory = await getApplicationDocumentsDirectory();
//       final file = File('${directory.path}/$fileName');
//       await file.writeAsString(data);
//     } catch (e) {
//       print('Error saving to file: $e');
//       rethrow;
//     }
//   }

//   /// Read data from a file
//   Future<String> _readFromFile(String fileName) async {
//     try {
//       final directory = await getApplicationDocumentsDirectory();
//       final file = File('${directory.path}/$fileName');

//       if (await file.exists()) {
//         return await file.readAsString();
//       }

//       return '';
//     } catch (e) {
//       print('Error reading from file: $e');
//       return '';
//     }
//   }
// }

