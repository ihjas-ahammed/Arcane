#!/usr/bin/env python3
"""Verify prepared or downloaded release assets against the app's trust key."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--remote', action='store_true')
parser.add_argument('--repo', default='ihjas-ahammed/Arcane')
# Android-only release: the Linux bundle is neither built nor advertised.
parser.add_argument('--android-only', action='store_true')
args = parser.parse_args()
version, code = re.search(r'^version:\s*([^+\s]+)\+(\d+)', Path('pubspec.yaml').read_text(), re.M).groups()
code = int(code)
tag = f'v{version}-b{code}'
metadata = json.loads(Path('builds/update_info.json').read_text())
if metadata['version_code'] != code or metadata['version_name'] != version:
    raise SystemExit('Prepared metadata does not match pubspec.yaml.')
names = [f'missions-v{version}-b{code}-{abi}.apk' for abi in ('arm64-v8a', 'armeabi-v7a', 'x86_64')]
if not args.android_only:
    names.append(f'missions-v{version}-b{code}-linux-x86_64.tar.gz')
base = f'https://github.com/{args.repo}/releases/download/{tag}'
expected = re.search(r"const releasePublicKey = '([^']+)'", Path('lib/src/services/release_signature.dart').read_text())[1]
public = base64.b64decode(expected, validate=True)
if len(public) != 32:
    raise SystemExit('Invalid compiled Ed25519 trust key.')
with tempfile.TemporaryDirectory(prefix='arcane_verify_release_') as directory:
    temporary = Path(directory)
    public_file = temporary / 'public.der'
    # Ed25519 SubjectPublicKeyInfo wrapper; verification needs no private key.
    public_file.write_bytes(bytes.fromhex('302a300506032b6570032100') + public)
    location = Path('builds')
    if args.remote:
        location = temporary / 'assets'
        location.mkdir()
        command = ['gh', 'release', 'download', tag, '--repo', args.repo, '--dir', str(location)]
        for name in names:
            command.extend(['--pattern', name])
        subprocess.run(command, check=True)
    for name in names:
        path = location / name
        url = f'{base}/{name}'
        with path.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        if digest != metadata['package_sha256'][url] or path.stat().st_size != metadata['package_sizes'][url]:
            raise SystemExit(f'Hash or size mismatch: {name}')
        message = temporary / 'message'
        signature = temporary / 'signature'
        message.write_text(f'arcane-release-v1\n{code}\n{digest}\n{url}\n')
        signature.write_bytes(base64.b64decode(metadata['package_signatures'][url], validate=True))
        subprocess.run(['openssl', 'pkeyutl', '-verify', '-rawin', '-pubin', '-keyform', 'DER', '-inkey', str(public_file), '-in', str(message), '-sigfile', str(signature)], check=True, stdout=subprocess.DEVNULL)
        print(f'Verified {name}: {digest}')
print(f'{"Published" if args.remote else "Local"} release verified: {tag}, {len(names)} signed assets')
