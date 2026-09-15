import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'core/network/websocket_service.dart';
import 'widgets/mouse_pad.dart';


void main() {
  runApp(const RemoteDesktop());
}

class RemoteDesktop extends StatefulWidget {
  const RemoteDesktop({super.key});

  @override
  State<RemoteDesktop> createState() => _RemoteDesktopState();
}

class _RemoteDesktopState extends State<RemoteDesktop> {
  final WebSocketService webSocket = WebSocketService();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? peerConnection;
  RTCDataChannel? dataChannel;
  StreamSubscription? socketSubscription;

  bool move = false;
  bool leftClick = false;
  bool rightClick = false;
  bool keyboard = false;
  bool down = false;
  bool up = false;
  bool drag = false;
  bool scroll = false;
  bool connected = false;
  bool videoTrackReceived = false;
  bool firstFrameRendered = false;

  double sensitivity = 2.0;
  static const double minSensitivity = 0.5;
  static const double maxSensitivity = 8.0;

  final xController = TextEditingController();
  final yController = TextEditingController();
  final keyController = TextEditingController();

  @override
  void initState(){
    super.initState();
    initRemoteRenderer();
  }

  Future<void> initRemoteRenderer() async {
    await remoteRenderer.initialize();

    remoteRenderer.onFirstFrameRendered = () {
      debugPrint("🎉 FIRST VIDEO FRAME RENDERED");

      if (!mounted) return;

      setState(() {
        firstFrameRendered = true;
      });
    };

    debugPrint("✅ RTCVideoRenderer initialized");
  }

  Future<void> createRtcPeerConnection() async {
  
    final configuration = {
      "iceServers": [
        {
          "urls": [
            "stun:stun.l.google.com:19302"
          ]
        }
      ]
    };
  
  
    peerConnection = await createPeerConnection(configuration);
  
    debugPrint("PeerConnection Created");
  
    await peerConnection!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(
        direction: TransceiverDirection.RecvOnly,
      ),
    );
    debugPrint("🎥 Video recvonly transceiver added");

    peerConnection!.onTrack = (RTCTrackEvent event){
      debugPrint("🎥 onTrack fired");
      debugPrint("Track kind: ${event.track.kind}");
      debugPrint("Streams: ${event.streams.length}");

      if (event.track.kind == "video" && event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;

        if (!mounted) return;

        setState(() {
          videoTrackReceived = true;
        });

        debugPrint("✅ Remote video attached");
      }
    };
  
