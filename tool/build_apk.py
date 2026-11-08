import argparse
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--profile', type=Path)
    parser.add_argument('--debug', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    command = ['flutter', 'build', 'apk', '--debug' if args.debug else '--release',
               '--target-platform', 'android-arm64']
    if args.profile:
        profile = json.loads(args.profile.read_text())
        directory = root / '.ai/build'
        directory.mkdir(parents=True, exist_ok=True)
        defines = directory / 'profile-defines.json'
        defines.write_text(json.dumps({'INITIAL_PROFILE': json.dumps(profile, ensure_ascii=False)},
                                     ensure_ascii=False))
        defines.chmod(0o600)
        command.append(f'--dart-define-from-file={defines}')
    subprocess.run(command, cwd=root, check=True)


if __name__ == '__main__':
    main()
