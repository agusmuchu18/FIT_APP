import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Uses official providers only when the social service is explicitly enabled.
/// Registration and web site key are deployment prerequisites, never fake tokens.
abstract final class SocialAttestation {
  static Future<void>? _activation;
  static Future<void> _activate() async {
    const siteKey = String.fromEnvironment('FIT_SOCIAL_RECAPTCHA_SITE_KEY');
    if (kIsWeb && siteKey.isEmpty) {
      throw StateError('App Check web registration is not configured.');
    }
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      throw UnsupportedError(
        'A verified App Check provider is unavailable on this platform.',
      );
    }
    await FirebaseAppCheck.instance.activate(
      providerWeb: kIsWeb ? ReCaptchaV3Provider(siteKey) : null,
      providerAndroid: const AndroidPlayIntegrityProvider(),
      providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }

  static Future<String?> token() async {
    final activation = _activation ??= _activate();
    try {
      await activation;
    } catch (_) {
      if (identical(_activation, activation)) _activation = null;
      rethrow;
    }
    final token = await FirebaseAppCheck.instance.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('App attestation unavailable.');
    }
    return token;
  }
}
