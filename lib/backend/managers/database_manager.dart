import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '/backend/managers/plugin_manager.dart';
import '/backend/plugin_interface.dart';
import '/backend/universal_formats.dart';
import '/main.dart';

// This class is used to simplify interactions with the database
class DatabaseManager {
  // make the db manager a singleton.
  // This way any part of the app can access the db, without having to re-initialize the manager
  static final DatabaseManager _instance = DatabaseManager._init();

  DatabaseManager._init() {
    init();
  }

  factory DatabaseManager() {
    return _instance;
  }

  void init() {
    if (Platform.isLinux) {
      logger.i("Linux detected, initializing sqflite_ffi");
      sqfliteFfiInit();
    }
    databaseFactory = databaseFactoryFfi;
    // init db
    getDb().then((tempDb) => tempDb.close());
  }

  static Future<Database> getDb() async {
    Directory appSupportDir = await getApplicationSupportDirectory();
    String dbPath = "${appSupportDir.path}/hedon_haven.db";

    logger.i("Opening database at $dbPath");
    Database db = await openDatabase(dbPath, version: 1,
        onCreate: (Database db, int version) async {
      logger.i("No database detected, creating new");
      createDefaultTables(db);
    }, onUpgrade: (Database db, int oldVersion, int newVersion) async {
      logger.i("Database upgrade from $oldVersion to $newVersion");
      // TODO: Implement database upgrades if needed
    }, onDowngrade: (Database db, int oldVersion, int newVersion) async {
      logger
          .w("UNEXPECTED DATBASE DOWNGRADE! Backing up to hedon_haven.db_old");
      // copy database to old database
      await File(dbPath).copy("${dbPath}_old");
      logger.w("DROPPING ALL TABLES TO PREVENT ERRORS!!!");
      await db.execute("DROP TABLE watch_history");
      await db.execute("DROP TABLE search_history");
      await db.execute("DROP TABLE favorites");
      createDefaultTables(db);
    }, onOpen: (Database db) async {
      logger.i("Database opened successfully");
    });
    return db;
  }

  /// Delete all rows from a table
  /// Possible tableNames: watch_history, search_history, favorites
  static void deleteAllFrom(String tableName) {
    logger.w("Deleting all rows from $tableName");
    getDb().then((db) {
      db.execute("DELETE FROM $tableName");
      db.close();
    });
  }

  /// Unlike deleteAllFrom, this deletes the database file itself
  static Future<void> purgeDatabase() async {
    logger.w("Purging database");
    Directory appSupportDir = await getApplicationSupportDirectory();
    File databaseFile = File("${appSupportDir.path}/hedon_haven.db");
    if (await databaseFile.exists()) {
      await databaseFile.delete();
      logger.i("Database deleted successfully");
    } else {
      logger.w("Database not found, nothing was deleted");
    }
  }

  static void createDefaultTables(Database db) async {
    logger.i("Creating default tables in database");
    // Reimplementation of some parts of UniversalSearchResult
    // This is only used to show a preview in the history screen
    // If the user decides to replay a video from history, the corresponding
    // plugin will be called upon to fetch fresh video metadata
    // Storing videoPreview would take up a lot of storage
    // TODO: Make it optional to store video previews?
    await db.execute('''
        CREATE TABLE watch_history (
          id INTEGER PRIMARY KEY,
          videoID TEXT,
          title TEXT,
          plugin TEXT,
          author TEXT,
          thumbnailBinary BLOB,
          durationInSeconds INTEGER,
          maxQuality INTEGER,
          virtualReality INTEGER,
          firstWatched Text,
          lastWatched TEXT
        )
        ''');
    // Reimplementation of UniversalSearchRequest
    // Plugins is a list of plugins the search was attempted on
    // virtualReality is actually a boolean
    // categories and keywords are actually lists of strings
    await db.execute('''
        CREATE TABLE search_history (
          id INTEGER PRIMARY KEY,
          plugins TEXT,
          searchString TEXT,
          sortingType TEXT,
          dateRange TEXT,
          minQuality INTEGER,
          maxQuality INTEGER,
          minDuration INTEGER,
          maxDuration INTEGER,
          minFramesPerSecond INTEGER,
          maxFramesPerSecond INTEGER,
          virtualReality INTEGER,
          categoriesInclude TEXT,
          categoriesExclude TEXT,
          keywordsInclude TEXT,
          keywordsExclude TEXT
        )
      ''');
    // Reimplementation of some parts of UniversalSearchResult
    // This is only used to show a preview in the history screen
    // If the user decides to replay a video from history, the corresponding
    // plugin will be called upon to fetch fresh video metadata
    // Storing videoPreview would take up a lot of storage
    // TODO: Make it optional to store video previews?
    await db.execute('''
        CREATE TABLE favorites (
          id INTEGER PRIMARY KEY,
          videoID TEXT,
          title TEXT,
          plugin TEXT,
          thumbnailBinary BLOB,
          durationInSeconds INTEGER,
          maxQuality INTEGER,
          virtualReality INTEGER,
          author TEXT,
          addedOn Text
        )
        ''');
    // Dont close db, as this function is only called by getDb
  }

  static Future<List<Map<String, Object?>>> getAllFrom(
      String dbName, String tableName) async {
    Database db = await getDb();
    List<Map<String, Object?>> results = await db.query(tableName);
    db.close();
    return results;
  }

