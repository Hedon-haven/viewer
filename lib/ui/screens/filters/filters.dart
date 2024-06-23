import 'package:flutter/material.dart';

import '/backend/managers/shared_prefs_manager.dart';
import '/backend/universal_formats.dart';
import '/main.dart';
import '/ui/screens/settings/custom_widgets/options_dialog.dart';
import '/ui/screens/settings/custom_widgets/options_switch.dart';
import '/ui/toast_notification.dart';

class FilterScreen extends StatefulWidget {
  UniversalSearchRequest previousSearch;

  FilterScreen({super.key, required this.previousSearch});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  String sortingType = "";
  String dateRange = "";
  bool sortReverse = false;
  double minQuality = 0;
  double maxQuality = 8;
  double minDuration = 0;
  double maxDuration = 5;
  double minFps = 0;
  double maxFps = 60;

  final List<int> qualities = [0, 144, 240, 360, 480, 720, 1080, 1440, 2160];

  final List<int> durationsInSeconds = [
    0,
    300,
    600,
    1200,
    1800,
    3600
  ]; // 60 == infinite

  /// Use refreshFromSettings = false, if the current settings from the filter screen should be used, instead of loading from the shared prefs
  UniversalSearchRequest applyStoredFilters(UniversalSearchRequest request,
      [bool refreshFromSettings = true]) {
    if (refreshFromSettings) {
      logger.i("refreshing filters from sharedPrefs");
      loadStoredFilters();
    }
    request.sortingType = sortingType;
    request.dateRange = dateRange;
    request.minQuality = qualities[minQuality.toInt()];
    request.maxQuality = qualities[maxQuality.toInt()];
    request.minDuration = durationsInSeconds[minDuration.toInt()];
    request.maxDuration = durationsInSeconds[maxDuration.toInt()];
    request.minFramesPerSecond = minFps.toInt();
    request.maxFramesPerSecond = maxFps.toInt();
    return request;
  }

  void loadStoredFilters() {
    sortingType = sharedStorage.getString("sort_order")!;
    dateRange = sharedStorage.getString("sort_date_range")!;
    sortReverse = sharedStorage.getBool("sort_reverse")!;
    minQuality =
        qualities.indexOf(sharedStorage.getInt("sort_quality_min")!).toDouble();
    maxQuality =
        qualities.indexOf(sharedStorage.getInt("sort_quality_max")!).toDouble();
    minDuration = durationsInSeconds
        .indexOf(sharedStorage.getInt("sort_duration_min")!)
        .toDouble();
    maxDuration = durationsInSeconds
        .indexOf(sharedStorage.getInt("sort_duration_max")!)
        .toDouble();
  }

