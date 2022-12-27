// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:web_rtc_demo/firebase_options.dart';
// import 'package:web_rtc_demo/signling.dart';
//
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: MyHomePage(),
//     );
//   }
// }
//
// class MyHomePage extends StatefulWidget {
//   MyHomePage({Key? key}) : super(key: key);
//
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   Signaling signaling = Signaling();
//   RTCVideoRenderer _localRenderer = RTCVideoRenderer();
//   RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
//   String? roomId;
//   TextEditingController textEditingController = TextEditingController(text: '');
//
//   @override
//   void initState() {
//     _localRenderer.initialize();
//     _remoteRenderer.initialize();
//
//     signaling.onAddRemoteStream = ((stream) {
//       _remoteRenderer.srcObject = stream;
//       setState(() {});
//     });
//
//     super.initState();
//   }
//
//   @override
//   void dispose() {
//     _localRenderer.dispose();
//     _remoteRenderer.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Welcome to Flutter Explained - WebRTC"),
//       ),
//       body: Column(
//         children: [
//           SizedBox(height: 8),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               ElevatedButton(
//                 onPressed: () {
//                   signaling.openUserMedia(_localRenderer, _remoteRenderer);
//                 },
//                 child: Text("Open camera & microphone"),
//               ),
//               SizedBox(
//                 width: 8,
//               ),
//               ElevatedButton(
//                 onPressed: () async {
//                   roomId = await signaling.createRoom(_remoteRenderer);
//                   textEditingController.text = roomId!;
//                   setState(() {});
//                 },
//                 child: Text("Create room"),
//               ),
//               SizedBox(
//                 width: 8,
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   // Add roomId
//                   signaling.joinRoom(
//                     textEditingController.text,
//                     _remoteRenderer,
//                   );
//                 },
//                 child: Text("Join room"),
//               ),
//               SizedBox(
//                 width: 8,
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   signaling.hangUp(_localRenderer);
//                 },
//                 child: Text("Hangup"),
//               )
//             ],
//           ),
//           SizedBox(height: 8),
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Expanded(child: RTCVideoView(_localRenderer, mirror: true)),
//                   Expanded(child: RTCVideoView(_remoteRenderer)),
//                 ],
//               ),
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text("Join the following Room: "),
//                 Flexible(
//                   child: TextFormField(
//                     controller: textEditingController,
//                   ),
//                 )
//               ],
//             ),
//           ),
//           SizedBox(height: 8)
//         ],
//       ),
//     );
//   }
// }


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

