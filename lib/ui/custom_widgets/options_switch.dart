import 'package:flutter/material.dart';

class OptionsSwitch extends StatelessWidget {
  final String title;
  final String subTitle;
  final bool switchState;
  final void Function(bool) onSelected;

  const OptionsSwitch({
    super.key,
    required this.title,
    required this.subTitle,
    required this.switchState,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: ListTile(
            title: Text(title),
            subtitle: Text(subTitle),
          ),
        ),
        Switch(
          value: switchState,
          onChanged: (value) {
            onSelected(value);
          },
        ),
      ],
    );
  }
}
