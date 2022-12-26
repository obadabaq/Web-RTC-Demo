import 'dart:core';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:web_rtc_demo/firebase_options.dart';
import 'package:web_rtc_demo/src/join_room.dart';
import 'src/create_room.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Maids.cc-Video Call example'),
          ),
          body: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12.0),
              itemCount: 2,
              itemBuilder: (context, i) {
                return RaisedButton(
                  onPressed: () {
                    if (i == 0) {
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (context) {
                        return CreateRoom();
                      }));
                    } else {
                      _showAddressDialog(context);
                    }
                  },
                  child: Text(i == 0 ? 'Create Room' : 'Join Room'),
                );
              })),
    );
  }

  @override
  initState() {
    super.initState();
  }
}

void showDemoDialog<T>({BuildContext? context, Widget? child}) {
  showDialog<T>(
    context: context!,
    builder: (BuildContext context) => child!,
  ).then<void>((value) {
    // The value passed to Navigator.pop() or null.
    if (value != null) {}
  });
}

_showAddressDialog(context) {
  TextEditingController textEditingController = TextEditingController();
  showDemoDialog<String>(
      context: context,
      child: AlertDialog(
          title: const Text('Enter Room Id:'),
          content: TextField(
            controller: textEditingController,
            onChanged: (String text) {},
            decoration: const InputDecoration(),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            FlatButton(
                child: const Text('CANCEL'),
                onPressed: () {
                  Navigator.pop(context);
                }),
            FlatButton(
                child: const Text('CONNECT'),
                onPressed: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (context) {
                    return JoinRoom(
                      id: textEditingController.text,
                    );
                  }));
                })
          ]));
}