  @override
  void initState() {
    super.initState();
    loadStoredFilters();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        onPopInvoked: (_) {
          logger.i("Saving filters to sharedPrefs");
          // save all settings to sharedStorage to be able to restore them when user returns to screen
          sharedStorage.setString("sort_order", sortingType);
          sharedStorage.setString("sort_date_range", dateRange);
          sharedStorage.setBool("sort_reverse", sortReverse);
          // convert slider values to their actual resolutions
          sharedStorage.setInt(
              "sort_quality_min", qualities[minQuality.toInt()]);
          sharedStorage.setInt(
              "sort_quality_max", qualities[maxQuality.toInt()]);
          sharedStorage.setInt(
              "sort_duration_min", durationsInSeconds[minDuration.toInt()]);
          sharedStorage.setInt(
              "sort_duration_max", durationsInSeconds[maxDuration.toInt()]);
          logger.i("Modifying universal search request parameters");
          applyStoredFilters(widget.previousSearch, false);
        },
        child: Scaffold(
            appBar: AppBar(
              title: const Text("Search filters"),
              iconTheme:
                  IconThemeData(color: Theme.of(context).colorScheme.primary),
              leading: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check),
                //replace with our own icon data.
              ),
              actions: [
                IconButton(
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    setState(() {
                      SharedPrefsManager().setDefaultFilterSettings();
                      loadStoredFilters();
                    });
                  },
                  // TODO: Find proper restore icon without dot in the middle
                  icon: const Icon(Icons.settings_backup_restore),
                )
              ],
            ),
            body: SafeArea(
                child: SingleChildScrollView(
              child: Column(children: [
                DialogTile(
                    title: "Sort by",
                    subtitle: sortingType,
                    options: const [
                      "Relevance",
                      "Upload date",
                      "Views",
                      "Rating",
                      "Duration"
                    ],
                    selectedOption: sortingType,
                    onSelected: (value) {
                      setState(() {
                        sortingType = value;
                      }); // Update the widget
                    }),
                DialogTile(
                    title: "Date range",
                    subtitle: dateRange,
                    options: const [
                      "All time",
                      "Last year",
                      "Last month",
                      "Last week",
                      "Last day/Last 3 days/Latest"
                      // aka last 3 days or latest on some websites
                    ],
                    selectedOption: sortingType,
                    onSelected: (value) {
                      setState(() {
                        dateRange = value;
                      }); // Update the widget
                    }),
                ListTile(
                    title: const Text("Categories"),
                    subtitle: const Text("Categories to be included/excluded"),
                    onTap: () {
                      // go to categories screen
                    }),
                ListTile(
                    title: const Text("Keywords"),
                    subtitle: const Text("Keywords to be included/excluded"),
                    onTap: () {
                      // go to categories screen
                    }),
                Padding(
                    padding: const EdgeInsets.only(left: 16, right: 20),
                    child: Column(children: [
                      Row(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(width: 80, child: Text("Quality:")),
                            Expanded(
                                child: RangeSlider(
                              min: 0,
                              max: 8,
                              divisions: 8,
                              labels: RangeLabels(
                                // display actual resolutions, not the slider values
                                "${qualities[minQuality.toInt()]}p",
                                "${qualities[maxQuality.toInt()]}p",
                              ),
                              values: RangeValues(minQuality, maxQuality),
                              onChanged: (values) {
                                setState(() {
                                  minQuality = values.start;
                                  maxQuality = values.end;
                                });
                              },
                            ))
                          ]),
                      Row(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(width: 80, child: Text("Duration:")),
                            Expanded(
                                child: RangeSlider(
                              min: 0,
                              max: 5,
                              divisions: 5,
                              labels: RangeLabels(
                                // display actual resolutions, not the slider values
                                // .toStringAsFixed(0) removes the .0 at the end
                                "${(durationsInSeconds[minDuration.toInt()] / 60).toStringAsFixed(0)} min",
                                maxDuration <= 4
                                    ? "${(durationsInSeconds[maxDuration.toInt()] / 60).toStringAsFixed(0)} min"
                                    : "60+ min",
                              ),
                              values: RangeValues(minDuration, maxDuration),
                              onChanged: (values) {
                                setState(() {
                                  minDuration = values.start;
                                  maxDuration = values.end;
                                });
                              },
                            ))
                          ]),
                      Row(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(width: 80, child: Text("FPS:")),
                            Expanded(
                                child: RangeSlider(
                              min: 0,
                              max: 60,
                              divisions: 2,
                              labels: RangeLabels(
                                // display actual resolutions, not the slider values
                                minFps == 0 ? "0/unknown fps" : "$minFps fps",
                                maxFps == 60 ? "60+ fps" : "$maxFps fps",
                              ),
                              values: RangeValues(minFps, maxFps),
                              onChanged: (values) {
                                setState(() {
                                  minFps = values.start;
                                  maxFps = values.end;
                                });
                              },
                            ))
                          ]),
                      OptionsSwitch(
                          title: "Virtual reality",
                          subTitle: "Include virtual reality videos",
                          reduceBorders: true,
                          switchState: false,
                          nonInteractive: true,
                          onToggled: (value) => ToastMessageShower.showToast(
                              "VR is not yet implemented", context)),
                      OptionsSwitch(
                          title: "Reverse order",
                          subTitle: "Display results in reverse order",
                          reduceBorders: true,
                          nonInteractive: true,
                          switchState: false,
                          onToggled: (value) {
                            //setState(() => sortReverse = value);
                            // TODO: Add reverse search
                            ToastMessageShower.showToast(
                                "Reverse search is not yet implemented",
                                context);
                          })
                    ])),
              ]),
            ))));
  }
}
