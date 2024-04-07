import 'dart:io';

import 'package:hedon_viewer/backend/universal_formats.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../plugin_base.dart';

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
      print("Linux detected, initializing sqflite_ffi");
      sqfliteFfiInit();
    }
    databaseFactory = databaseFactoryFfi;
    getDB("histories.db");
    getDB("favorites.db");
  }

  static Future<Database> getDB(String dbName) async {
    Directory appSupportDir = await getApplicationSupportDirectory();
    String dbPath = "${appSupportDir.path}/$dbName";

    print("Opening $dbName database at $dbPath");
    Database db = await openDatabase(dbPath, version: 1,
        onCreate: (Database db, int version) async {
      print("No $dbName database detected, creating new");
      switch (dbName) {
        case 'histories.db':
          initHistoriesDb(db);
          break;
        case 'favorites.db':
          initFavoritesDb(db);
          break;
      }
    }, onUpgrade: (Database db, int oldVersion, int newVersion) async {
      print("Database upgrade from $oldVersion to $newVersion");
      // TODO: Implement database upgrades if needed
    }, onDowngrade: (Database db, int oldVersion, int newVersion) async {
      print("UNEXPECTED $dbName DOWNGRADE! Backing up to ${dbName}_old");
      // copy database to old database
      await File(dbPath).copy("${dbPath}_old");
      print("DROPPING ALL TABLES TO PREVENT ERRORS");
      switch (dbName) {
        case 'histories.db':
          await db.execute("DROP TABLE watch_history");
          await db.execute("DROP TABLE search_history");
          initHistoriesDb(db);
          break;
        case 'favorites.db':
          await db.execute("DROP TABLE favorites");
          initFavoritesDb(db);
          break;
      }
    });
    return db;
  }

  /// Delete all rows from a table
  static void deleteAll(String dbName, String tableName) {
    getDB(dbName).then((db) {
      db.execute("DELETE FROM $tableName");
    });
  }

  static void initHistoriesDb(Database db) async {
    // Reimplementation of some parts of UniversalSearchResult
    // This is only used to show a preview in the history screen
    // If the user decides to replay a video from history, the corresponding
    // provider will be called upon to fetch fresh video metadata
    // Storing videoPreview would take up a lot of storage
    // TODO: Make it optional to store video previews?
    await db.execute('''
        CREATE TABLE watch_history (
          id INTEGER PRIMARY KEY,
          videoID TEXT,
          title TEXT,
          provider TEXT,
          thumbnail BLOB,
          durationInSeconds INTEGER,
          maxQuality INTEGER,
          virtualReality INTEGER,
          author TEXT,
          firstWatched Text,
          lastWatched TEXT
        )
        ''');
    // Reimplementation of UniversalSearchRequest
    // Providers is a list of providers the search was attempted on
    // virtualReality is actually a boolean
    await db.execute('''
        CREATE TABLE search_history (
          id INTEGER PRIMARY KEY,
          searchString TEXT,
          providers TEXT,
          minimalFramesPerSecond INTEGER,
          minimalQuality INTEGER,
          minimalDuration INTEGER,
          maximalDuration INTEGER,
          categories TEXT,
          sortingType TEXT,
          timeframe TEXT,
          virtualReality INTEGER
        )
      ''');
  }

  static void initFavoritesDb(Database db) async {
    // Reimplementation of some parts of UniversalSearchResult
    // This is only used to show a preview in the history screen
    // If the user decides to replay a video from history, the corresponding
    // provider will be called upon to fetch fresh video metadata
    // Storing videoPreview would take up a lot of storage
    // TODO: Make it optional to store video previews?
    await db.execute('''
        CREATE TABLE favorites (
          id INTEGER PRIMARY KEY,
          videoID TEXT,
          title TEXT,
          provider TEXT,
          thumbnail BLOB,
          durationInSeconds INTEGER,
          maxQuality INTEGER,
          virtualReality INTEGER,
          author TEXT,
          addedOn Text
        )
        ''');
  }

  static Future<List<Map<String, Object?>>> getAllFrom(
      String dbName, String tableName) async {
    Database db = await getDB(dbName);
    List<Map<String, Object?>> results = await db.query(tableName);
    db.close();
    return results;
  }

  static void addToSearchHistory(
      UniversalSearchRequest request, List<PluginBase> providers) async {
    print("Adding to search history: ");
    request.printAllAttributes();
    Database db = await getDB("histories.db");
    ;
    await db.insert("search_history", <String, Object?>{
      "searchString": request.searchString,
      "providers": providers.map((p) => p.pluginName).join(","),
      "minimalFramesPerSecond": request.minimalFramesPerSecond,
      "minimalQuality": request.minimalQuality,
      "minimalDuration": request.minimalDuration,
      "categories": request.categories.toString(),
      "sortingType": request.sortingType,
      "timeframe": request.timeframe,
      "virtualReality": request.virtualReality ? 1 : 0 // Convert bool to int
    });
    db.close();
  }

  static void addToWatchHistory(UniversalSearchResult result) async {
    print("Adding to watch history: ");
    result.printAllAttributes();
    Database db = await getDB("histories.db");

    Map<String, Object?> newEntryData = {
      "videoID": result.videoID,
      "title": result.title,
      "provider": result.provider!.pluginName,
      "thumbnail":
          await result.provider!.downloadThumbnail(Uri.parse(result.thumbnail)),
      "durationInSeconds": result.duration.inSeconds,
      "maxQuality": result.maxQuality,
      "virtualReality": result.virtualReality ? 1 : 0,
      // Convert bool to int
      "author": result.author,
      "lastWatched": DateTime.now().toUtc().toString(),
      "firstWatched": DateTime.now().toUtc().toString()
    };

    // If entry already exists, fetch its firstWatchedOn value
    List<Map<String, Object?>> oldEntry = await db.query("watch_history",
        columns: ["firstWatched"],
        where: "videoID = ?",
        whereArgs: [result.videoID]);
    if (oldEntry.isNotEmpty) {
      print("Found old entry, updating everything except firstWatched");
      newEntryData["firstWatched"] = oldEntry[0]["firstWatched"];
      await db.update(
        "watch_history",
        newEntryData,
        where: "videoID = ?",
        whereArgs: [result.videoID],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      print("No old entry found, creating new entry");
      await db.insert("watch_history", newEntryData);
    }

    db.close();
  }

  static void addToFavorites(UniversalSearchResult result) async {
    print("Adding to watch history: ");
    result.printAllAttributes();
    Database db = await getDB("histories.db");
    await db.insert("watch_history", <String, Object?>{
      "videoID": result.videoID,
      "title": result.title,
      "provider": result.provider!.pluginName,
      "thumbnail":
          await result.provider!.downloadThumbnail(Uri.parse(result.thumbnail)),
      "durationInSeconds": result.duration.inSeconds,
      "maxQuality": result.maxQuality,
      "virtualReality": result.virtualReality ? 1 : 0,
      // Convert bool to int
      "author": result.author,
      "addedOn": DateTime.now().toUtc().toString(),
    });
  }

  static void removeFromSearchHistory(UniversalSearchRequest request) async {
    print("Removing from search history: ");
    request.printAllAttributes();
    Database db = await getDB("histories.db");
    await db.delete("search_history",
        where: "searchString = ?", whereArgs: [request.searchString]);
  }

  static void removeFromWatchHistory(UniversalSearchResult result) async {
    print("Removing from watch history: ");
    result.printAllAttributes();
    Database db = await getDB("histories.db");
    await db.delete("watch_history",
        where: "videoID = ?", whereArgs: [result.videoID]);
  }

  static void removeFromFavorites(UniversalSearchResult result) async {
    print("Removing from favorites: ");
    result.printAllAttributes();
    Database db = await getDB("histories.db");
    await db.delete("watch_history",
        where: "videoID = ?", whereArgs: [result.videoID]);
  }
}
