import 'package:flutter/material.dart';

class OptionsDialog extends StatelessWidget {
  final String title;
  final List<String> options;
  final String selectedOption;
  final void Function(String) onSelected;

  const OptionsDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selectedOption,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("Cancel"),
        ),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var option in options)
            RadioListTile(
              title: Text(option),
              value: option,
              groupValue: selectedOption,
              onChanged: (value) {
                onSelected(value!);
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
        ],
      ),
    );
  }
}
