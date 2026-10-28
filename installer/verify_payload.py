"""Manifest and PE verification; never executes staged binaries. Requires pefile."""
import hashlib
import csv
import json
import re
from pathlib import Path
import subprocess
import sys
import pefile

stage = Path(sys.argv[1]).resolve()
assert (stage/'demo/db/northwind.db').is_file(), 'Demo launch dependency northwind.db missing'
repo = Path(__file__).resolve().parents[1]
evidence = repo / 'build/release-audit'
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()

def record(path, relative, expected_machine=None):
    data = path.read_bytes()
    result = dict(filename=relative, size=len(data), sha256=hashlib.sha256(data).hexdigest(),
                  product_source_commit=commit, signed=False)
    if path.suffix.lower() in ('.exe', '.bpl'):
        pe = pefile.PE(data=data)
        result['machine'] = hex(pe.FILE_HEADER.Machine)
        result['architecture'] = {0x14c: 'Win32', 0x8664: 'Win64'}[pe.FILE_HEADER.Machine]
        if expected_machine is not None:
            assert pe.FILE_HEADER.Machine == expected_machine, (relative, 'wrong architecture')
        info = pe.VS_FIXEDFILEINFO[0]
        for name, ms, ls in [('file_version', info.FileVersionMS, info.FileVersionLS),
                             ('product_version', info.ProductVersionMS, info.ProductVersionLS)]:
            value = f'{ms >> 16}.{ms & 65535}.{ls >> 16}.{ls & 65535}'
            assert value == '1.0.1.0', (relative, name, value)
            result[name] = value
        result['dependencies'] = [entry.dll.decode('ascii') for entry in getattr(pe, 'DIRECTORY_ENTRY_IMPORT', [])]
        security = pe.OPTIONAL_HEADER.DATA_DIRECTORY[pefile.DIRECTORY_ENTRY['IMAGE_DIRECTORY_ENTRY_SECURITY']]
        assert security.Size == 0, (relative, 'unexpected signature')
        pe.close()
    elif path.suffix.lower() == '.dcp':
        result.update(architecture='Delphi Win32 compiler metadata', file_version=None, product_version=None)
    return result

records = []
for path in sorted(stage.rglob('*')):
    if not path.is_file():
        continue
    rel = path.relative_to(stage).as_posix()
    assert not path.is_symlink(), rel
    assert path.suffix.lower() not in ('.fdb', '.log', '.pdb', '.local', '.identcache', '.dcu'), rel
    machine = None
    if path.suffix.lower() in ('.exe', '.bpl'):
        intended = {
            'Bpl/VittixReportRuntime.bpl': 0x14c,
            'Bpl/VittixReportDesign.bpl': 0x14c,
            'vittixdesigner/VittixDesigner.exe': 0x14c,
            'vittixdesigner/Win64/VittixDesigner.exe': 0x8664,
            'demo/VittixReportDemo.exe': 0x14c,
        }
        assert rel in intended, ('unexpected executable', rel)
        machine = intended[rel]
    records.append(record(path, rel, machine))
assert sum(r['filename'].endswith(('.exe', '.bpl')) for r in records) == 5
# Verify distribution bytes against Git blobs, allowing only CRLF/LF conversion
# for known text formats, not arbitrary working checkout or staged source edits.
# checkout or a previous manifest. Only rebuilt resources and explicit outputs
# are exceptions. A compile-only invocation cannot silently import stage extras.
generated = {
    'packages/VittixReportRuntime.res', 'packages/VittixReportDesign.res',
    'demo/VittixReportDemo.res', 'demo/db/northwind.db',
}
sources = [r for r in records if r['filename'] not in generated and
           not r['filename'].endswith(('.exe', '.bpl', '.dcp'))]
queries = ''.join(f"HEAD:{r['filename']}\n" for r in sources).encode()
batch = subprocess.run(['git', 'cat-file', '--batch'], cwd=repo, input=queries,
                       stdout=subprocess.PIPE, check=True).stdout
offset = 0
for entry in sources:
    end = batch.index(b'\n', offset)
    header = batch[offset:end].split()
    assert len(header) == 3 and header[1] == b'blob', ('untracked stage input', entry['filename'])
    size = int(header[2])
    blob = batch[end+1:end+1+size]
    staged = (stage/entry['filename']).read_bytes()
    if Path(entry['filename']).suffix.lower() in ('.pas', '.inc', '.dfm', '.dpk', '.dpr', '.dproj', '.md', '.sql', '.vrt') or Path(entry['filename']).name == 'LICENSE':
        blob = blob.replace(b'\r\n', b'\n')
        staged = staged.replace(b'\r\n', b'\n')
    assert staged == blob, ('source differs from merged Git blob', entry['filename'])
    offset = end+size+2
