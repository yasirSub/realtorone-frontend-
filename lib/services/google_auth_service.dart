import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Shared Google Sign-In for login and register.
///
/// Android needs [webClientId] as `serverClientId` so the plugin returns an
/// id token for the backend. Error code 10 (DEVELOPER_ERROR) means SHA-1 /
/// package name mismatch in Firebase — common for Play Store builds.
class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '790178174861-af1d20utnlt0etqb17dpbkr0tcbahmfu.apps.googleusercontent.com',
  );

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile', 'openid'],
    serverClientId: webClientId.isEmpty ? null : webClientId,
  );

  Future<({GoogleSignInAccount account, String idToken})> signIn() async {
    debugPrint('[GOOGLE AUTH] signIn started (platform=${Platform.operatingSystem})');
    await _googleSignIn.signOut();
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw const GoogleSignInCancelledException();
    }
    debugPrint('[GOOGLE AUTH] account selected: ${account.email}');

    final auth = await account.authentication;
    final idToken = auth.idToken;
    debugPrint(
      '[GOOGLE AUTH] idToken present: ${idToken != null && idToken.isNotEmpty}',
    );
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        webClientId.isEmpty
            ? 'Google id token missing. Pass --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com'
            : 'Google id token missing. Check Firebase OAuth (web client) and SHA fingerprints.',
      );
    }

    return (account: account, idToken: idToken);
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  String platformErrorMessage(PlatformException e) {
    if (e.code != 'sign_in_failed') {
      return 'Google sign-in failed (${e.code}). ${e.message ?? ''}'.trim();
    }

    final details = (e.message ?? '').toLowerCase();
    final isDeveloperError = details.contains('10') ||
        details.contains('apiexception') ||
        details.contains('developer_error');

    if (!isDeveloperError) {
      return 'Google sign-in failed. ${e.message ?? 'Please try again.'}'.trim();
    }

    if (Platform.isAndroid) {
      return 'Google sign-in is not configured for this app build (error 10). '
          'Add your app SHA-1 in Firebase (Project settings → Android app). '
          'If you installed from Play Store, also add the App signing key SHA-1 '
          'from Play Console → Setup → App integrity, then download a new '
          'google-services.json and rebuild.';
    }

    return 'Google sign-in configuration error. Check Firebase iOS app, '
        'bundle id com.realtorone.app, and OAuth client in Google Cloud.';
  }
}

class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
}
