from pathlib import Path
import re

manifest=Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    s=manifest.read_text()
    if 'android.permission.INTERNET' not in s:
        p=s.find('>')
        s=s[:p+1]+'\n    <uses-permission android:name="android.permission.INTERNET" />'+s[p+1:]
    if 'android:scheme="tz"' not in s:
        pattern=r'(<activity[^>]*android:name="\.MainActivity"[^>]*>)(.*?)(</activity>)'
        m=re.search(pattern,s,re.S)
        filt='''\n            <intent-filter>\n                <action android:name="android.intent.action.VIEW" />\n                <category android:name="android.intent.category.DEFAULT" />\n                <category android:name="android.intent.category.BROWSABLE" />\n                <data android:scheme="tz" android:host="auth-callback" />\n            </intent-filter>'''
        if m:
            block=m.group(1)+m.group(2)+filt+m.group(3)
            s=s[:m.start()]+block+s[m.end():]
    manifest.write_text(s)

plist=Path('ios/Runner/Info.plist')
if plist.exists():
    s=plist.read_text()
    if '<key>CFBundleURLTypes</key>' not in s:
        insert='''\n\t<key>CFBundleURLTypes</key>\n\t<array>\n\t\t<dict>\n\t\t\t<key>CFBundleTypeRole</key><string>Editor</string>\n\t\t\t<key>CFBundleURLSchemes</key>\n\t\t\t<array><string>tz</string></array>\n\t\t</dict>\n\t</array>\n'''
        s=s.replace('</dict>\n</plist>',insert+'</dict>\n</plist>',1)
    plist.write_text(s)
print('Native TZ auth callback and Android network configuration prepared.')
