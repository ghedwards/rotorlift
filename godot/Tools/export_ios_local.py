#!/usr/bin/env python3
"""Export with Godot, archive locally, then sign for TestFlight without a device profile."""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot'))
    parser.add_argument('--xcode', type=Path, default=Path('/Applications/Xcode.app'))
    parser.add_argument('--upload', action='store_true', help='Upload to App Store Connect instead of exporting a local IPA')
    args = parser.parse_args()
    if not args.godot:
        parser.error('Pass --godot with the Godot executable path')
    project = Path(__file__).resolve().parents[1]
    output = project / 'builds/ios'
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env['DEVELOPER_DIR'] = str(args.xcode / 'Contents/Developer')
    # Xcode invokes rsync helpers through PATH; Homebrew rsync is incompatible
    # with Apple's extended-attributes flags during IPA packaging.
    env['PATH'] = '/usr/bin:/bin:/usr/sbin:/sbin'

    def run(label, command, logfile):
        print(label, flush=True)
        with logfile.open('w') as stream:
            result = subprocess.run(command, cwd=project, env=env, stdout=stream, stderr=subprocess.STDOUT)
        if result.returncode:
            raise SystemExit(f'{label} failed; see {logfile}')

    run('Exporting project through Godot', [str(Path(args.godot).resolve()), '--headless', '--path', str(project), '--export-release', 'iOS TestFlight', str(output / 'Rotorlift.ipa')], output / 'godot-export.log')
    archive = output / 'Rotorlift.xcarchive'
    run('Archiving for iPhone', ['/usr/bin/xcodebuild', '-project', str(output / 'Rotorlift.xcodeproj'), '-scheme', 'Rotorlift', '-sdk', 'iphoneos', '-configuration', 'Release', '-destination', 'generic/platform=iOS', '-archivePath', str(archive), 'CODE_SIGNING_ALLOWED=NO', 'archive'], output / 'archive.log')
    options = {
        'method': 'app-store-connect', 'destination': 'upload' if args.upload else 'export',
        'teamID': 'EA3D6755HZ', 'signingStyle': 'automatic',
        'uploadSymbols': True, 'manageAppVersionAndBuildNumber': False,
    }
    options_path = output / 'local-export-options.plist'
    options_path.write_bytes(plistlib.dumps(options))
    run('Signing and uploading to App Store Connect' if args.upload else 'Signing IPA for App Store distribution', ['/usr/bin/xcodebuild', '-exportArchive', '-archivePath', str(archive), '-exportOptionsPlist', str(options_path), '-allowProvisioningUpdates', '-exportPath', str(output / 'testflight')], output / 'distribution.log')
    print('Upload submitted; check App Store Connect for processing.' if args.upload else f'Exported {output / "testflight/Rotorlift.ipa"}')


if __name__ == '__main__':
    main()
