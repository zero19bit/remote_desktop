@echo off

mkdir lib\app
mkdir lib\core\constants
mkdir lib\core\network
mkdir lib\core\utils

mkdir lib\features\remote_desktop\data\models
mkdir lib\features\remote_desktop\data\services

mkdir lib\features\remote_desktop\presentation\pages
mkdir lib\features\remote_desktop\presentation\widgets

mkdir lib\features\remote_desktop\controller

mkdir lib\shared\widgets


type nul > lib\app\app.dart
type nul > lib\app\routes.dart

type nul > lib\core\constants\app_constants.dart
type nul > lib\core\network\websocket_service.dart
type nul > lib\core\utils\logger.dart

type nul > lib\features\remote_desktop\data\models\signaling_message.dart

type nul > lib\features\remote_desktop\data\services\webrtc_service.dart

type nul > lib\features\remote_desktop\presentation\pages\remote_page.dart

type nul > lib\features\remote_desktop\presentation\widgets\control_panel.dart

type nul > lib\features\remote_desktop\controller\remote_controller.dart

type nul > lib\shared\widgets\.gitkeep


echo Flutter structure created successfully
pause