  static Future<List<UniversalSearchResult>> getWatchHistory() async {
    Database db = await getDb();
    List<Map<String, Object?>> results = await db.query("watch_history");
    db.close();
    List<UniversalSearchResult> resultsList = [];

    for (var historyItem in results) {
      resultsList.add(UniversalSearchResult(
          videoID: historyItem["videoID"].toString(),
          title: historyItem["title"].toString(),
          plugin:
              PluginManager.getPluginByName(historyItem["plugin"].toString()),
          author: historyItem["author"].toString(),
          thumbnailBinary: historyItem["thumbnailBinary"] as Uint8List,
          duration: Duration(
              seconds: int.parse(historyItem["durationInSeconds"].toString())),
          maxQuality: int.parse(historyItem["maxQuality"].toString()),
          virtualReality: historyItem["virtualReality"] == 1,
          lastWatched: DateTime.tryParse(historyItem["lastWatched"].toString()),
          firstWatched:
              DateTime.tryParse(historyItem["firstWatched"].toString())));
    }
    return resultsList.reversed.toList();
  }

  static void addToSearchHistory(
      UniversalSearchRequest request, List<PluginInterface> plugins) async {
    logger.d("Adding to search history: ");
    request.printAllAttributes();
    Database db = await getDb();
    await db.insert("search_history", <String, Object?>{
      "plugins": plugins.map((plugin) => plugin.codeName).join(","),
      "searchString": request.searchString,
      "sortingType": request.sortingType,
      "dateRange": request.dateRange,
      "minQuality": request.minQuality,
      "maxQuality": request.maxQuality,
      "minDuration": request.minDuration,
      "maxDuration": request.maxDuration,
      "minFramesPerSecond": request.minFramesPerSecond,
      "maxFramesPerSecond": request.maxFramesPerSecond,
      "virtualReality": request.virtualReality ? 1 : 0,
      "categoriesInclude": request.categoriesInclude.toString(),
      "categoriesExclude": request.categoriesExclude.toString(),
      "keywordsInclude": request.keywordsInclude.toString(),
      "keywordsExclude": request.keywordsExclude.toString()
      // Convert bool to int
    });
    db.close();
  }

  static void addToWatchHistory(
      UniversalSearchResult result, String sourceScreenType) async {
    logger.d("Adding to watch history: ");
    result.printAllAttributes();
    Database db = await getDb();

    // If entry already exists, fetch its firstWatchedOn value
    List<Map<String, Object?>> oldEntry = await db.query("watch_history",
        columns: ["firstWatched"],
        where: "videoID = ?",
        whereArgs: [result.videoID]);
    if (sourceScreenType == "results") {
      Map<String, Object?> newEntryData = {
        "videoID": result.videoID,
        "title": result.title,
        "plugin": result.plugin!.codeName,
        "thumbnailBinary":
            await result.plugin!.downloadThumbnail(Uri.parse(result.thumbnail)),
        "durationInSeconds": result.duration.inSeconds,
        "maxQuality": result.maxQuality,
        "virtualReality": result.virtualReality ? 1 : 0,
        // Convert bool to int
        "author": result.author,
        "lastWatched": DateTime.now().toUtc().toString(),
        "firstWatched": DateTime.now().toUtc().toString()
      };
      if (oldEntry.isNotEmpty) {
        logger.i("Found old entry, updating everything except firstWatched");

        newEntryData["firstWatched"] = oldEntry.first["firstWatched"];
        await db.update(
          "watch_history",
          newEntryData,
          where: "videoID = ?",
          whereArgs: [result.videoID],
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        logger.i("No old entry found, creating new entry");
        await db.insert("watch_history", newEntryData);
      }
    } else {
      logger.i("Found old entry, watching from history, updating lastWatched");
      Map<String, dynamic> updatedEntry =
          Map<String, dynamic>.from(oldEntry.first);
      updatedEntry["lastWatched"] = DateTime.now().toUtc().toString();
      await db.update(
        "watch_history",
        updatedEntry,
        where: "videoID = ?",
        whereArgs: [result.videoID],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    db.close();
  }

  static void addToFavorites(UniversalSearchResult result) async {
    logger.d("Adding to watch history: ");
    result.printAllAttributes();
    Database db = await getDb();
    await db.insert("watch_history", <String, Object?>{
      "videoID": result.videoID,
      "title": result.title,
      "plugin": result.plugin!.codeName,
      "thumbnailBinary":
          await result.plugin!.downloadThumbnail(Uri.parse(result.thumbnail)),
      "durationInSeconds": result.duration.inSeconds,
      "maxQuality": result.maxQuality,
      "virtualReality": result.virtualReality ? 1 : 0,
      // Convert bool to int
      "author": result.author,
      "addedOn": DateTime.now().toUtc().toString(),
    });
    db.close();
  }

  static void removeFromSearchHistory(UniversalSearchRequest request) async {
    logger.d("Removing from search history: ");
    request.printAllAttributes();
    Database db = await getDb();
    await db.delete("search_history",
        where: "searchString = ?", whereArgs: [request.searchString]);
    db.close();
  }

  static void removeFromWatchHistory(UniversalSearchResult result) async {
    logger.d("Removing from watch history: ");
    result.printAllAttributes();
    Database db = await getDb();
    await db.delete("watch_history",
        where: "videoID = ?", whereArgs: [result.videoID]);
    db.close();
  }

  static void removeFromFavorites(UniversalSearchResult result) async {
    logger.d("Removing from favorites: ");
    result.printAllAttributes();
    Database db = await getDb();
    await db.delete("watch_history",
        where: "videoID = ?", whereArgs: [result.videoID]);
    db.close();
  }
}
