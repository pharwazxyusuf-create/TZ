from pathlib import Path
import re

p = Path('lib/tz_build.dart')
s = p.read_text(encoding='utf-8')

# This is the ONLY auth patch used by the production build. It is deliberately
# deterministic: it does not append pages or duplicate existing classes.
s = s.replace("import 'package:supabase_flutter/supabase_flutter.dart';", "import 'dart:async';\nimport 'package:app_links/app_links.dart';\nimport 'package:supabase_flutter/supabase_flutter.dart';", 1)
s = s.replace("import 'password_pages.dart';\n", '', 1)

# Supabase v2 configuration: publishable key + PKCE for mobile recovery links.
s = re.sub(
    r"await Supabase\.initialize\(url: supabaseUrl, anonKey: supabaseKey\);",
    "await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey, authFlowType: AuthFlowType.pkce);",
    s,
    count=1,
)
s = re.sub(
    r"await Supabase\.initialize\(url: supabaseUrl, publishableKey: supabaseKey, authFlowType: AuthFlowType\.pkce\);",
    "await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey, authFlowType: AuthFlowType.pkce);",
    s,
    count=1,
)

# Password reset emails first land on the Temz web redirect page, which forwards
# the PKCE code into tz://auth-callback/ for the native app.
s = re.sub(r"redirectTo: 'tz://auth-callback/'", "redirectTo: 'https://temz.ng/tz-auth/'", s)

# Replace the existing AuthGate only. The production source already contains
# LoginPage, ForgotPasswordPage, SetNewPasswordPage and AgentRegistrationPage.
a = s.find('class AuthGate extends StatefulWidget {')
b = s.find('class Logo extends StatelessWidget {', a)
if a < 0 or b < 0:
    raise SystemExit('Expected AuthGate/Logo markers were not found.')

auth = r'''class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

bool _passwordRecoveryMode = false;
StreamSubscription<Uri>? _authLinkSubscription;

Future<void> _handleAuthLink(Uri uri) async {
  if (uri.scheme != 'tz' || uri.host != 'auth-callback') return;
  try {
    final code = uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      await db.auth.exchangeCodeForSession(code);
      _passwordRecoveryMode = true;
      return;
    }
    final fragment = uri.fragment;
    if (fragment.isNotEmpty) {
      final values = Uri.splitQueryString(fragment);
      final accessToken = values['access_token'];
      final refreshToken = values['refresh_token'];
      if (accessToken != null && refreshToken != null) {
        await db.auth.setSession(refreshToken, accessToken: accessToken);
        _passwordRecoveryMode = values['type'] == 'recovery';
      }
    }
  } catch (_) {}
}

Future<void> _initAuthLinks() async {
  final links = AppLinks();
  try {
    final initial = await links.getInitialLink();
    if (initial != null) await _handleAuthLink(initial);
  } catch (_) {}
  await _authLinkSubscription?.cancel();
  _authLinkSubscription = links.uriLinkStream.listen((uri) async {
    await _handleAuthLink(uri);
  });
}

class _AuthGateState extends State<AuthGate> {
  bool recovery = _passwordRecoveryMode;
  @override
  void initState() {
    super.initState();
    db.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.passwordRecovery) setState(() => recovery = true);
      if (data.event == AuthChangeEvent.signedOut) setState(() => recovery = false);
    });
  }
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: db.auth.onAuthStateChange,
        builder: (_, __) {
          if (recovery && db.auth.currentSession != null) return const SetNewPasswordPage();
          if (db.auth.currentSession == null) return const LoginPage();
          return const ProfileGate();
        },
      );
}

'''
s = s[:a] + auth + s[b:]

# Start the deep-link listener before runApp so cold-start recovery links are caught.
s = s.replace('runApp(const TZApp());', 'await _initAuthLinks();\n  runApp(const TZApp());', 1)

# Add signed-in password change exactly once, immediately before HomeShell.
if 'class ChangePasswordPage extends StatefulWidget {' not in s:
    marker = 'class HomeShell extends StatefulWidget {'
    page = r'''class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  bool hidden = true;

  Future<void> save() async {
    if (password.text.length < 8 || password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords must match and contain at least 8 characters.')));
      return;
    }
    setState(() => busy = true);
    try {
      await db.auth.updateUser(UserAttributes(password: password.text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully.')));
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change Password')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Keep your TZ account secure.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy)),
      const SizedBox(height: 20),
      TextField(controller: password, obscureText: hidden, autofillHints: const [AutofillHints.newPassword], decoration: InputDecoration(labelText: 'New password', prefixIcon: const Icon(Icons.lock), suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility : Icons.visibility_off)))),
      const SizedBox(height: 14),
      TextField(controller: confirm, obscureText: hidden, autofillHints: const [AutofillHints.newPassword], decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.verified_user))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : save, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE PASSWORD')),
    ]),
  );
}

'''
    if marker not in s:
        raise SystemExit('HomeShell marker not found.')
    s = s.replace(marker, page + marker, 1)

# Add the drawer action exactly once.
logout = "ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'), onTap: () => db.auth.signOut())"
change = "ListTile(leading: const Icon(Icons.lock_reset), title: const Text('Change password'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage())))"
if change not in s:
    if logout not in s:
        raise SystemExit('HomeShell logout item not found.')
    s = s.replace(logout, change + ', ' + logout, 1)

# Safety checks: the build must contain exactly one registration page and exactly
# one change-password page. These catch the duplicate-class problem before Dart.
if s.count('class AgentRegistrationPage extends StatefulWidget {') != 1:
    raise SystemExit('AgentRegistrationPage count is not exactly one.')
if s.count('class ChangePasswordPage extends StatefulWidget {') != 1:
    raise SystemExit('ChangePasswordPage count is not exactly one.')
if 'getInitialAppLink' in s:
    raise SystemExit('Obsolete app_links getInitialAppLink API remains.')

p.write_text(s, encoding='utf-8')
print('TZ production auth source finalized without duplicate UI patches.')
