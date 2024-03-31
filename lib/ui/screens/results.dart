import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/universal_formats.dart';
import 'package:hedon_viewer/ui/custom_widgets/video_list.dart';
import 'package:hedon_viewer/ui/screens/search.dart';

class ResultsScreen extends StatelessWidget {
  final Future<List<UniversalSearchResult>> videoResults;
  final UniversalSearchRequest searchRequest;

  const ResultsScreen(
      {super.key, required this.videoResults, required this.searchRequest});

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvoked: (goingToPop) {
          print("goingToPop: $goingToPop");
          // Go back to home screen and clear navigation stack
          Navigator.pushNamedAndRemoveUntil(context, "/home", (route) => false);
        },
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: AppBar().preferredSize,
            child: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                  child: GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SearchScreen(
                              previousSearch: searchRequest,
                            ),
                          )),
                      child: Container(
                        color: Theme.of(context).colorScheme.background,
                        child: AppBar(
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {
                              // Go back to home screen
                              Navigator.pushNamedAndRemoveUntil(
                                  context, "/", (route) => false);
                            },
                          ),
                          titleSpacing: 0.0,
                          title: Text(searchRequest.searchString,
                              overflow: TextOverflow.clip,
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                fontSize: 16,
                              )),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(25),
                                  right: Radius.circular(25))),
                          elevation: 8,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                        ),
                      ))),
            ),
          ),
          body: VideoList(
            videoResults: videoResults,
          ),
        ));
  }
}
