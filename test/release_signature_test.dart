import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/services/release_signature.dart';

void main() {
  test('signatures bind the version, checksum, and URL to the trusted key',
      () async {
    final algorithm = Ed25519();
    final key =
        await algorithm.newKeyPairFromSeed(List<int>.generate(32, (i) => i));
    final publicKey = base64Encode((await key.extractPublicKey()).bytes);
    const hash =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const url = 'https://example.com/release.apk';
    final signature = await algorithm
        .sign(utf8.encode(releaseSigningMessage(42, hash, url)), keyPair: key);
    final encoded = base64Encode(signature.bytes);
    expect(
        await verifyReleaseSignature(42, hash, url, encoded,
            publicKey: publicKey),
        isTrue);
    expect(
        await verifyReleaseSignature(43, hash, url, encoded,
            publicKey: publicKey),
        isFalse);
    expect(
        await verifyReleaseSignature(
            42, hash, 'https://evil.example/fake.apk', encoded,
            publicKey: publicKey),
        isFalse);
    expect(
        await verifyReleaseSignature(42, 'b$hash', url, encoded,
            publicKey: publicKey),
        isFalse);
    expect(
        await verifyReleaseSignature(42, hash, url, 'invalid',
            publicKey: publicKey),
        isFalse);
  });
}
