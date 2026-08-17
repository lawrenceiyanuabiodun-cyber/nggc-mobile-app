import 'package:flutter/material.dart';

/// Stub implementation for mobile (Android/iOS).
/// Does nothing - the actual web player is in web_player_web.dart
class WebMediaPlayer {
  static bool isSafari() => false;

  static Widget build({
    required String url,
    required String mediaType,
    required VoidCallback onCloseSheet,
  }) {
    return const SizedBox.shrink();
  }
}