assert hashlib.sha256((stage/'demo/db/northwind.db').read_bytes()).hexdigest() == '324f1362b2f4fead11ab4f5a5667a57226b61af5a39c22f480011502dc109185', 'Unexpected Northwind sample bytes'
manifest_path = evidence/'payload-manifest.json'
if len(sys.argv) > 2:
    assert json.loads(manifest_path.read_text()) == records, 'Stage changed during compilation'
else:
    manifest_path.write_text(json.dumps(records, indent=2)+'\n')
print(f'PASS payload: {len(records)} files, five PE artifacts, correct architectures and 1.0.1.0 versions')
if len(sys.argv) > 2:
    setup = Path(sys.argv[2]).resolve()
    result = record(setup, setup.name, 0x14c)
    # Compare actual compiler inputs against the whole staged allowlist. The
    # branding icon is compiled into setup, not installed as an application file.
    raw = (evidence/'iscc-build.log').read_bytes()
    log = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')
    expanded = (evidence/'preprocessed.iss').read_text(encoding='utf-8-sig')
    assert re.findall(r'^AppId=(.+)$', expanded, re.M) == ['{{B7E91D42-8C3A-4F6E-9D25-1A0C7E4B8F63}']
    assert 'DefaultDirName={commonpf}\\VittixReport' in expanded
    assert 'PrivilegesRequired=admin' in expanded
    assert 'PrivilegesRequiredOverridesAllowed=' not in expanded
    assert 'DisableDirPage=yes' in expanded and 'UsePreviousAppDir=yes' in expanded
    assert "Result := IsSamePath(Candidate, Expected);" in expanded
    assert 'function InitializeSetup: Boolean' in expanded
    assert 'HasDirCommandLineOverride' in expanded
    assert 'function PrepareToInstall(var NeedsRestart: Boolean): String' in expanded
    assert 'function ValidateInstallLocation(const Candidate: string; RequireBpl: Boolean;' in expanded
    assert 'GetNamedSecurityInfoW' in expanded and 'AccessCheck' in expanded
    assert 'DACL_SECURITY_INFORMATION or OWNER_SECURITY_INFORMATION or GROUP_SECURITY_INFORMATION' in expanded
    assert 'not IsValidSid(Owner) or not IsValidSid(Group)' in expanded
    assert 'FILE_ATTRIBUTE_REPARSE_POINT' in expanded
    compressed = {Path(p.strip()).resolve() for p in re.findall(r'^\s+Compressing: (.+)$', log, re.M)}
    expected = {stage/r['filename'] for r in records if r['filename'] != 'branding/vittix-report.ico'}
    assert compressed == expected, (str(compressed-expected), str(expected-compressed))
    with (setup.parent/'VittixReport-1.0.1-payload.txt').open(encoding='utf-8-sig', newline='') as stream:
        compiler_records = list(csv.DictReader(stream, delimiter='\t'))
    assert len(compiler_records) == len(expected), 'Compiler manifest count mismatch'
    by_path = {stage/r['filename']: r for r in records}
    for entry in compiler_records:
        source = Path(entry['SourceFilename']).resolve()
        assert source in expected, ('unexpected compiled source', str(source))
        assert entry['SHA256Sum'] == by_path[source]['sha256'], ('embedded hash mismatch', str(source))
        assert int(entry['OriginalSize']) == by_path[source]['size'], ('embedded size mismatch', str(source))
    result['compiled_payload_files'] = len(compressed)
    result['compiler_manifest_hashes_verified'] = True
    result['installer_source_state'] = 'uncommitted release-preparation changes; see installer-source-manifest.json'
    source_records = []
    for p in sorted((repo/'installer').rglob('*')):
        if p.is_file() and '__pycache__' not in p.parts and p.suffix.lower() != '.pyc':
            source_records.append(dict(filename=p.relative_to(repo).as_posix(),
                                       sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    (evidence/'installer-source-manifest.json').write_text(json.dumps(source_records, indent=2)+'\n')
    (evidence/'installer-artifact.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))
