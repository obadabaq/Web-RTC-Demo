import 'dart:core';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:share/share.dart';
import 'Dialogs.dart';

class CreateRoom extends StatefulWidget {
  static String tag = 'loopback_sample';

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<CreateRoom> {
  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  WebRTC webRTC = WebRTC();

  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _inCalling = false;
  String id = 'id';
  late Timer _timer;
  String get sdpSemantics => 'plan-b';
  var room = FirebaseFirestore.instance.collection('rooms').doc();
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
        title: const Text('Create Room'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _inCalling ? _hangUp : _makeCall,
        tooltip: _inCalling ? 'Hangup' : 'Call',
        child: Icon(_inCalling ? Icons.call_end : Icons.phone),
      ),
    );
  }

  @override
  initState() {
    super.initState();
    initRenderers();
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
    if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
      print('Connection Ready');
      statusDialog(title: 'Room Ready to join', color: Colors.green);
      print('Share Opened');
      Share.share(id);
    }

    print(state);
  }

  _onIceConnectionState(RTCIceConnectionState state) {
    if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
      statusDialog(title: 'Failed', color: Colors.red);
    }
    print(state);
  }

  _onAddStream(MediaStream stream) {
    print('addStream: ${stream.id}');
    _remoteRenderer.srcObject = stream;
  }

  _onRemoveStream(MediaStream stream) {
    _remoteRenderer.srcObject = null;
  }

  _onCandidate(RTCIceCandidate candidate) {
    var callerCandidatesCollection = room.collection('callerCandidates');

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
          "minWidth": '600',
          // Provide your own width, height and frame rate here
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
          'url': 'stun:stun.l.google.com:19302'
          // "url": 'turn:18.224.253.192:3478',
          // "credential": 'FmxvrY6nADxaAskhmrNrAL2N4CRtZ8',
          // "username": 'turnBKhETPNa8M7tsxD'
        }
      ],
      'sdpSemantics': sdpSemantics
    };

    final Map<String, dynamic> offerSdpConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
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

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;
      // _localRenderer.mirror = true;
      statusDialog(title: 'Local Camera Ready', color: const Color(0xFFE7AE25));

      // _peerConnection!.addStream(_localStream!);
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

      // Unified-Plan Simulcast
      /*await _peerConnection?.addTransceiver(
          track: _localStream!.getVideoTracks()[0],
          init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendOnly,
            streams: [_localStream!],
            sendEncodings: [
              // for firefox order matters... first high resolution, then scaled resolutions...
              RTCRtpEncoding(
                rid: 'f',
                maxBitrate: 900000,
                numTemporalLayers: 3,
              ),
              RTCRtpEncoding(
                rid: 'h',
                numTemporalLayers: 3,
                maxBitrate: 300000,
                scaleResolutionDownBy: 2.0,
              ),
              RTCRtpEncoding(
                rid: 'q',
                numTemporalLayers: 3,
                maxBitrate: 100000,
                scaleResolutionDownBy: 4.0,
              ),
            ],
          ));

      await _peerConnection!.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeVideo);
      await _peerConnection!.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeVideo);
      await _peerConnection!.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
          init:
              RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly));*/
      RTCSessionDescription description =
          await _peerConnection!.createOffer(offerSdpConstraints);
      var sdp = description.sdp;
      print(description.sdp);
      _peerConnection!.setLocalDescription(description);
      //change for loopback.
      var sdp_answer = sdp!.replaceAll('setup:actpass', 'setup:active');
      var description_answer = RTCSessionDescription(sdp_answer, 'answer');
      await _peerConnection!.setRemoteDescription(description_answer);

      var roomWithOffer = {
        'offer': {
          "type": description.type,
          "sdp": description.sdp,
        },
      };
      print(roomWithOffer);
      await room.set(roomWithOffer);
      print("Room Id: ${room.id}");
      statusDialog(
          title: 'Room Id : ${room.id}', color: const Color(0xFFE7AE25));

      setState(() {
        id = room.id;
      });

      // room.update(data);

      room.snapshots().listen((event) async {
        // await room.get();
        print("LOLLL ${event.data()}");

        if (event.data()!.containsKey('answer')) {
          print('In Answer');
          description.type = 'answer';
          var sdp = event.data()!['answer']['sdp'];
          RTCSessionDescription remoteDescription =
              RTCSessionDescription(sdp, 'answer');
          _peerConnection!.setRemoteDescription(remoteDescription);

          var calleeCandidatesCollection = room.collection('calleeCandidates');

          calleeCandidatesCollection.snapshots().listen((event) {
            event.docChanges.forEach((element) {
              if (element.type == DocumentChangeType.added) {
                var temp = element.doc.data();
                RTCIceCandidate remoteCandidate = RTCIceCandidate(
                    temp!['candidate'], temp['sdpMid'], temp['sdpMLineIndex']);
                print('Add new Reomte Candidate');
                _peerConnection!.addCandidate(remoteCandidate);
              }
            });
          });

          if (!mounted) return;

          // _timer = new Timer.periodic(Duration(seconds: 1), handleStatsReport);

          setState(() {
            _inCalling = true;
          });
        }
      });
    } catch (e) {
      print("damy $e");
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
