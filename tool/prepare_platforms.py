from pathlib import Path
import re

# Native platform requirements for TZ production builds.
# Internet access is required on Android; tz://auth-callback/ is used for
# Supabase password recovery and email confirmation to return to the app.
manifest=Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    s=manifest.read_text()
    if 'android.permission.INTERNET' not in s:
        s=s.replace('<manifest ', '<manifest ', 1)
        pos=s.find('>')
        s=s[:pos+1]+'\n    <uses-permission android:name="android.permission.INTERNET" />'+s[pos+1:]
    if 'android:scheme="tz"' not in s:
        marker='<application '
        i=s.find(marker)
        if i>=0:
            app_end=s.find('>',i)+1
            filt='''\n        <activity android:name=".MainActivity" android:exported="true">\n            <intent-filter>\n                <action android:name="android.intent.action.VIEW" />\n                <category android:name="android.intent.category.DEFAULT" />\n                <category android:name="android.intent.category.BROWSABLE" />\n                <data android:scheme="tz" android:host="auth-callback" />\n            </intent-filter>\n        </activity>'''
            # flutter's MainActivity already exists; add the filter to the existing activity instead.
            s=s.replace('</activity>',filt+'\n    </activity>',1) if '</activity>' in s else s
    manifest.write_text(s)

plist=Path('ios/Runner/Info.plist')
if plist.exists():
    s=plist.read_text()
    if '<key>CFBundleURLTypes</key>' not in s:
        insert='''\n\t<key>CFBundleURLTypes</key>\n\t<array>\n\t\t<dict>\n\t\t\t<key>CFBundleTypeRole</key><string>Editor</string>\n\t\t\t<key>CFBundleURLSchemes</key><array><string>tz</string></array>\n\t\t</dict>\n\t</array>\n'''
        s=s.replace('</dict>\n</plist>',insert+'</dict>\n</plist>',1)
    plist.write_text(s)
print('Native TZ auth callback and Android network configuration prepared.')
