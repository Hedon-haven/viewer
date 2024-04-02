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
    return _OptionsSwitchWidget(
        title: title,
        subTitle: subTitle,
        switchState: switchState,
        onSelected: onSelected);
  }
}

class _OptionsSwitchWidget extends StatefulWidget {
  final String title;
  final String subTitle;
  late bool switchState;
  final void Function(bool) onSelected;

  _OptionsSwitchWidget({
    required this.title,
    required this.subTitle,
    required this.switchState,
    required this.onSelected,
  });

  @override
  State<_OptionsSwitchWidget> createState() => _OptionsSwitchWidgetState();
}

class _OptionsSwitchWidgetState extends State<_OptionsSwitchWidget> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: ListTile(
            title: Text(widget.title),
            subtitle: Text(widget.subTitle),
          ),
        ),
        Switch(
          value: widget.switchState,
          onChanged: (value) {
            widget.onSelected(value);
            // The user provided function completes after the setState below
            // is called -> value is written to settings successfully,
            // but widget is not updated visually
            // -> Manually temporarily change switchState to the new value
            widget.switchState = value;
            setState(() {});
          },
        ),
      ],
    );
  }
}
