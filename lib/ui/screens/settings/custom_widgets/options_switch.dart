import 'package:flutter/material.dart';

class OptionsSwitch extends StatefulWidget {
  final String title;
  final String subTitle;
  late bool switchState;
  late bool showSettingsButton;
  late bool reduceBorders;

  /// Make toggle visual only
  late bool nonInteractive;
  late Widget? leadingWidget;
  final void Function(bool) onToggled;
  final void Function() onPressedSettingsButton;

  OptionsSwitch(
      {super.key,
      required this.title,
      required this.subTitle,
      required this.switchState,
      required this.onToggled,
      bool? showExtraSettingsButton,
      bool? reduceBorders,
      bool? nonInteractive,
      this.leadingWidget, // can be just null
      void Function()? onPressedSettingsButton})
      : showSettingsButton = showExtraSettingsButton ?? false,
        reduceBorders = reduceBorders ?? false,
        nonInteractive = nonInteractive ?? false,
        onPressedSettingsButton = onPressedSettingsButton ?? (() {});

  @override
  State<OptionsSwitch> createState() => _OptionsSwitchWidgetState();
}

class _OptionsSwitchWidgetState extends State<OptionsSwitch> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: ListTile(
            leading: widget.leadingWidget,
            title: Text(widget.title),
            subtitle: Text(widget.subTitle),
            visualDensity: widget.reduceBorders
                ? const VisualDensity(horizontal: 0, vertical: -4)
                : null,
            contentPadding: widget.reduceBorders ? EdgeInsets.zero : null,
          ),
        ),
        widget.showSettingsButton
            ? IconButton(
                onPressed: () {
                  widget.onPressedSettingsButton();
                },
                icon: const Icon(Icons.settings))
            : const SizedBox(),
        Switch(
          value: widget.switchState,
          onChanged: (value) {
            widget.onToggled(value);
            if (!widget.nonInteractive) {
              // The user provided function completes after the setState below
              // is called -> value is written to settings successfully,
              // but widget is not updated visually
              // -> Manually temporarily change switchState to the new value
              setState(() {
                widget.switchState = value;
              });
            }
          },
        ),
      ],
    );
  }
}
