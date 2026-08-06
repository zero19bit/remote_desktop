package main

import (
	"encoding/json"
	"log"
	"net/http"
	"runtime"
	"os/exec"

	"github.com/go-vgo/robotgo"
	"github.com/gorilla/websocket"
	"github.com/pion/webrtc/v4"
)

type Payload struct {
	X      int    `json:"x,omitempty"`
	Y      int    `json:"y,omitempty"`
	DX     int    `json:"dx,omitempty"`
	DY     int    `json:"dy,omitempty"`
	Button string `json:"button,omitempty"`
	Key    string `json:"key,omitempty"`
}

type Message struct {
	Type    string  `json:"type"`
	Device  string  `json:"device"`
	Action  string  `json:"action"`
	Payload Payload `json:"payload,omitempty"`

	SDP           string `json:"sdp,omitempty"`
	Candidate     string `json:"candidate,omitempty"`
	SDPMid        string `json:"sdpMid,omitempty"`
	SDPMLineIndex int    `json:"sdpMLineIndex,omitempty"`
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func handleSwipe(direction string) {
	log.Println("🖐️ handleSwipe called:", direction, "on", runtime.GOOS)
	switch runtime.GOOS {
		case "windows":
			switch direction {
				case "up":
					robotgo.KeyTap("tab", "cmd")
				case "down":
					robotgo.KeyTap("d", "cmd")
				case "left":
					robotgo.KeyTap("left", "cmd", "ctrl")
				case "right":
					robotgo.KeyTap("right", "cmd", "ctrl")
			}
		case "darwin":
			switch direction {
				case "up":
					robotgo.KeyTap("up", "ctrl")
				case "down":
					robotgo.KeyTap("f11")
				case "left":
					robotgo.KeyTap("left", "ctrl")
				case "right":
					robotgo.KeyTap("right", "ctrl")
			}
		case "linux":

			switch direction {
				case "up":
					robotgo.KeyTap("lsuper")
				case "down":
					if err := exec.Command("wmctrl", "-k", "on").Run(); err != nil {
						log.Println("wmctrl failed (is it installed?):", err)
					}
				case "left":
					exec.Command("xdotool", "set_desktop", "--relative", "--", "-1").Run()
				case "right":
					exec.Command("xdotool", "set_desktop", "--relative", "--", "1").Run()
			}
	}
}

func wsHandler(w http.ResponseWriter, r *http.Request) {

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println(err)
		return
	}
	defer conn.Close()

	log.Println("Client connected")

	peerConnection, err := webrtc.NewPeerConnection(
		webrtc.Configuration{
			ICEServers: []webrtc.ICEServer{
				{
					URLs: []string{
						"stun:stun.l.google.com:19302",
					},
				},
			},
		},
	)
	if err != nil {
		log.Println(err)
	}
	defer peerConnection.Close()

	peerConnection.OnICEConnectionStateChange(
		func(state webrtc.ICEConnectionState) {
			log.Println("ICE CONNECTION STATE:", state)

			switch state {

			case webrtc.ICEConnectionStateFailed:
				log.Println("❌ ICE connection failed")

			case webrtc.ICEConnectionStateDisconnected:
				log.Println("⚠️ ICE disconnected")

			case webrtc.ICEConnectionStateClosed:
				log.Println("🔴 ICE closed")

			case webrtc.ICEConnectionStateConnected:
				log.Println("✅ ICE connected")

			}
		},
	)

	peerConnection.OnICEGatheringStateChange(
		func(state webrtc.ICEGatheringState) {
			log.Println("ICE GATHERING STATE:", state)

			switch state {

			case webrtc.ICEGatheringStateComplete:
				log.Println("✅ ICE gathering completed")

			case webrtc.ICEGatheringStateGathering:
				log.Println("⏳ Gathering ICE candidates")

			}
		},
	)

	peerConnection.OnSignalingStateChange(
		func(state webrtc.SignalingState) {
			log.Println("SIGNALING STATE:", state)

			switch state {

			case webrtc.SignalingStateStable:
				log.Println("✅ Signaling stable")

			case webrtc.SignalingStateHaveRemoteOffer:
				log.Println("📩 Remote offer received")

			case webrtc.SignalingStateHaveLocalOffer:
				log.Println("📤 Local offer created")

			case webrtc.SignalingStateClosed:
				log.Println("🔴 Signaling closed")

			}
		},
	)

	peerConnection.OnConnectionStateChange(
		func(state webrtc.PeerConnectionState) {
			log.Println("PEER CONNECTION STATE:", state)

			switch state {

			case webrtc.PeerConnectionStateConnected:
				log.Println("🎉 WebRTC CONNECTED")

			case webrtc.PeerConnectionStateFailed:
				log.Println("❌ WebRTC FAILED")

			case webrtc.PeerConnectionStateDisconnected:
				log.Println("⚠️ WebRTC DISCONNECTED")

			case webrtc.PeerConnectionStateClosed:
				log.Println("🔴 WebRTC CLOSED")

			}
		},
	)

	peerConnection.OnICECandidate(func(candidate *webrtc.ICECandidate) {
		if candidate == nil {
			return
		}
		c := candidate.ToJSON()

		if c.SDPMid == nil {
			return
		}

		if c.SDPMLineIndex == nil {
			return
		}

		response := Message{
			Type:          "candidate",
			Candidate:     c.Candidate,
			SDPMid:        *c.SDPMid,
			SDPMLineIndex: int(*c.SDPMLineIndex),
		}

		data, err := json.Marshal(response)
		if err != nil {
			log.Println("Marshal error:", err)
			return
		}

		err = conn.WriteMessage(websocket.TextMessage, data)
		if err != nil {
			log.Println("Write error:", err)
			return
		}

	})

	peerConnection.OnDataChannel(func(dc *webrtc.DataChannel) {

		log.Println("DataChannel Created:", dc.Label())

		dc.OnOpen(func() {
			log.Println("DataChannel OPEN")
		})

		dc.OnClose(func() {
			log.Println("DataChannel CLOSED")
		})

		dc.OnError(func(err error) {
			log.Println("DataChannel ERROR:", err)
		})

		dc.OnMessage(func(msg webrtc.DataChannelMessage) {
			var m Message

			if err := json.Unmarshal(msg.Data, &m); err != nil {
				log.Println(err)
				return
			}

			switch m.Type {
			case "input":
				switch m.Device {
				case "mouse":
					switch m.Action {

					case "move":
						//						x, y := robotgo.Location()
						robotgo.MoveRelative(m.Payload.DX, m.Payload.DY)


					case "click":
						switch m.Payload.Button {
						case "left":
							robotgo.Click("left", false)
						case "right":
							robotgo.Click("right", false)
						case "middle":
							robotgo.Click("center", false)
						}


					case "doubleClick":
						robotgo.Click(m.Payload.Button, true)


					case "scroll":
						if m.Payload.DY > 0 {
							robotgo.ScrollDir(m.Payload.DY/4, "down")
						} else {
							robotgo.ScrollDir(-(m.Payload.DY / 4), "up")
						}


					case "dragStart":
						robotgo.MouseDown("left")


					case "drag":
						robotgo.MoveRelative(m.Payload.DX, m.Payload.DY)


					case "dragEnd":
						robotgo.MouseUp("left")


					case "swipeUp":
						handleSwipe("up")


					case "swipeDown":
						handleSwipe("down")


					case "swipeLeft":
						handleSwipe("left")


					case "swipeRight":
						handleSwipe("right")


					}
				case "keyboard":
					switch m.Action {
					case "press":
						robotgo.KeyTap(m.Payload.Key)
					case "down":
						robotgo.KeyDown(m.Payload.Key)
					case "up":
						robotgo.KeyUp(m.Payload.Key)
					}
				}
			}
		})
	})

	for {

		_, message, err := conn.ReadMessage()
		if err != nil {
			log.Println("Read error:", err)
			break
		}

		var msg Message

		err = json.Unmarshal(message, &msg)
		if err != nil {
			log.Println("JSON error:", err)
			continue
		}

		log.Printf("Received: %+v\n", msg)

		switch msg.Type {
		case "offer":
			offer := webrtc.SessionDescription{
				Type: webrtc.SDPTypeOffer,
				SDP:  msg.SDP,
			}

			err = peerConnection.SetRemoteDescription(offer)
			if err != nil {
				log.Println(err)
				continue
			}

			answer, err := peerConnection.CreateAnswer(nil)
			if err != nil {
				log.Println(err)
				continue
			}

			err = peerConnection.SetLocalDescription(answer)
			if err != nil {
				log.Println(err)
				continue
			}

			local := peerConnection.LocalDescription()

			response := Message{
				Type: "answer",
				SDP:  local.SDP,
			}

			data, err := json.Marshal(response)
			if err != nil {
				log.Println("Marshal error:", err)
				continue
			}

			err = conn.WriteMessage(websocket.TextMessage, data)
			if err != nil {
				log.Println("Write error:", err)
				continue
			}

		case "answer":

		case "candidate":
			lineIndex := uint16(msg.SDPMLineIndex)

			candidate := webrtc.ICECandidateInit{
				Candidate:     msg.Candidate,
				SDPMid:        &msg.SDPMid,
				SDPMLineIndex: &lineIndex,
			}

			err = peerConnection.AddICECandidate(candidate)
			if err != nil {
				log.Println(err)
				continue
			}

		default:
			log.Println("Unknown message:", msg.Type)
		}

		//		response, err := json.Marshal(msg)
		//		if err != nil {
		//			log.Println("Marshal error:", err)
		//			continue
		//		}
		//
		//		err = conn.WriteMessage(websocket.TextMessage, response)
		//		if err != nil {
		//			log.Println("Write error:", err)
		//			break
		//		}
	}

	log.Println("Client disconnected")
}

func main() {

	http.HandleFunc("/ws", wsHandler)

	log.Println("Server started on :8080")

	log.Fatal(http.ListenAndServe(":8080", nil))
}
