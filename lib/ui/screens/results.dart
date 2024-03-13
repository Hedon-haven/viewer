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
        actions: const [
          //           IconButton(
          //             icon: const Icon(Icons.search),
          //             onPressed: () {
          //               // go back to search screen
          //               Navigator.pop(context);
          //             },
          //           ),
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
    return await result.pluginOrigin!.getVideoMetadata(result.videoID);
  }

  /// Convert raw views into a human readable format, e.g. 100k
  /// Division will automatically round the number up/down
  /// This function might need to be moved somewhere more generic to allow it to be reused
  String convertViewsIntoHumanReadable(int views) {
    if (views < 1000) {
      return views.toString();
      // <100k
    } else if (views < 100000) {
      return "${(views / 1000).toStringAsFixed(1)}K";
      // <1M
    } else if (views < 1000000) {
      return "${(views / 1000).toStringAsFixed(0)}K";
      // <10M
    } else if (views < 10000000) {
      return "${(views / 1000000).toStringAsFixed(1)}M";
      // >10M
    } else {
      return "${(views / 1000000).toStringAsFixed(0)}M";
    }
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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ClipRect contains the shadow spreads to just the preview
                                ClipRect(
                                    child: Stack(children: [
                                  SizedBox(
                                      width: constraints.maxWidth,
                                      height: constraints.maxWidth * 9 / 16,
                                      child: _clickedChildIndex == index
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator())
                                          : widget.videoResults[index]
                                                      .thumbnail !=
                                                  ""
                                              ? Image.network(
                                                  widget.videoResults[index]
                                                      .thumbnail,
                                                  fit: BoxFit.fill)
                                              : const Placeholder()),
                                  // show video quality
                                  Positioned(
                                      right: 2.0,
                                      top: 2.0,
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
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                              switch (widget.videoResults[index]
                                                  .maxQuality) {
                                                VideoResolution.below720 =>
                                                  "<720p",
                                                VideoResolution.hd720 => "720p",
                                                VideoResolution.hd1080 =>
                                                  "1080p",
                                                VideoResolution.hd4K => "4K",
                                                VideoResolution.above4k =>
                                                  "2160p",
                                                // check if vr
                                                VideoResolution.unknown =>
                                                  widget.videoResults[index]
                                                          .virtualReality
                                                      ? "VR"
                                                      : "Unknown",
                                              }))),
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
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                              widget
                                                          .videoResults[index]
                                                          .durationInSeconds
                                                          .inMinutes <
                                                      61
                                                  ? "${(widget.videoResults[index].durationInSeconds.inMinutes % 60).toString().padLeft(2, '0')}:${(widget.videoResults[index].durationInSeconds.inSeconds % 60).toString().padLeft(2, '0')}"
                                                  : "1h+")))
                                ])),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    // make sure the text is at least 2 lines, so that other widgets dont move up
                                    widget.videoResults[index].title + '\n',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                Row(children: [
                                  Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Row(children: [
                                        Icon(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                            Icons.remove_red_eye),
                                        const SizedBox(width: 5),
                                        Text(convertViewsIntoHumanReadable(
                                            widget.videoResults[index]
                                                .viewsTotal))
                                      ])),
                                  Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Row(children: [
                                        Icon(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                            Icons.thumb_up),
                                        const SizedBox(width: 5),
                                        Text(widget.videoResults[index]
                                                    .ratingsPositivePercent !=
                                                -1
                                            ? "${widget.videoResults[index].ratingsPositivePercent}%"
                                            : "-")
                                      ])),
                                  Expanded(
                                      child: Padding(
                                          padding: const EdgeInsets.only(
                                              left: 8.0, right: 8.0),
                                          child: Row(children: [
                                            Icon(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .secondary,
                                                Icons.person),
                                            const SizedBox(width: 5),
                                            Expanded(
                                                child: Text(
                                              widget.videoResults[index].author,
                                              overflow: TextOverflow.clip,
                                              maxLines: 1,
                                            ))
                                          ])))
                                ])
                              ],
                            );
                          },
                        ),
                      ));
                },
              ),
      ),
    );
  }
}
