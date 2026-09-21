"""Architecture checks, not a substitute for device acceptance."""
from pathlib import Path
import plistlib
import re
root = Path(__file__).resolve().parents[1]
for directory in ['WatchApp', 'Shared']:
    for path in (root / directory).rglob('*.swift'):
        text = path.read_text()
        for forbidden in [r'URLSession', r'URLRequest', r'import Speech\b', r'AIWRIST_GATEWAY_URL', r'AIWRIST_DEVICE_TOKEN', r'/api/v1/']:
            assert not re.search(forbidden, text), (path, forbidden)
watch = plistlib.loads((root / 'Config/Watch-Info.plist').read_bytes())
assert watch['WKCompanionAppBundleIdentifier'] == '$(AIWRIST_BUNDLE_ID)'
assert watch['WKRunsIndependentlyOfCompanionApp'] is False
assert watch['NSMicrophoneUsageDescription']
project = (root / 'AIWristCom.xcodeproj/project.pbxproj').read_text()
assert 'Embed Watch Content' in project
assert 'AIWristCoreTests' in project
assert 'tests/CoreTests' in project
assert 'AIWRIST_GATEWAY_URL' not in str(watch)
print('PASS: Watch network boundary, companion metadata, test target')
