"""Fail CI if the installable bundle lacks the widget or its shared configuration."""
import pathlib
import plistlib
import sys

app = pathlib.Path(sys.argv[1])
extension = app / 'PlugIns' / 'ScheduleWidget.appex'
assert extension.is_dir(), 'Widget extension missing from app bundle'
with (app / 'Info.plist').open('rb') as f:
    main = plistlib.load(f)
with (extension / 'Info.plist').open('rb') as f:
    widget = plistlib.load(f)
assert widget['NSExtension']['NSExtensionPointIdentifier'] == 'com.apple.widgetkit-extension'
assert widget['CFBundleIdentifier'] == main['CFBundleIdentifier'] + '.ScheduleWidget'
assert widget['YIClassAppGroup'] == main['YIClassAppGroup']
assert main['YIClassAppGroup'].startswith('group.')
assert '$(' not in main['YIClassAppGroup']
assert widget['CFBundleVersion'] == main['CFBundleVersion']
assert (extension / widget['CFBundleExecutable']).stat().st_size > 0
print('Verified embedded WidgetKit extension:', widget['CFBundleIdentifier'])
print('Shared App Group:', main['YIClassAppGroup'])
