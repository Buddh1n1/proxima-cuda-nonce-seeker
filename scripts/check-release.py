"""Conservative source-release hygiene check; never print matched values."""
import ipaddress,pathlib,re,sys
root=pathlib.Path(__file__).resolve().parents[1]
findings=[];count=0
for p in root.rglob('*'):
 rel=p.relative_to(root)
 if any(x in {'.git','target'}for x in rel.parts):continue
 if p.is_symlink():findings.append((str(rel),'symlink'));continue
 if not p.is_file():continue
 count+=1;raw=p.read_bytes()
 if p.suffix.lower()in {'.exe','.dll','.pdb','.key','.pem','.p12','.pass','.passphrase','.log'}or p.name in {'proxi.yaml','.env'}:
  findings.append((str(rel),'runtime/credential/build artifact'))
 for label,pattern in [
  ('private key block',rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
  ('absolute operator path',rb'(?i)[A-Z]:[\\/]Users[\\/][^\\/\s]+|/'+b'home'+rb'/[^/\s]+/'),
  ('GitHub credential',rb'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}'),
 ]:
  if re.search(pattern,raw):findings.append((str(rel),label))
 # Source fixtures may use loopback. A shipped real endpoint needs review.
 for value in re.findall(rb'(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])',raw):
  try:address=ipaddress.ip_address(value.decode())
  except ValueError:continue
  if not address.is_loopback and str(address)!='0.0.0.0':findings.append((str(rel),'non-loopback endpoint'));break
for name,label in findings:print(name+': '+label)
print('Scanned '+str(count)+' files; '+str(len(findings))+' findings. Pattern checks do not prove absence of all secrets.')
sys.exit(1 if findings else 0)
