#!/usr/bin/env python3
"""Terminate a saved native lesson process and cold-launch the installed app."""
import argparse
import json
from pathlib import Path
import plistlib
import signal
import socket
import subprocess
import time
import urllib.error
import urllib.request


APP = 'com.rw.qabas'


def simctl(device, *arguments):
    return subprocess.run(['xcrun', 'simctl', arguments[0], device, *arguments[1:]],
                          check=True, capture_output=True, text=True).stdout.strip()


def preferences(container):
    try:
        with (container / 'Library/Preferences/com.rw.qabas.plist').open('rb') as f:
            return plistlib.load(f)
    except (OSError, plistlib.InvalidFileException):
        return {}


def launch(device, out, name):
    # Attach to the installed app without reinstalling it between processes.
    # Neither app data nor the checkpoint is edited by the host.
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    stdout = (out / f'ios_resume_{name}_app.txt').resolve()
    stderr = (out / f'ios_resume_{name}_app_error.txt').resolve()
    stdout.write_text(''); stderr.write_text('')
    subprocess.run(['xcrun', 'simctl', 'launch', f'--stdout={stdout}',
                    f'--stderr={stderr}', '--terminate-running-process',
                    device, APP, '--start-paused', '--enable-dart-profiling',
                    '--disable-service-auth-codes', '--disable-vm-service-publication',
                    '--enable-checked-mode', '--verify-entry-points',
                    f'--vm-service-port={port}'], check=True, capture_output=True, text=True)
    uri = f'http://127.0.0.1:{port}/'
    deadline = time.monotonic() + 30
    while True:
        try:
            with urllib.request.urlopen(uri + 'getVM', timeout=1) as response:
                if json.load(response).get('result', {}).get('type') == 'VM':
                    return uri
        except (OSError, ValueError, urllib.error.URLError):
            pass
        if time.monotonic() > deadline:
            raise SystemExit(f'No VM service after cold launch; inspect {stderr}')
        time.sleep(.2)


def drive(device, uri):
    return ['flutter', 'drive', '--no-pub', '--keep-app-running',
            '--driver=test_driver/integration_test.dart',
            '--target=integration_test/phase12_resume_test.dart', '-d', device,
            '--dart-define-from-file=config/demo.json', f'--use-existing-app={uri}']


def stop_driver(process):
    try:
        process.wait(timeout=15)
    except subprocess.TimeoutExpired:
        process.send_signal(signal.SIGINT)
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill(); process.wait()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--device', required=True)
    p.add_argument('--binary', default='build/ios/iphonesimulator/Runner.app')
    args = p.parse_args()
    out = Path('build/phase12'); out.mkdir(parents=True, exist_ok=True)
    simctl(args.device, 'install', str(Path(args.binary).resolve()))
    container = Path(simctl(args.device, 'get_app_container', APP, 'data'))
    previous_id = preferences(container).get('flutter.qabas_phase12_resume_id')
    # This file selects setup; preferences, the secure token, mock history and
    # the local checkpoint remain the real persisted state under test.
    (container / 'tmp/phase12_resume_seed').write_text('seed')
    uri = launch(args.device, out, 'seed')
    seed_log = out / 'ios_resume_seed.txt'
    with seed_log.open('w') as log:
        seed = subprocess.Popen(drive(args.device, uri), stdout=log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 180
        while True:
            logs = seed_log.read_text() + (out / 'ios_resume_seed_app_error.txt').read_text()
            prefs = preferences(container)
            session_id = prefs.get('flutter.qabas_phase12_resume_id')
            try:
                checkpoints = json.loads(prefs.get('flutter.qabas_session_checkpoints', '{}'))
                saved = checkpoints.get(session_id, {})
                durable = (session_id and session_id != previous_id and
                           prefs.get('flutter.qabas_phase12_resume_stage') == 'ready' and
                           saved.get('stage') == 'feedback' and saved.get('feedback_exercise'))
            except (ValueError, TypeError):
                durable = False
            if 'PHASE12_KILL_READY' in logs and durable:
                break
            if seed.poll() is not None or time.monotonic() > deadline:
                stop_driver(seed) if seed.poll() is None else None
                raise SystemExit(f'No durable feedback checkpoint; inspect {seed_log}')
            time.sleep(.2)
        simctl(args.device, 'terminate', APP)
        print('Saved native feedback checkpoint; terminated the app process.', flush=True)
        stop_driver(seed)
    uri = launch(args.device, out, 'restore')
    restore_log = out / 'ios_resume_restore.txt'
    with restore_log.open('w') as log:
        result = subprocess.run(drive(args.device, uri), stdout=log, stderr=subprocess.STDOUT)
    logs = restore_log.read_text() + (out / 'ios_resume_restore_app_error.txt').read_text()
    if result.returncode or 'PHASE12_COLD_RESUME_PASSED' not in logs:
        raise SystemExit(f'Cold recovery failed; inspect {restore_log}')
    print(f'Cold recovery and the single retry passed; evidence: {restore_log}', flush=True)


if __name__ == '__main__':
    main()
