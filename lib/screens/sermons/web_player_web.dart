// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

import '../../theme/app_theme.dart';

class WebMediaPlayer {
  static bool isSafari() {
    try {
      final ua = html.window.navigator.userAgent.toLowerCase();
      final hasSafari = ua.contains('safari');
      final isChrome  = ua.contains('chrome') || ua.contains('crios');
      final isFirefox = ua.contains('firefox') || ua.contains('fxios');
      final isEdge    = ua.contains('edg');
      return hasSafari && !isChrome && !isFirefox && !isEdge;
    } catch (_) {
      return false;
    }
  }

  static String _convertYoutubeToEmbed(String url) {
    String? id;
    final youtubeRegex = RegExp(
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/|youtube\.com\/shorts\/)([\w-]{11})',
    );
    final match = youtubeRegex.firstMatch(url);
    if (match != null) id = match.group(1);
    if (id != null) return 'https://www.youtube.com/embed/$id';
    return url;
  }

  static Widget build({
    required String url,
    required String mediaType,
    required VoidCallback onCloseSheet,
  }) {
    // Safari fallback: open in new tab
    if (isSafari()) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              mediaType == 'audio' ? Icons.audiotrack : Icons.play_circle,
              size: 64,
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tap below to open media',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(url);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                onCloseSheet();
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(mediaType == 'audio' ? 'Play Audio' : 'Watch Video'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    final viewType = 'html5-player-${url.hashCode}';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      if (mediaType == 'audio') {
        final audio = html.AudioElement()
          ..src = url
          ..controls = true
          ..autoplay = false
          ..style.width = '100%'
          ..style.height = '80px';
        return audio;
      } else {
        if (url.contains('youtube.com') || url.contains('youtu.be')) {
          final embedUrl = _convertYoutubeToEmbed(url);
          final iframe = html.IFrameElement()
            ..src = embedUrl
            ..style.border = '0'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allowFullscreen = true
            ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';
          return iframe;
        }
        final video = html.VideoElement()
          ..src = url
          ..controls = true
          ..autoplay = false
          ..style.width = '100%'
          ..style.height = '100%';
        return video;
      }
    });
    return HtmlElementView(viewType: viewType);
  }
}