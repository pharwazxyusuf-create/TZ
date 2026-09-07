from pathlib import Path

p = Path('lib/tz_build.dart')
s = p.read_text(encoding='utf-8')

if "package:app_links/app_links.dart" not in s:
    s = "import 'dart:async';\nimport 'package:app_links/app_links.dart';\n" + s

s = s.replace(
    'Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey)',
    'Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey, authFlowType: AuthFlowType.pkce)',
    1,
)
s = s.replace(
    'Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey)',
    'Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey, authFlowType: AuthFlowType.pkce)',
    1,
)
s = s.replace("redirectTo: 'tz://auth-callback/'", "redirectTo: 'https://temz.ng/tz-auth/'")

if 'Future<void> _initAuthDeepLinks() async {' not in s:
    marker = 'final SupabaseClient db = Supabase.instance.client;'
    block = r'''

bool _passwordRecoveryMode = false;
StreamSubscription<Uri>? _authLinkSubscription;

Future<void> _handleAuthDeepLink(Uri uri) async {
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
        if (values['type'] == 'recovery') _passwordRecoveryMode = true;
      }
    }
  } catch (_) {}
}

Future<void> _initAuthDeepLinks() async {
  final links = AppLinks();
  try {
    final initial = await links.getInitialAppLink();
    if (initial != null) await _handleAuthDeepLink(initial);
  } catch (_) {}
  await _authLinkSubscription?.cancel();
  _authLinkSubscription = links.uriLinkStream.listen((uri) async {
    await _handleAuthDeepLink(uri);
  });
}
'''
    if marker not in s:
        raise SystemExit('Supabase client marker not found')
    s = s.replace(marker, marker + block, 1)

if 'await _initAuthDeepLinks();' not in s:
    s = s.replace('runApp(const TZApp());', 'await _initAuthDeepLinks();\n  runApp(const TZApp());', 1)

# Replace AuthGate only once, preserving LoginPage/ProfileGate.
a = s.find('class AuthGate extends StatelessWidget {')
b = s.find('class Logo extends StatelessWidget {', a)
if a >= 0 and b > a:
    auth = r'''class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override State<AuthGate> createState() => _AuthGateState();
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
  Widget build(BuildContext context) {
    if (recovery && db.auth.currentSession != null) return const RecoveryPasswordPage();
    return StreamBuilder<AuthState>(
      stream: db.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (recovery && db.auth.currentSession != null) return const RecoveryPasswordPage();
        if (db.auth.currentSession == null) return const LoginPage();
        return const ProfileGate();
      },
    );
  }
}

'''
    s = s[:a] + auth + s[b:]

if 'class ChangePasswordPage extends StatefulWidget {' not in s:
    marker = 'class ProfileGate extends StatefulWidget {'
    pages = r'''class RecoveryPasswordPage extends StatefulWidget {
  const RecoveryPasswordPage({super.key});
  @override State<RecoveryPasswordPage> createState() => _RecoveryPasswordPageState();
}

class _RecoveryPasswordPageState extends State<RecoveryPasswordPage> {
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
      _passwordRecoveryMode = false;
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ProfileGate()), (_) => false);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Set New Password')),
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Column(children: [
        const Logo(size: 120), const SizedBox(height: 18),
        const Text('Set New Password', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 8), const Text('Create a new password for your TZ account.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextField(controller: password, obscureText: hidden, decoration: InputDecoration(labelText: 'New password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility : Icons.visibility_off)))),
        const SizedBox(height: 14),
        TextField(controller: confirm, obscureText: hidden, decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.verified_user_outlined))),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : save, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE & CONTINUE'))),
      ]),
    )))),
  );
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  @override State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  bool hidden = true;
  Future<void> change() async {
    if (current.text.isEmpty || next.text.length < 8 || next.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your current password and a matching new password of at least 8 characters.')));
      return;
    }
    setState(() => busy = true);
    try {
      await db.auth.updateUser(UserAttributes(password: next.text, currentPassword: current.text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully.')));
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change Password')),
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Column(children: [
        const Logo(size: 100), const SizedBox(height: 18),
        const Text('Change Password', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 22),
        TextField(controller: current, obscureText: hidden, decoration: const InputDecoration(labelText: 'Current password', prefixIcon: Icon(Icons.lock_outline))),
        const SizedBox(height: 14),
        TextField(controller: next, obscureText: hidden, decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.password_outlined))),
        const SizedBox(height: 14),
        TextField(controller: confirm, obscureText: hidden, decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.verified_user_outlined))),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : change, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('CHANGE PASSWORD'))),
      ]),
    )))),
  );
}

'''
    if marker not in s:
        raise SystemExit('ProfileGate marker not found')
    s = s.replace(marker, pages + marker, 1)

logout = "ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'), onTap: () => db.auth.signOut()),"
change_tile = "ListTile(leading: const Icon(Icons.password_outlined), title: const Text('Change Password'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()))),"
if logout in s and change_tile not in s:
    s = s.replace(logout, change_tile + '\n              ' + logout, 1)

p.write_text(s, encoding='utf-8')
print('Auth flow fixed: PKCE deep links, working password recovery, and signed-in password change.')
