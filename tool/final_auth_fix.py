from pathlib import Path
import re

AUTH_REDIRECT = 'https://temz.ng/tz-auth/'
DEEP_LINK = 'tz://auth-callback/'

source = Path('lib/tz_build.dart')
s = source.read_text(encoding='utf-8')

# Use publishable key + PKCE for mobile authentication.
s = s.replace(
    "Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey)",
    "Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey, authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce))"
)
s = s.replace(
    "Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey)",
    "Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey, authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce))"
)

# Keep the login/recovery pages pointed at the public confirmation page.
for filename in ['lib/password_pages.dart', 'lib/admin_setup.dart']:
    p = Path(filename)
    if p.exists():
        text = p.read_text(encoding='utf-8')
        text = text.replace("const _authRedirect = 'tz://auth-callback/';", f"const _authRedirect = '{AUTH_REDIRECT}';")
        p.write_text(text, encoding='utf-8')

# Agents can be deactivated/reactivated by an admin. Preserve the profile and history.
s = s.replace(
    "select('role,full_name,password_set')",
    "select('role,full_name,password_set,available')"
)
s = s.replace(
    "passwordSet = row['password_set'] == null ? true : row['password_set'] as bool;",
    "passwordSet = row['password_set'] == null ? true : row['password_set'] as bool;\n        if (row['role'] == 'agent' && row['available'] == false) throw Exception('Your Temz Store agent account is currently inactive. Contact an administrator.');"
)

old_agent_trailing = "trailing: Icon(a['password_set'] == true ? Icons.verified_user : Icons.key_off, color: a['password_set'] == true ? green : orange),"
new_agent_trailing = """trailing: PopupMenuButton<String>(
                  tooltip: a['available'] == true ? 'Remove agent' : 'Restore agent',
                  icon: Icon(a['available'] == true ? Icons.person_remove_alt_1 : Icons.person_add_alt_1, color: a['available'] == true ? red : green),
                  onSelected: (action) async {
                    try {
                      final active = action == 'activate';
                      await db.rpc('tz_set_agent_active', params: {'p_agent': a['id'], 'p_active': active});
                      refresh();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: a['available'] == true ? 'deactivate' : 'activate', child: Text(a['available'] == true ? 'Remove agent' : 'Restore agent')),
                  ],
                ),"""
if old_agent_trailing in s:
    s = s.replace(old_agent_trailing, new_agent_trailing)

# Also show inactive agents clearly in the list.
s = s.replace(
    "Text('${a['email'] ?? ''}\\n${a['state'] ?? 'State not set'} • ${a['available'] == true ? 'Available' : 'Unavailable'}'),",
    "Text('${a['email'] ?? ''}\\n${a['state'] ?? 'State not set'} • ${a['available'] == true ? 'Active' : 'Removed'}'),"
)

# Ensure the confirmation/recovery redirect is visible to the user in the login flow.
if "const String authRedirect" not in s:
    s = s.replace("const String supabaseKey =", "const String authRedirect = 'https://temz.ng/tz-auth/';\nconst String supabaseKey =")

source.write_text(s, encoding='utf-8')

# Android deep-link registration.
manifest = Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    m = manifest.read_text(encoding='utf-8')
    intent = '''\n            <intent-filter>\n                <action android:name="android.intent.action.VIEW" />\n                <category android:name="android.intent.category.DEFAULT" />\n                <category android:name="android.intent.category.BROWSABLE" />\n                <data android:scheme="tz" android:host="auth-callback" />\n            </intent-filter>'''
    if 'android:scheme="tz"' not in m:
        pos = m.find('</activity>')
        if pos != -1:
            m = m[:pos] + intent + '\n        ' + m[pos:]
            manifest.write_text(m, encoding='utf-8')

# iOS deep-link registration.
plist = Path('ios/Runner/Info.plist')
if plist.exists():
    p = plist.read_text(encoding='utf-8')
    if 'CFBundleURLTypes' not in p:
        block = '''\n\t<key>CFBundleURLTypes</key>\n\t<array>\n\t\t<dict>\n\t\t\t<key>CFBundleTypeRole</key>\n\t\t\t<string>Editor</string>\n\t\t\t<key>CFBundleURLSchemes</key>\n\t\t\t<array><string>tz</string></array>\n\t\t</dict>\n\t</array>\n'''
        p = p.replace('</dict>\n</plist>', block + '</dict>\n</plist>')
        plist.write_text(p, encoding='utf-8')

print('Final TZ authentication, confirmation redirect, and agent-management fixes applied.')
