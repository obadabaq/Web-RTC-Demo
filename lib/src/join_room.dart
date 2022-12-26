import 'dart:core';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class JoinRoom extends StatefulWidget {
  final String id;

  const JoinRoom({Key? key, required this.id}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<JoinRoom> {
  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;

  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _inCalling = false;
  bool ready = false;
  late Timer _timer;
  DocumentReference? room;
  DocumentSnapshot? roomSnapshot;

  String get sdpSemantics => 'unified-plan';
  final List<RTCRtpSender> _senders = [];

  @override
  Widget build(BuildContext context) {
    var widgets = <Widget>[
      Expanded(
        child: RTCVideoView(_localRenderer),
      ),
      Expanded(
        child: RTCVideoView(_remoteRenderer),
      )
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Room'),
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Center(
            child: Container(
              decoration: const BoxDecoration(color: Colors.black54),
              child: orientation == Orientation.portrait
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: widgets)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: widgets),
            ),
          );
        },
      ),
      floatingActionButton: ready
          ? FloatingActionButton(
              onPressed: _inCalling ? _hangUp : _makeCall,
              tooltip: _inCalling ? 'Hangup' : 'Call',
              child: Icon(_inCalling ? Icons.call_end : Icons.phone),
            )
          : const SizedBox(),
    );
  }

  @override
  initState() {
    super.initState();
    asyncInit();
    initRenderers();
  }

  Future<void> asyncInit() async {
    room = await FirebaseFirestore.instance.collection('rooms').doc(widget.id);
    roomSnapshot = await room!.get();
    setState(() {
      ready = true;
    });
  }

  @override
  deactivate() {
    super.deactivate();
    if (_inCalling) {
      _hangUp();
    }
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void handleStatsReport(Timer timer) async {}

  _onSignalingState(RTCSignalingState state) {
    print(state);
  }

  _onIceGatheringState(RTCIceGatheringState state) {
    print(state);
  }

  _onIceConnectionState(RTCIceConnectionState state) {
    print(state);
  }

  _onAddStream(MediaStream stream) {
    print('addStream: ${stream.id}');
    _remoteRenderer.srcObject = stream;
    setState(() {
      _inCalling = true;
    });
  }

  _onRemoveStream(MediaStream stream) {
    _remoteRenderer.srcObject = null;
  }

  _onCandidate(RTCIceCandidate candidate) {
    var callerCandidatesCollection = room!.collection('calleeCandidates');

    callerCandidatesCollection.add(candidate.toMap());

    print('onCandidate: ${candidate.candidate}');
    _peerConnection!.addCandidate(candidate);
  }

  void _onTrack(RTCTrackEvent event) {
    print('onTrack');
    if (event.track.kind == 'video') {
      _remoteRenderer.srcObject = event.streams[0];
    }
  }

  void _onAddTrack(MediaStream stream, MediaStreamTrack track) {
    if (track.kind == 'video') {
      _remoteRenderer.srcObject = stream;
    }
  }

  void _onRemoveTrack(MediaStream stream, MediaStreamTrack track) {
    if (track.kind == 'video') {
      _remoteRenderer.srcObject = null;
    }
  }

  _onRenegotiationNeeded() {
    print('RenegotiationNeeded');
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  _makeCall() async {
    final Map<String, dynamic> mediaConstraints = {
      "audio": true,
      "video": {
        "mandatory": {
          "minWidth":
              '600', // Provide your own width, height and frame rate here
          "minHeight": '600',
          "minFrameRate": '30',
        },
        "facingMode": "user",
        "optional": [],
      }
    };

    Map<String, dynamic> configuration = {
      "iceServers": [
        {
          'url': 'stun:stun.l.google.com:19302',
          // "url": 'turn:18.224.253.192:3478',
          "credential": widget.id,
          // "username": 'turnBKhETPNa8M7tsxD'
        }
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    final Map<String, dynamic> loopbackConstraints = {
      "mandatory": {},
      "optional": [
        {"DtlsSrtpKeyAgreement": false},
      ],
    };

    if (_peerConnection != null) return;

    try {
      _peerConnection =
          await createPeerConnection(configuration, loopbackConstraints);

      _peerConnection!.onSignalingState = _onSignalingState;
      _peerConnection!.onIceGatheringState = _onIceGatheringState;
      _peerConnection!.onIceConnectionState = _onIceConnectionState;
      _peerConnection!.onAddStream = _onAddStream;
      _peerConnection!.onRemoveStream = _onRemoveStream;
      _peerConnection!.onIceCandidate = _onCandidate;
      _peerConnection!.onRenegotiationNeeded = _onRenegotiationNeeded;
      // _peerConnection!.addStream(_localStream!);

      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;

      switch (sdpSemantics) {
        case 'plan-b':
          _peerConnection!.onAddStream = _onAddStream;
          _peerConnection!.onRemoveStream = _onRemoveStream;
          await _peerConnection!.addStream(_localStream!);
          break;
        case 'unified-plan':
          _peerConnection!.onTrack = _onTrack;
          _peerConnection!.onAddTrack = _onAddTrack;
          _peerConnection!.onRemoveTrack = _onRemoveTrack;
          _localStream!.getTracks().forEach((track) async {
            _senders.add(await _peerConnection!.addTrack(track, _localStream!));
          });
          break;
      }

      print("FUCKY 12 ${roomSnapshot!.data()}");
      var data = roomSnapshot!.data() as Map<String, dynamic>;
      var offer = data['offer'];

      var sdp = offer['sdp'];
      RTCSessionDescription remoteDescription =
          RTCSessionDescription(sdp, 'offer');

      _peerConnection!.setRemoteDescription(remoteDescription);

      RTCSessionDescription description =
          await _peerConnection!.createAnswer(offerSdpConstraints);

      _peerConnection!.setLocalDescription(description);

      var roomWithAnswer = {
        'answer': {
          "type": description.type,
          "sdp": description.sdp,
        },
      };
      var test = await room!.get();
      print(roomWithAnswer);
      room!.update(roomWithAnswer);
      // print("FUCKY123 ${await room!.update(roomWithAnswer)}");


      // print("FUCK12 ${await room.data()}");
      print("FUCK12 ${test.data()}");

      //change for loopback.

      CollectionReference callerCandidatesCollection = room!.collection('callerCandidates');

      callerCandidatesCollection.snapshots().listen((event) async {
        if (event.docs.length > 0) {
          var temp = event.docs.last.data() as Map<String, dynamic>;
          print("HALO $temp");
          RTCIceCandidate remoteCandidate = RTCIceCandidate(
              temp['candidate'], temp['sdpMid'], temp['sdpMLineIndex']);
          print('Add new Reomte Candidate');
          _peerConnection!.addCandidate(remoteCandidate);
        }
      });
    } catch (e) {
      print(e.toString());
    }
  }

  _hangUp() async {
    try {
      await _localStream!.dispose();
      await _peerConnection!.close();
      _peerConnection = null;
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    } catch (e) {
      print(e.toString());
    }
    setState(() {
      _inCalling = false;
    });
    _timer.cancel();
  }
}
