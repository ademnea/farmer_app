import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
// import 'package:farmer_app/bee_counter/bee_counter_model.dart';

class TimeBasedReturnRateDatabase {
  static final TimeBasedReturnRateDatabase instance =
      TimeBasedReturnRateDatabase._init();
  static Database? _database;

  TimeBasedReturnRateDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('time_based_return_rates.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    // Table for daily time block analysis
    await db.execute('''
    CREATE TABLE time_block_analysis (
      id $idType,
      hive_id $textType,
      date $textType,
      time_block $textType,
      bees_out $intType,
      bees_in $intType,
      actual_return_rate $realType,
      expected_return_rate $realType,
      avg_trip_duration $realType,
      health_indicator $textType,
      timestamp $textType
    )
    ''');

    // Table for trip duration distribution
    await db.execute('''
    CREATE TABLE trip_duration_distribution (
      id $idType,
      hive_id $textType,
      date $textType,
      short_trips_percent $realType,
      medium_trips_percent $realType,
      long_trips_percent $realType,
      avg_short_duration $realType,
      avg_medium_duration $realType,
      avg_long_duration $realType,
      timestamp $textType
    )
    ''');
  }

  // Save time block analysis
  Future<String> saveTimeBlockAnalysis({
    required String hiveId,
    required DateTime date,
    required String timeBlock,
    required int beesOut,
    required int beesIn,
    required double actualReturnRate,
    required double expectedReturnRate,
    required double avgTripDuration,
    required String healthIndicator,
  }) async {
    final db = await instance.database;

    final id = '${hiveId}_${DateFormat('yyyy-MM-dd').format(date)}_$timeBlock';

    final data = {
      'id': id,
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'time_block': timeBlock,
      'bees_out': beesOut,
      'bees_in': beesIn,
      'actual_return_rate': actualReturnRate,
      'expected_return_rate': expectedReturnRate,
      'avg_trip_duration': avgTripDuration,
      'health_indicator': healthIndicator,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      await db.insert(
        'time_block_analysis',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return id;
    } catch (e) {
      print('Error saving time block analysis: $e');
      throw e;
    }
  }

  // Save trip duration distribution
  Future<String> saveTripDurationDistribution({
    required String hiveId,
    required DateTime date,
    required double shortTripsPercent,
    required double mediumTripsPercent,
    required double longTripsPercent,
    required double avgShortDuration,
    required double avgMediumDuration,
    required double avgLongDuration,
  }) async {
    final db = await instance.database;

    final id = '${hiveId}_${DateFormat('yyyy-MM-dd').format(date)}';

    final data = {
      'id': id,
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'short_trips_percent': shortTripsPercent,
      'medium_trips_percent': mediumTripsPercent,
      'long_trips_percent': longTripsPercent,
      'avg_short_duration': avgShortDuration,
      'avg_medium_duration': avgMediumDuration,
      'avg_long_duration': avgLongDuration,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      await db.insert(
        'trip_duration_distribution',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return id;
    } catch (e) {
      print('Error saving trip duration distribution: $e');
      throw e;
    }
  }

  // Read time block analysis for a specific hive and date
  Future<List<Map<String, dynamic>>> readTimeBlockAnalysisByDate(
    String hiveId,
    DateTime date,
  ) async {
    final db = await instance.database;

    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    try {
      return await db.query(
        'time_block_analysis',
        where: 'hive_id = ? AND date = ?',
        whereArgs: [hiveId, dateStr],
      );
    } catch (e) {
      print('Error reading time block analysis: $e');
      return [];
    }
  }

  // Read time block analysis for a specific hive within a date range
  Future<List<Map<String, dynamic>>> readTimeBlockAnalysisByDateRange(
    String hiveId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await instance.database;

    final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

    try {
      return await db.query(
        'time_block_analysis',
        where: 'hive_id = ? AND date BETWEEN ? AND ?',
        whereArgs: [hiveId, startDateStr, endDateStr],
      );
    } catch (e) {
      print('Error reading time block analysis by date range: $e');
      return [];
    }
  }

  // Read trip duration distribution for a specific hive and date
  Future<Map<String, dynamic>?> readTripDurationDistribution(
    String hiveId,
    DateTime date,
  ) async {
    final db = await instance.database;

    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    try {
      final results = await db.query(
        'trip_duration_distribution',
        where: 'hive_id = ? AND date = ?',
        whereArgs: [hiveId, dateStr],
      );

      if (results.isNotEmpty) {
        return results.first;
      }
      return null;
    } catch (e) {
      print('Error reading trip duration distribution: $e');
      return null;
    }
  }

  // Other database methods remain the same...
}

