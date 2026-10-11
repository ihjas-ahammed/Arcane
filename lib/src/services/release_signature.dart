import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Only this public key ships in the app. The private release key is never
/// tracked or included in an application bundle.
const releasePublicKey = 'ao4/hfhuLfio5C3e2uHiyWR45bAZ7ZL9LcdtdXWYip4=';
String releaseSigningMessage(int versionCode, String hash, String url) =>
    'arcane-release-v1\n$versionCode\n$hash\n$url\n';
Future<bool> verifyReleaseSignature(
    int versionCode, String hash, String url, String signature,
    {String publicKey = releasePublicKey}) async {
  try {
    final key =
        SimplePublicKey(base64Decode(publicKey), type: KeyPairType.ed25519);
    return Ed25519().verify(
        utf8.encode(releaseSigningMessage(versionCode, hash, url)),
        signature: Signature(base64Decode(signature), publicKey: key));
  } catch (_) {
    return false;
  }
}
