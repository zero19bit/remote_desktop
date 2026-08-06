@echo off

mkdir cmd\server

mkdir internal\websocket
mkdir internal\signaling
mkdir internal\webrtc
mkdir internal\input
mkdir internal\logger

mkdir pkg


type nul > cmd\server\main.go

type nul > internal\websocket\handler.go
type nul > internal\websocket\client.go

type nul > internal\signaling\message.go

type nul > internal\webrtc\peer.go
type nul > internal\webrtc\config.go
type nul > internal\webrtc\events.go

type nul > internal\input\controller.go

type nul > internal\logger\logger.go


echo Go structure created successfully
pause