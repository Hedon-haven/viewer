import 'package:flutter/material.dart';

import '/ui/widgets/future_widget.dart';
import '/utils/global_vars.dart';

class FakeRemindersScreen extends StatefulWidget {
  final Function parentStopConcealing;

  const FakeRemindersScreen({super.key, required this.parentStopConcealing});

  @override
  State<FakeRemindersScreen> createState() => _FakeRemindersScreenState();
}

class _FakeRemindersScreenState extends State<FakeRemindersScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return FutureWidget<List<String>?>(
        future: sharedStorage.getStringList("fake_reminders_list"),
        finalWidgetBuilder: (context, snapshotData) {
          return Scaffold(
            appBar: AppBar(
              title: Text("Reminders",
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            body: ListView.builder(
              itemCount: snapshotData!.length,
              itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.all(4),
                  child: ListTile(
                    tileColor: Theme.of(context).colorScheme.surfaceVariant,
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    title: Text(snapshotData[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () =>
                          setState(() => snapshotData.removeAt(index)),
                    ),
                  )),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text("Add Reminder"),
                      content: TextField(
                        controller: _controller,
                        decoration:
                            const InputDecoration(hintText: "Enter reminder"),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // Close the dialog
                          },
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (_controller.text.trim().toLowerCase() ==
                                "stop concealing") {
                              logger.i("Unconcealing app");
                              widget.parentStopConcealing();
                              Navigator.pop(context); // Close the dialog
                              return;
                            }
                            if (_controller.text.isNotEmpty) {
                              snapshotData.add(_controller.text);
                              await sharedStorage.setStringList(
                                  "fake_reminders_list", snapshotData);
                              setState(() {});
                              _controller.clear(); // Clear the text field
                              Navigator.pop(context); // Close the dialog
                            }
                          },
                          child: const Text("Add"),
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Icon(Icons.add),
            ),
          );
        });
  }
}