    peerConnection!.onIceCandidate = (candidate) {
    
      webSocket.send({
        "type": "candidate",
        "candidate": candidate.candidate,
        "sdpMid": candidate.sdpMid,
        "sdpMLineIndex": candidate.sdpMLineIndex
      });
  
      debugPrint("Candidate Sent");
    };
  
  
    peerConnection!.onConnectionState = (state){
    
      debugPrint(
        "Connection State: $state"
      );
  
    };
  
  
    dataChannel = await peerConnection!.createDataChannel(
      "control",
      RTCDataChannelInit()
    );
  
  
    dataChannel!.onDataChannelState = (state){
    
      debugPrint(
        "DataChannel State: $state"
      );
  
    };
  
  
    dataChannel!.onMessage = (message){
    
      debugPrint(
        "Message: ${message.text}"
      );
  
    };
  
  }

  Future<void> connect() async {

    
    if (connected) {
      debugPrint("Already connected");
      return;
    }

    try {

      await webSocket.connect(
        "ws://localhost:8080/ws",
      );

      await createRtcPeerConnection();

      socketSubscription = webSocket.messages!.listen(
        (message) async {
          final data = jsonDecode(message);

          switch(data["type"]) {
            case "answer":
              RTCSessionDescription answer = RTCSessionDescription(data["sdp"], "answer");
              await peerConnection!.setRemoteDescription(answer);
              debugPrint("Remote Description Set");
              break;
            case "candidate":
              RTCIceCandidate candidate = RTCIceCandidate(data["candidate"], data["sdpMid"], data["sdpMLineIndex"]);
              await peerConnection!.addCandidate(candidate);
              break;
            default:
              debugPrint("Unknown message");
          }

        },
        onDone: () {
          debugPrint("⚠️ WebSocket closed");
          disconnect();
        },
        onError: (error) {
          debugPrint("❌ WebSocket error: $error");
          setState(() { connected = false; });
        },
      );

      await createOffer();

      setState(() {
        connected = true;
      });

    } catch (e) {

      debugPrint("Connection error: $e");

      setState(() {
        connected = false;
      });

    }
  }

  Future<void> disconnect() async {
    if (!connected) return;

    await dataChannel?.close();
    await peerConnection?.close();

    peerConnection = null;
    dataChannel = null;

    socketSubscription?.cancel();
    webSocket.disconnect();

    setState(() {
      connected = false;
    });

    debugPrint("Disconnected");
  }

  Future<void> createOffer() async {
    if (peerConnection == null) return;

    RTCSessionDescription offer =
        await peerConnection!.createOffer();

    await peerConnection!.setLocalDescription(offer);

    webSocket.send({
      "type" : "offer" ,
      "sdp" : offer.sdp,
    });

    debugPrint("Offer Sent");
    debugPrint("Offer Created");
    debugPrint(offer.sdp);
  }

  void sendMessage() {

    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("DataChannel آماده نیست"),
        ),
      );
      return;
    }

    final int x = int.tryParse(xController.text) ?? 0;
    final int y = int.tryParse(yController.text) ?? 0;

    if (move) {
      dataChannel?.send(
        RTCDataChannelMessage(
          jsonEncode(
            {
              "type": "input",
              "device": "mouse",
              "action": "move",
              "payload": {
                "x": x,
                "y": y,
              }
            },
          )
        )
      );
    }

    if (leftClick) {
      dataChannel?.send(
        RTCDataChannelMessage(
          jsonEncode(
            {
              "type": "input",
              "device": "mouse",
              "action": "click",
              "payload": {
                "button": "left",
              }
            },
          )
        )
      );
    }

    if (rightClick) {
      dataChannel?.send(
        RTCDataChannelMessage(
          jsonEncode(
            {
              "type": "input",
              "device": "mouse",
              "action": "click",
              "payload": {
                "button": "right",
              }
            },
          )
        )
      );
    }

    if (keyboard) {
      dataChannel?.send(
        RTCDataChannelMessage(
          jsonEncode(
            {
              "type": "input",
              "device": "keyboard",
              "action": down ? "down" : up ? "up" : "press",
              "payload": {  
                "key": keyController.text.isNotEmpty ? keyController.text : "A", // Replace with the actual key you want to send
              }
            },
          ),
        )
      );
    }
    
  }

  @override
  void dispose() {
    socketSubscription?.cancel();
    dataChannel?.close();
    peerConnection?.close();
    dataChannel = null;
    peerConnection = null;
    remoteRenderer.srcObject = null;
    remoteRenderer.dispose();
    xController.dispose();
    yController.dispose();
    keyController.dispose();
    webSocket.disconnect();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Remote Desktop"),
        ),
        body: SingleChildScrollView(
          child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              const Text(
                "Connect to PC",
                style: TextStyle(fontSize: 24),
              ),

              const SizedBox(height: 20),

              //connect and disconnect buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: connected ? null : connect,
                      child: const Text("Connect"),
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: connected ? disconnect : null,
                      child: const Text("Disconnect"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                height: 240,
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RTCVideoView(
                      remoteRenderer,
                      objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    ),

                    if (!videoTrackReceived)
                      const Center(
                        child: Text(
                          "Waiting for remote desktop...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          ),
                      ),
                    if (videoTrackReceived && !firstFrameRendered)
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),

              //touchpad
              SizedBox(
                height: 300,
                child: MousePad(

                  onSwipeUp: () {
                    debugPrint("🔼 onSwipeUp FIRED");
                    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen){
                      return;
                    }

                    dataChannel!.send(
                      RTCDataChannelMessage(
                        jsonEncode({
                          "type" : "input",
                          "device": "mouse",
                          "action": "swipeUp",
                          "payload": {
                            }
                        })
                      )
                    );
                  },

                  onSwipeDown: () {
                    debugPrint("🔽 onSwipeDown FIRED");
                    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen){
                      return;
                    }

                    dataChannel!.send(
                      RTCDataChannelMessage(
                        jsonEncode({
                          "type" : "input",
                          "device": "mouse",
                          "action": "swipeDown",
                          "payload": {
                            }
                        })
                      )
                    );
                  },

                  onSwipeLeft: () {
                    debugPrint("◀️ onSwipeLeft FIRED");
                    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen){
                      return;
                    }

                    dataChannel!.send(
                      RTCDataChannelMessage(
                        jsonEncode({
                          "type" : "input",
                          "device": "mouse",
                          "action": "swipeLeft",
                          "payload": {
                            }
                        })
                      )
                    );
                  },

                  onSwipeRight: () {
                    debugPrint("▶️ onSwipeRight FIRED");
                    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen){
                      return;
                    }

                    dataChannel!.send(
                      RTCDataChannelMessage(
                        jsonEncode({
                          "type" : "input",
                          "device": "mouse",
                          "action": "swipeRight",
                          "payload": {
                            }
                        })
                      )
                    );
                  },

                  onMiddleClick: () {
                    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen){
                      return;
                    }

                    debugPrint("click send in main");

                    dataChannel!.send(
                      RTCDataChannelMessage(
                        jsonEncode({
                          "type" : "input",
                          "device": "mouse",
                          "action": "click",
                          "payload": {
                            "button": "middle",
                            }
                        })
                      )
                    );

                    debugPrint("click sended in main");


                  },

                  onDragStart: (){
                    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen){
                      return;
                    }

                    dataChannel!.send(
                      RTCDataChannelMessage(
                        jsonEncode({
                          "type" : "input",
                          "device": "mouse",
                          "action": "dragStart",
                          "payload": {
                            }
                        })
                      )
                    );
                  },

                  onDrag:(dx, dy) {
                    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen){
                      return;
                    }

                    if (dx.abs() < 1 && dy.abs() < 1) {
                      return;
                    }

                    dataChannel!.send(
                      RTCDataChannelMessage(
                        jsonEncode({
                          "type" : "input",
                          "device": "mouse",
                          "action": "drag",
                          "payload": {
                            "dx": (dx * sensitivity).round(),
                            "dy": (dy * sensitivity).round(),
                            }
                        })
                      )
                    );
                  },

                  onDragEnd: (){
                    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen){
                      return;
                    }

                    dataChannel!.send(
                      RTCDataChannelMessage(
                        jsonEncode({
                          "type" : "input",
                          "device": "mouse",
                          "action": "dragEnd",
                          "payload": {
                            }
                        })
                      )
                    );
                  },

                  onDoubleTap: (){
                    debugPrint("🔵 onDoubleTap FIRED");
                    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen){
                      return;
                    }

                    dataChannel!.send(
                      RTCDataChannelMessage(
                        jsonEncode({
                          "type" : "input",
                          "device": "mouse",
                          "action": "doubleClick",
                          "payload": {
                            "button": "left",
                            }
                        })
                      )
                    );
                  },
                  

                  onLongPress: (){
                    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen){
                      return;
                    }

                    dataChannel!.send(
                      RTCDataChannelMessage(
                        jsonEncode({
                          "type" : "input",
                          "device": "mouse",
                          "action": "click",
                          "payload": {
                            "button": "right",
                            }
                        })
                      )
                    );
                  },

                  onTap: (){
                    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen){
                      return;
                    }

                    dataChannel!.send(
                      RTCDataChannelMessage(
                        jsonEncode({
                          "type" : "input",
                          "device": "mouse",
                          "action": "click",
                          "payload": {
                            "button": "left",
                            }
                        })
                      )
                    );
                  },

                  onScroll: (dy) {
                    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen){
                      return;
                    }

                    if (dy.abs() < 1) {
                      return;
                    }


                    dataChannel!.send(
                      RTCDataChannelMessage(
                        jsonEncode({
                          "type" : "input",
                          "device": "mouse",
                          "action": "scroll",
                          "payload": {
                            "dy": dy.round(),
                            }
                        })
                      )
                    );
                  },

                  onMove: (dx, dy) {
                    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen){
                      return;
                    }

                    if (dx.abs() < 1 && dy.abs() < 1) {
                      return;
                    }

                    dataChannel!.send(
                      RTCDataChannelMessage(
                        jsonEncode({
                          "type" : "input",
                          "device": "mouse",
                          "action": "move",
                          "payload": {
                            "dx": (dx * sensitivity).round(),
                            "dy": (dy * sensitivity).round(),
                            }
                        })
                      )
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  const Icon(Icons.speed, size: 20),
                  Expanded(
                    child: Slider(
                      value: sensitivity,
                      min: minSensitivity,
                      max: maxSensitivity,
                      divisions: 225,
                      label: sensitivity.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          sensitivity = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      sensitivity.toStringAsFixed(1),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),

              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: "Key",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              CheckboxListTile(
                title: const Text("Right Click"),
                value: rightClick,
                onChanged: (value) {
                  setState(() {
                    rightClick = value!;
                  });
                },
              ),

              CheckboxListTile(
                title: const Text("Keyboard"),
                value: keyboard,
                onChanged: (value) {
                  setState(() {
                    keyboard = value!;
                  });
                },
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: sendMessage,
                child: const Text("Send"),
              ),
            ],
          ),
        ),
      )),
    );
  }
}
