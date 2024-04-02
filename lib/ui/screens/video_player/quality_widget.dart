import 'package:flutter/material.dart';

import 'overlay_widget.dart';

class QualityWidget extends StatelessWidget {
  bool showControls;
  int selectedResolution;
  final List<int>? sortedResolutions;
  final void Function(int) onSelected;

  QualityWidget(
      {super.key,
      required this.showControls,
      required this.selectedResolution,
      required this.onSelected,
      this.sortedResolutions});

  @override
  Widget build(BuildContext context) {
    return OverlayWidget(
        showControls: showControls,
        // TODO: Force animation to always go downwards
        child: DropdownButton<String>(
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          dropdownColor: Colors.black87,
          padding: const EdgeInsets.all(0.0),
          value: "${selectedResolution}p",
          underline: const SizedBox(),
          onChanged: (String? newValue) async {
            selectedResolution =
                int.parse(newValue!.substring(0, newValue.length - 1));
            onSelected(selectedResolution);
          },
          items: sortedResolutions!.map<DropdownMenuItem<String>>((int value) {
            return DropdownMenuItem<String>(
              value: "${value}p",
              child: Text("${value}p",
                  style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
        ));
  }
}
