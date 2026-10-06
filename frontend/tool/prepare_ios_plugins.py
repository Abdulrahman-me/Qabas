"""Align the generated Swift plugin package with Runner before simulator builds.

Flutter may regenerate this ignored package at iOS 13. Xcode then cannot read
build settings for a plugin requiring iOS 14, preventing Flutter's automatic
deployment-target update. Run after `flutter build ios --config-only`, then use
`--no-pub` for native runs/tests. This edits only Flutter's ephemeral package.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
runner = root / "ios/Runner.xcodeproj/project.pbxproj"
targets = set(re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);", runner.read_text()))
if len(targets) != 1:
    raise SystemExit("Runner deployment targets must agree before preparation")
target = targets.pop()
manifest = root / "ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
if not manifest.exists():
    raise SystemExit("Run flutter build ios --config-only first")
text, count = re.subn(r'\.iOS\("[\d.]+"\)', f'.iOS("{target}")', manifest.read_text())
if count != 1:
    raise SystemExit("Unexpected generated package platform declaration")
manifest.write_text(text)
print(f"Generated Swift plugin package matches Runner: iOS {target}")
