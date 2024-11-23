import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '/backend/managers/plugin_manager.dart';
import '/backend/plugin_interface.dart';
import '/backend/universal_formats.dart';
import '/main.dart';

late Database _database;

bool _factoryInitialized = false;

Future<void> initDb() async {
  if (!_factoryInitialized) {
    logger.i("Initializing database backend");
    if (Platform.isLinux) {
      logger.i("Linux detected, initializing sqflite_ffi");
      sqfliteFfiInit();
    }
    databaseFactory = databaseFactoryFfi;
    _factoryInitialized = true;
  } else {
    logger.i("Database backend already initialized. Skipping...");
  }

  Directory appSupportDir = await getApplicationSupportDirectory();
  String dbPath = "${appSupportDir.path}/hedon_haven.db";

  logger.i("Opening database at $dbPath");
  await openDatabase(dbPath, version: 1,
      onCreate: (Database db, int version) async {
    _database = db;
    logger.i("No database detected, creating new");
    createDefaultTables();
  }, onUpgrade: (Database db, int oldVersion, int newVersion) async {
    _database = db;
    logger.i("Database upgrade from $oldVersion to $newVersion");
    // TODO: Implement database upgrades if needed
  }, onDowngrade: (Database db, int oldVersion, int newVersion) async {
    _database = db;
    logger.w("UNEXPECTED DATABASE DOWNGRADE! Backing up to hedon_haven.db_old");
    // copy database to old database
    await File(dbPath).copy("${dbPath}_old");
    logger.w("DROPPING ALL TABLES TO PREVENT ERRORS!!!");
    await db.execute("DROP TABLE watch_history");
    await db.execute("DROP TABLE search_history");
    await db.execute("DROP TABLE favorites");
    createDefaultTables();
  }, onOpen: (Database db) async {
    _database = db;
    logger.i("Database opened successfully");
  });
}

Future<void> closeDb() async {
  // Ensure any transaction is committed
  await _database
      .execute('COMMIT;')
      .onError((_, __) => logger.d("Nothing to commit before closing db"));
  // Ensure all data is flushed to disk
  await _database
      .execute('PRAGMA synchronous = FULL;')
      .onError((_, __) => logger.d("Nothing to sync before closing db"));
  await _database.close();
}

/// Delete all rows from a table
/// Possible tableNames: watch_history, search_history, favorites
void deleteAllFrom(String tableName) {
  logger.w("Deleting all rows from $tableName");
  _database.execute("DELETE FROM $tableName");
}

/// Unlike deleteAllFrom, this deletes the database file itself
Future<void> purgeDatabase() async {
  logger.w("Purging database");
  logger.i("Closing old db");
  await closeDb();
  Directory appSupportDir = await getApplicationSupportDirectory();
  File databaseFile = File("${appSupportDir.path}/hedon_haven.db");
  if (await databaseFile.exists()) {
    await databaseFile.delete();
    logger.i("Database deleted successfully");
  } else {
    logger.w("Database not found, nothing was deleted");
  }
}

