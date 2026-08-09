import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// SupportService
/// Handles opening WhatsApp, Email, and Phone dialer from within the app.
/// Used by SupportScreen.
class SupportService {
  // ─────────────────────────────────────────────────────────
  // Admin Contact Details
  // ─────────────────────────────────────────────────────────
  static const String adminEmail = 'lawrenceiyanuabiodun@gmail.com';
  static const String adminWhatsApp = '2347041926783'; // no +, no spaces
  static const String adminPhone = '+2347041926783';

  // ─────────────────────────────────────────────────────────
  // Open WhatsApp with pre-filled message
  // ─────────────────────────────────────────────────────────
  static Future<bool> openWhatsApp({
    required String reason,
    BuildContext? context,
  }) async {
    final message = _buildMessage(reason);
    final encodedMessage = Uri.encodeComponent(message);

    // Try WhatsApp app first (wa.me works for both app + web)
    final url = Uri.parse('https://wa.me/$adminWhatsApp?text=$encodedMessage');

    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context != null && context.mounted) {
        _showError(context, 'Could not open WhatsApp. Is it installed?');
      }
      return launched;
    } catch (e) {
      if (context != null && context.mounted) {
        _showError(context, 'Could not open WhatsApp.');
      }
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // Open Email with pre-filled subject + body
  // ─────────────────────────────────────────────────────────
  static Future<bool> openEmail({
    required String reason,
    BuildContext? context,
  }) async {
    final subject = '[NGGC App] $reason';
    final body = _buildMessage(reason);

    final url = Uri(
      scheme: 'mailto',
      path: adminEmail,
      query: _encodeQueryParameters({
        'subject': subject,
        'body': body,
      }),
    );

    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context != null && context.mounted) {
        _showError(context, 'Could not open email app.');
      }
      return launched;
    } catch (e) {
      if (context != null && context.mounted) {
        _showError(context, 'Could not open email app.');
      }
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // Pre-filled message body
  // ─────────────────────────────────────────────────────────
  static String _buildMessage(String reason) {
    return 'Hello Admin,\n\n'
        'I am reaching out about: $reason\n\n'
        '[Please type your message here]\n\n'
        '---\n'
        'Sent from NGGC Sunday School App';
  }

  // ─────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────
  static String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}