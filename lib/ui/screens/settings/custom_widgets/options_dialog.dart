import 'package:flutter/material.dart';

class DialogTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool removeHorizontalPadding;
  final List<String> options;
  final String selectedOption;
  final void Function(String) onSelected;

  const DialogTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selectedOption,
    required this.onSelected,
    bool? removeHorizontalPadding,
  }) : removeHorizontalPadding = removeHorizontalPadding ?? false;

  @override
  State<DialogTile> createState() => _DialogTileState();
}

class _DialogTileState extends State<DialogTile> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: Text(widget.title),
        subtitle: Text(widget.subtitle),
        // remove extra padding
        visualDensity: widget.removeHorizontalPadding
            ? const VisualDensity(horizontal: 0, vertical: -4)
            : null,
        contentPadding: widget.removeHorizontalPadding ? EdgeInsets.zero : null,
        onTap: () {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text(widget.title),
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
                      for (var option in widget.options)
                        RadioListTile(
                          title: Text(option),
                          value: option,
                          groupValue: widget.selectedOption,
                          onChanged: (value) {
                            widget.onSelected(value!);
                            Navigator.of(context).pop(); // Close the dialog
                          },
                        ),
                    ],
                  ),
                );
              });
        });
  }
}