void createDefaultTables() async {
  logger.i("Creating default tables in database");
  // Reimplementation of some parts of UniversalSearchResult
  // This is only used to show a preview in the history screen
  // If the user decides to replay a video from history, the corresponding
  // plugin will be called upon to fetch fresh video metadata
  // Storing videoPreview would take up a lot of storage
  // TODO: Make it optional to store video previews?
  await _database.execute('''
        CREATE TABLE watch_history (
          id INTEGER PRIMARY KEY,
          videoID TEXT,
          title TEXT,
          plugin TEXT,
          thumbnailBinary BLOB,
          durationInSeconds INTEGER,
          maxQuality INTEGER,
          virtualReality INTEGER,
          author TEXT,
          verifiedAuthor INTEGER,
          lastWatched TEXT,
          addedOn Text
        )
        ''');
  // Reimplementation of UniversalSearchRequest
  // Plugins is a list of plugins the search was attempted on
  // virtualReality is actually a boolean
  // categories and keywords are actually lists of strings
  await _database.execute('''
        CREATE TABLE search_history (
          id INTEGER PRIMARY KEY,
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
  await _database.execute('''
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
          verifiedAuthor INTEGER,
          addedOn Text
        )
        ''');
}

Future<List<Map<String, Object?>>> getAllFrom(
    String dbName, String tableName) async {
  logger.i("Getting all rows from $tableName");
  return await _database.query(tableName);
}

Future<List<UniversalSearchRequest>> getSearchHistory() async {
  logger.i("Getting search history");
  List<Map<String, Object?>> results = await _database.query("search_history");
  List<UniversalSearchRequest> resultsList = [];

  logger.i("Converting search history");
  for (var historyItem in results) {
    resultsList.add(UniversalSearchRequest(
      searchString: historyItem["searchString"] as String,
      sortingType: historyItem["sortingType"] as String,
      dateRange: historyItem["dateRange"] as String,
      minQuality: historyItem["minQuality"] as int,
      maxQuality: historyItem["maxQuality"] as int,
      minDuration: historyItem["minDuration"] as int,
      maxDuration: historyItem["maxDuration"] as int,
      minFramesPerSecond: historyItem["minFramesPerSecond"] as int,
      maxFramesPerSecond: historyItem["maxFramesPerSecond"] as int,
      virtualReality: historyItem["virtualReality"] as int == 1,
      categoriesInclude: List<String>.from(
          jsonDecode(historyItem["categoriesInclude"] as String)),
      categoriesExclude: List<String>.from(
          jsonDecode(historyItem["categoriesExclude"] as String)),
      keywordsInclude: List<String>.from(
          jsonDecode(historyItem["keywordsInclude"] as String)),
      keywordsExclude: List<String>.from(
          jsonDecode(historyItem["keywordsExclude"] as String)),
      historySearch: true,
    ));
  }

  return resultsList.reversed.toList();
}

Future<List<UniversalVideoPreview>> getWatchHistory() async {
  List<Map<String, Object?>> results = await _database.query("watch_history");
  List<UniversalVideoPreview> resultsList = [];

  for (var historyItem in results) {
    resultsList.add(UniversalVideoPreview(
        videoID: historyItem["videoID"] as String,
        title: historyItem["title"] as String,
        plugin: PluginManager.getPluginByName(historyItem["plugin"] as String),
        thumbnailBinary: historyItem["thumbnailBinary"] as Uint8List,
        duration: historyItem["durationInSeconds"] as int == -1
            ? null
            : Duration(seconds: historyItem["durationInSeconds"] as int),
        maxQuality: historyItem["maxQuality"] as int == -1
            ? null
            : historyItem["maxQuality"] as int,
        virtualReality: historyItem["virtualReality"] as int == 1,
        author: historyItem["author"] as String == "null"
            ? null
            : historyItem["author"] as String,
        verifiedAuthor: historyItem["verifiedAuthor"] as int == 1,
        // convert string back to bool
        lastWatched: DateTime.tryParse(historyItem["lastWatched"] as String),
        addedOn: DateTime.tryParse(historyItem["addedOn"] as String)));
  }
  return resultsList.reversed.toList();
}

Future<List<UniversalVideoPreview>> getFavorites() async {
  List<Map<String, Object?>> results = await _database.query("favorites");
  List<UniversalVideoPreview> resultsList = [];

  for (var favorite in results) {
    resultsList.add(UniversalVideoPreview(
        videoID: favorite["videoID"] as String,
        title: favorite["title"] as String,
        plugin: PluginManager.getPluginByName(favorite["plugin"] as String),
        thumbnail: favorite["thumbnail"] as String == "null"
            ? null
            : favorite["thumbnail"] as String,
        duration: favorite["durationInSeconds"] as int == -1
            ? null
            : Duration(seconds: favorite["durationInSeconds"] as int),
        maxQuality: favorite["maxQuality"] as int == -1
            ? null
            : favorite["maxQuality"] as int,
        virtualReality: favorite["virtualReality"] == "1",
        author: favorite["author"] as String == "null"
            ? null
            : favorite["author"] as String,
        verifiedAuthor: favorite["verifiedAuthor"] as int == 1,
        addedOn: DateTime.tryParse(favorite["addedOn"] as String)));
  }
  return resultsList.toList();
}

void addToSearchHistory(
    UniversalSearchRequest request, List<PluginInterface> plugins) async {
  if (!(await sharedStorage.getBool("enable_search_history"))!) {
    logger.i("Search history disabled, not adding");
    return;
  }
  logger.d("Adding to search history: ");
  request.printAllAttributes();

  // Delete old entry
  List<Map<String, Object?>> oldEntry = await _database.query("search_history",
      where: "searchString = ?", whereArgs: [request.searchString]);
  if (oldEntry.isNotEmpty) {
    logger.i("Found old entry, deleting");
    await _database.delete("search_history",
        where: "searchString = ?", whereArgs: [request.searchString]);
  }
  logger.i("Adding new entry");
  await _database.insert("search_history", {
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
    "categoriesInclude": jsonEncode(request.categoriesInclude),
    "categoriesExclude": jsonEncode(request.categoriesExclude),
    "keywordsInclude": jsonEncode(request.keywordsInclude),
    "keywordsExclude": jsonEncode(request.keywordsExclude)
  });
}

void addToWatchHistory(
    UniversalVideoPreview result, String sourceScreenType) async {
  if (!(await sharedStorage.getBool("enable_watch_history"))!) {
    logger.i("Watch history disabled, not adding");
    return;
  }
  logger.d("Adding to watch history: ");
  result.printAllAttributes();

  // If entry already exists, fetch its addedOn value
  List<Map<String, Object?>> oldEntry = await _database.query("watch_history",
      columns: ["addedOn"], where: "videoID = ?", whereArgs: [result.videoID]);
  if (["homepage", "results"].contains(sourceScreenType)) {
    Map<String, Object?> newEntryData = {
      "videoID": result.videoID,
      "title": result.title,
      "plugin": result.plugin?.codeName ?? "null",
      "thumbnailBinary": await result.plugin
              ?.downloadThumbnail(Uri.parse(result.thumbnail ?? "")) ??
          Uint8List(0),
      "durationInSeconds": result.duration?.inSeconds ?? -1,
      "maxQuality": result.maxQuality ?? -1,
      "virtualReality": result.virtualReality ? 1 : 0,
      "author": result.author ?? "null",
      "verifiedAuthor": result.verifiedAuthor ? 1 : 0,
      "lastWatched": DateTime.now().toUtc().toString(),
      "addedOn": DateTime.now().toUtc().toString()
    };
    if (oldEntry.isNotEmpty) {
      logger.i("Found old entry, updating everything except addedOn");
      newEntryData["addedOn"] = oldEntry.first["addedOn"];
      await _database.update(
        "watch_history",
        newEntryData,
        where: "videoID = ?",
        whereArgs: [result.videoID],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      logger.i("No old entry found, creating new entry");
      await _database.insert("watch_history", newEntryData);
    }
  } else if (sourceScreenType == "history") {
    if (oldEntry.isEmpty) {
      logger.e(
          "Watching from history, but no old history entry found??? REPORT TO DEVS");
      return;
    }
    logger.i("Watching from history, updating lastWatched");
    Map<String, dynamic> updatedEntry =
        Map<String, dynamic>.from(oldEntry.first);
    updatedEntry["lastWatched"] = DateTime.now().toUtc().toString();
    await _database.update(
      "watch_history",
      updatedEntry,
      where: "videoID = ?",
      whereArgs: [result.videoID],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  } else {
    logger.e("Unknown / unhandled screen type. REPORT TO DEVS");
  }
}

void addToFavorites(UniversalVideoPreview result) async {
  logger.d("Adding to favorites: ");
  result.printAllAttributes();
  await _database.insert("favorites", <String, Object?>{
    "videoID": result.videoID,
    "title": result.title,
    "plugin": result.plugin?.codeName ?? "null",
    "thumbnailBinary": await result.plugin
            ?.downloadThumbnail(Uri.parse(result.thumbnail ?? "")) ??
        Uint8List(0),
    "durationInSeconds": result.duration?.inSeconds ?? -1,
    "maxQuality": result.maxQuality ?? -1,
    "virtualReality": result.virtualReality ? 1 : 0,
    "author": result.author ?? "null",
    "verifiedAuthor": result.verifiedAuthor ? 1 : 0,
    "addedOn": DateTime.now().toUtc().toString(),
  });
}

void removeFromSearchHistory(UniversalSearchRequest request) async {
  logger.d("Removing from search history: ");
  request.printAllAttributes();
  await _database.delete("search_history",
      where: "searchString = ?", whereArgs: [request.searchString]);
}

void removeFromWatchHistory(UniversalVideoPreview result) async {
  logger.d("Removing from watch history: ");
  result.printAllAttributes();
  await _database.delete("watch_history",
      where: "videoID = ?", whereArgs: [result.videoID]);
}

void removeFromFavorites(UniversalVideoPreview result) async {
  logger.d("Removing from favorites: ");
  result.printAllAttributes();
  await _database.delete("watch_history",
      where: "videoID = ?", whereArgs: [result.videoID]);
}
