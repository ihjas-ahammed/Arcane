#!/usr/bin/env python3
"""Generate checksummed, Ed25519-signed metadata for completed local builds."""
import argparse, base64, hashlib, json, os, re, subprocess, tempfile
from datetime import datetime, timezone
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--repo', default='ihjas-ahammed/Arcane')
parser.add_argument('--branch', default='revive2')
parser.add_argument('--signing-key', default='.release_keys/update_signing.pem')
# Android-only release: no Linux bundle, so no Linux URLs may be advertised.
parser.add_argument('--android-only', action='store_true')
# Build and advertise only the arm64-v8a APK (the owner's phone).
parser.add_argument('--arm64-only', action='store_true')
args = parser.parse_args()
version, code = re.search(r'^version:\s*([^+\s]+)\+(\d+)', Path('pubspec.yaml').read_text(), re.M).groups()
code = int(code)
tag = f'v{version}-b{code}'
base = f'https://github.com/{args.repo}/releases/download/{tag}'
key = Path(args.signing_key)
if not key.is_file(): raise SystemExit('The private release signing key is required.')
public = subprocess.check_output(['openssl','pkey','-in',str(key),'-pubout','-outform','DER'])[-32:]
expected = re.search(r"const releasePublicKey = '([^']+)'",Path('lib/src/services/release_signature.dart').read_text())[1]
if base64.b64encode(public).decode() != expected: raise SystemExit('Signing key does not match the public key compiled into the app.')
arches = {'arm64-v8a':2000,'armeabi-v7a':1000,'x86_64':4000}
if args.arm64_only: arches = {'arm64-v8a':0}  # not split per ABI: base version code
names = {abi:f'missions-v{version}-b{code}-{abi}.apk' for abi in arches}
linux_name = f'missions-v{version}-b{code}-linux-x86_64.tar.gz'
hashes, signatures, sizes = {}, {}, {}
packages = [*names.values()] + ([] if args.android_only else [linux_name])
for name in packages:
    path = Path('builds')/name
    if not path.is_file() or path.stat().st_size < 1024*1024: raise SystemExit(f'Missing or truncated build: {path}')
    with path.open('rb') as stream: digest = hashlib.file_digest(stream,'sha256').hexdigest()
    url = f'{base}/{name}'
    hashes[url] = digest
    sizes[url] = path.stat().st_size
    with tempfile.TemporaryDirectory(prefix='arcane_sign_') as temp:
        message = Path(temp)/'message'; signature = Path(temp)/'signature'
        message.write_text(f'arcane-release-v1\n{code}\n{digest}\n{url}\n')
        subprocess.run(['openssl','pkeyutl','-sign','-rawin','-inkey',str(key),'-in',str(message),'-out',str(signature)],check=True)
        signatures[url] = base64.b64encode(signature.read_bytes()).decode()
metadata = {
 'version_code':code,'version_name':version,'published_at':datetime.now(timezone.utc).isoformat().replace('+00:00','Z'),
 'min_supported_version_code':2026010101,
 'apk_filename':names['arm64-v8a'],'apk_url':f"{base}/{names['arm64-v8a']}",
 'apk_arch_urls':{abi:f'{base}/{name}' for abi,name in names.items()},
 'apk_arch_version_codes':{abi:code+offset for abi,offset in arches.items()},
 'package_sha256':hashes,'package_signatures':signatures,'package_sizes':sizes,
 'changelog_url':f'https://raw.githubusercontent.com/{args.repo}/{args.branch}/builds/latest.md',
}
if not args.android_only:
    metadata.update({'linux_filename':linux_name,'linux_url':f'{base}/{linux_name}',
                     'linux_arch_urls':{'x86_64':f'{base}/{linux_name}'}})
for filename in ['builds/update_info.json','builds/latest.json']:
    Path(filename).write_text(json.dumps(metadata,indent=2)+'\n')
print(f'Signed metadata prepared for {tag}: {len(hashes)} packages')
