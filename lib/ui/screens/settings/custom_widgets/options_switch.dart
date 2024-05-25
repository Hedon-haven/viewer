import 'package:flutter/material.dart';

class OptionsSwitch extends StatefulWidget {
  final String title;
  final String subTitle;
  late bool switchState;
  late bool showExtraHomeButton;
  late bool homeButtonState;
  late bool reduceBorders;

  /// Make toggle visual only
  late bool nonInteractive;
  final void Function(bool) onToggled;
  final void Function(bool) onToggledHomeButton;

  OptionsSwitch(
      {super.key,
      required this.title,
      required this.subTitle,
      required this.switchState,
      required this.onToggled,
      bool? showExtraHomeButton,
      bool? homeButtonState,
      bool? reduceBorders,
      bool? nonInteractive,
      void Function(bool)? onToggledHomeButton})
      : showExtraHomeButton = showExtraHomeButton ?? false,
        homeButtonState = homeButtonState ?? false,
        reduceBorders = reduceBorders ?? false,
        nonInteractive = nonInteractive ?? false,
        onToggledHomeButton = onToggledHomeButton ?? ((_) {});

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
            title: Text(widget.title),
            subtitle: Text(widget.subTitle),
            visualDensity: widget.reduceBorders
                ? const VisualDensity(horizontal: 0, vertical: -4)
                : null,
            contentPadding: widget.reduceBorders ? EdgeInsets.zero : null,
          ),
        ),
        widget.showExtraHomeButton
            ? IconButton(
                onPressed: () {
                  // toggle homebutton state
                  setState(() {
                    widget.homeButtonState = !widget.homeButtonState;
                  });

                  widget.onToggledHomeButton(widget.homeButtonState);
                },
                icon: widget.homeButtonState
                    ? const Icon(Icons.home)
                    : const Icon(Icons.home_outlined))
            : const SizedBox(),
        Switch(
          value: widget.switchState,
          onChanged: (value) {
            widget.onToggled(value);

            if (!widget.nonInteractive) {
              // toggle homepage accordingly
              // this will not prevent the user from using just the homepage or just results
              widget.onToggledHomeButton(value);
              widget.homeButtonState = value;

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
