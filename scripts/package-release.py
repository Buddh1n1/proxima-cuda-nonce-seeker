"""Package only a built executable, public documentation and dependency licenses."""
import argparse, hashlib, json, pathlib, re, subprocess, zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--exe', required=True, type=pathlib.Path)
parser.add_argument('--metadata', required=True, type=pathlib.Path)
parser.add_argument('--out', required=True, type=pathlib.Path)
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[1]
metadata = json.loads(args.metadata.read_text(encoding='utf-8-sig'))
payload = {'nonce_seeker_cuda.exe': args.exe.read_bytes()}
for name in ['README.md', 'MINING-GUIDE.md', 'BUILD.md', 'LICENSE', 'NOTICE', 'SOURCE-MANIFEST.json']:
    payload[name] = (root / name).read_bytes()
for p in sorted((root / 'LICENSES').glob('*')):
    if p.is_file():
        payload['LICENSES/' + p.name] = p.read_bytes()

notices = []
for package in sorted(metadata['packages'], key=lambda p: (p['name'], p['version'])):
    if not package.get('source'):
        continue
    directory = pathlib.Path(package['manifest_path']).parent
    names = {p for pattern in ('LICENSE*', 'LICENCE*', 'COPYING*', 'NOTICE*')
             for p in directory.glob(pattern) if p.is_file()}
    if package.get('license_file'):
        names.add(directory / package['license_file'])
    if not names:
        raise SystemExit('Missing license text for ' + package['name'])
    prefix = 'LICENSES/dependencies/' + package['name'] + '-' + package['version'] + '/'
    for p in sorted(names):
        payload[prefix + p.name] = p.read_bytes()
    notices.append(package['name'] + ' ' + package['version'] + ': ' + str(package.get('license')))
payload['THIRD-PARTY-NOTICES.txt'] = ('\n'.join(notices) + '\n').encode()
payload['SHA256SUMS.txt'] = ''.join(hashlib.sha256(raw).hexdigest() + '  ' + name + '\n'
                                    for name, raw in sorted(payload.items())).encode()
patterns = [rb'(?i)[A-Z]:[\\/]Users[\\/]', rb'(?i)[A-Z]:[\\/]a[\\/]',
            rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
            rb'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}']
for name, raw in payload.items():
    for pattern in patterns:
        if re.search(pattern, raw) or re.search(pattern, raw.replace(b'\0', b'')):
            raise SystemExit('Release hygiene check failed: ' + name)
args.out.mkdir(parents=True, exist_ok=True)
archive = args.out / 'proxima-cuda-nonce-seeker-windows-x64-sm86.zip'
with zipfile.ZipFile(archive, 'x', zipfile.ZIP_DEFLATED) as z:
    for name, raw in sorted(payload.items()):
        item = zipfile.ZipInfo(name, (2026, 10, 21, 0, 0, 0))
        item.compress_type = zipfile.ZIP_DEFLATED
        item.external_attr = 0o100644 << 16
        z.writestr(item, raw)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert set(z.namelist()) == set(payload)
    for name, raw in payload.items():
        assert z.read(name) == raw
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
(args.out / 'SHA256SUMS.txt').write_text(checksum + '  ' + archive.name + '\n', encoding='ascii')
print(json.dumps({'archive': archive.name, 'sha256': checksum, 'files': len(payload)}))
