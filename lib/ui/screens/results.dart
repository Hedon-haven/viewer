import 'package:flutter/material.dart';
import 'package:hedon_viewer/base/universal_formats.dart';

import 'video_player.dart';

class ResultsScreen extends StatelessWidget {
  final List<UniversalSearchResult> videoResults;

  const ResultsScreen({super.key, required this.videoResults});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // go back to search screen
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SafeArea(
          child: _ResultsScreenWidget(
        videoResults: videoResults,
      )),
    );
  }
}

class _ResultsScreenWidget extends StatefulWidget {
  final List<UniversalSearchResult> videoResults;

  const _ResultsScreenWidget({required this.videoResults});

  @override
  State<_ResultsScreenWidget> createState() => _ResultsScreenWidgetState();
}

class _ResultsScreenWidgetState extends State<_ResultsScreenWidget> {
  int? _clickedChildIndex;

  Future<UniversalVideoMetadata> getVideoMetaData(
      UniversalSearchResult result) async {
    return await result.pluginOrigin!
        .getVideoMetadataAsUniversalFormat(result.videoID);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: widget.videoResults.isEmpty
            // add a text saying no results to the top
            ? Center(
                child: Container(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height * 0.5),
                child: const Text(
                  "No results found",
                  style: TextStyle(fontSize: 20),
                ),
              ))
            : GridView.builder(
                padding: const EdgeInsets.all(4.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 4.0,
                  mainAxisSpacing: 4.0,
                ),
                itemCount: widget.videoResults.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () async {
                      setState(() {
                        _clickedChildIndex = index;
                      });
                      UniversalVideoMetadata videoMeta =
                          await getVideoMetaData(widget.videoResults[index]);
                      setState(() {
                        _clickedChildIndex = null;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerScreen(
                              videoMetadata: videoMeta,
                            ),
                          ),
                        );
                      });
                    },
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      shape: const ContinuousRectangleBorder(),
                      elevation: 2.0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(children: [
                            _clickedChildIndex == index
                                ? const CircularProgressIndicator()
                                : widget.videoResults[index].thumbnail != ""
                                    ? Image.network(
                                        widget.videoResults[index].thumbnail)
                                    : const Placeholder(),
                            // show video quality
                            Positioned(
                                right: 2.0,
                                bottom: 2.0,
                                child: Container(
                                    padding: const EdgeInsets.only(
                                        left: 2.0, right: 2.0),
                                    decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius:
                                            BorderRadius.circular(4.0),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black45,
                                            spreadRadius: 3,
                                            blurRadius: 8,
                                          ),
                                        ]),
                                    child: Text(
                                        style: const TextStyle(
                                          fontSize: 14,
                                        ),
                                        switch (widget
                                            .videoResults[index].maxQuality) {
                                          VideoResolution.below720 => "<720p",
                                          VideoResolution.hd720 => "720p",
                                          VideoResolution.hd1080 => "1080p",
                                          VideoResolution.hd4K => "4K",
                                          VideoResolution.above4k => "2160p",
                                          // check if vr
                                          VideoResolution.unknown => widget
                                                  .videoResults[index]
                                                  .virtualReality
                                              ? "VR"
                                              : "Unknown",
                                        })))
                          ]),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              widget.videoResults[index].title,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
