import 'package:flutter/material.dart';

import '/services/shared_prefs_manager.dart';
import '/ui/utils/toast_notification.dart';
import '/ui/widgets/options_dialog.dart';
import '/ui/widgets/options_switch.dart';
import '/utils/global_vars.dart';
import '/utils/universal_formats.dart';

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
  bool virtualReality = false;
  bool reverseOrder = false;

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
  void applyStoredFilters({bool refreshFromSettings = true}) async {
    if (refreshFromSettings) {
      logger.i("refreshing filters from sharedPrefs");
      await loadStoredFilters();
    }
    widget.previousSearch.sortingType = sortingType;
    widget.previousSearch.dateRange = dateRange;
    widget.previousSearch.minQuality = qualities[minQuality.toInt()];
    widget.previousSearch.maxQuality = qualities[maxQuality.toInt()];
    widget.previousSearch.minDuration = durationsInSeconds[minDuration.toInt()];
    widget.previousSearch.maxDuration = durationsInSeconds[maxDuration.toInt()];
    widget.previousSearch.minFramesPerSecond = minFps.toInt();
    widget.previousSearch.maxFramesPerSecond = maxFps.toInt();
  }

  Future<void> loadStoredFilters() async {
    sortingType = (await sharedStorage.getString("filter_order"))!;
    dateRange = (await sharedStorage.getString("filter_date_range"))!;
    sortReverse = (await sharedStorage.getBool("filter_reverse"))!;
    minQuality = qualities
        .indexOf((await sharedStorage.getInt("filter_quality_min"))!)
        .toDouble();
    maxQuality = qualities
        .indexOf((await sharedStorage.getInt("filter_quality_max"))!)
        .toDouble();
    minDuration = durationsInSeconds
        .indexOf((await sharedStorage.getInt("filter_duration_min"))!)
        .toDouble();
    maxDuration = durationsInSeconds
        .indexOf((await sharedStorage.getInt("filter_duration_max"))!)
        .toDouble();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loadStoredFilters();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        onPopInvoked: (_) async {
          logger.i("Saving filters to sharedPrefs");
          // save all settings to sharedStorage to be able to restore them when user returns to screen
          await sharedStorage.setString("filter_order", sortingType);
          await sharedStorage.setString("filter_date_range", dateRange);
          await sharedStorage.setBool("filter_reverse", sortReverse);
          // convert slider values to their actual resolutions
          await sharedStorage.setInt(
              "filter_quality_min", qualities[minQuality.toInt()]);
          await sharedStorage.setInt(
              "filter_quality_max", qualities[maxQuality.toInt()]);
          await sharedStorage.setInt(
              "filter_duration_min", durationsInSeconds[minDuration.toInt()]);
          await sharedStorage.setInt(
              "filter_duration_max", durationsInSeconds[maxDuration.toInt()]);
          logger.i("Modifying universal search request parameters");
          applyStoredFilters(refreshFromSettings: false);
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
                  onPressed: () async {
                    await setDefaultFilterSettings();
                    await loadStoredFilters();
                    showToast("Filters reset to default", context);
                    setState(() {});
                  },
                  // TODO: Find proper restore icon without dot in the middle
                  icon: const Icon(Icons.settings_backup_restore),
                )
              ],
            ),
            body: SafeArea(
                child: SingleChildScrollView(
              child: Column(children: [
                OptionsTile(
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
                OptionsTile(
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
                    selectedOption: dateRange,
                    onSelected: (value) {
                      setState(() {
                        dateRange = value;
                      }); // Update the widget
                    }),
                ListTile(
                    title: const Text("Categories"),
                    subtitle: const Text("Categories to be included/excluded"),
                    onTap: () {
                      showToast("Categories are not yet implemented", context);
                    }),
                ListTile(
                    title: const Text("Keywords"),
                    subtitle: const Text("Keywords to be included/excluded"),
                    onTap: () {
                      showToast("Keywords are not yet implemented", context);
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
                          switchState: virtualReality,
                          onToggled: (value) {
                            showToast("VR is not yet implemented", context);
                            setState(() => virtualReality = false);
                          }),
                      OptionsSwitch(
                          title: "Reverse order",
                          subTitle: "Display results in reverse order",
                          reduceBorders: true,
                          switchState: reverseOrder,
                          onToggled: (value) {
                            showToast("Reverse search is not yet implemented",
                                context);
                            setState(() => reverseOrder = false);
                          })
                    ])),
              ]),
            ))));
  }
}
