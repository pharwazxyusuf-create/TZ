from pathlib import Path

p = Path('lib/tz_build.dart')
s = p.read_text(encoding='utf-8')

# Use the current Supabase client-key API.
s = s.replace(
    'Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey)',
    'Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey)',
    1,
)

# Replace only the AuthGate section using explicit class boundaries.
a = s.index('class AuthGate')
b = s.index('class Logo', a)
auth_gate = r'''class RecoveryPasswordPage extends StatefulWidget {
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
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ProfileGate()), (_) => false);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Set New Password')),
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Column(children: [
        const Logo(size: 120),
        const SizedBox(height: 18),
        const Text('Set New Password', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 8),
        const Text('Create a new password for your TZ account.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextField(controller: password, obscureText: hidden, autofillHints: const [AutofillHints.newPassword], decoration: InputDecoration(labelText: 'New password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility : Icons.visibility_off)))),
        const SizedBox(height: 14),
        TextField(controller: confirm, obscureText: hidden, autofillHints: const [AutofillHints.newPassword], decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.verified_user_outlined))),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : save, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE & CONTINUE'))),
      ]),
    )))),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool recovery = false;
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
      if (db.auth.currentSession == null) return const LoginPage();
      if (recovery) return const RecoveryPasswordPage();
      return const ProfileGate();
    },
  );
}

'''
s = s[:a] + auth_gate + s[b:]

# Add Forgot Password and Agent Registration pages once, immediately before ProfileGate.
marker = 'class ProfileGate extends StatefulWidget {'
if 'class ForgotPasswordPage extends StatefulWidget {' not in s:
    block = r'''class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}
class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController();
  bool busy = false;
  Future<void> send() async {
    final value = email.text.trim().toLowerCase();
    if (value.isEmpty) return;
    setState(() => busy = true);
    try {
      await db.auth.resetPasswordForEmail(value, redirectTo: 'tz://auth-callback/');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent. Check your inbox.')));
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Forgot Password')),
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Column(children: [
        const Logo(size: 120), const SizedBox(height: 18),
        const Text('Reset your password', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 8), const Text('Enter your TZ account email and we will send you a secure reset link.', textAlign: TextAlign.center),
        const SizedBox(height: 22),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : send, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SEND RESET LINK'))),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Login')),
      ]),
    ))),
  );
}

class AgentRegistrationPage extends StatefulWidget {
  const AgentRegistrationPage({super.key});
  @override State<AgentRegistrationPage> createState() => _AgentRegistrationPageState();
}
class _AgentRegistrationPageState extends State<AgentRegistrationPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final stateName = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  Future<void> register() async {
    if (name.text.trim().isEmpty || email.text.trim().isEmpty || phone.text.trim().isEmpty || stateName.text.trim().isEmpty || password.text.length < 8 || password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete all fields and use matching passwords of at least 8 characters.')));
      return;
    }
    setState(() => busy = true);
    try {
      await db.auth.signUp(email: email.text.trim().toLowerCase(), password: password.text, data: {'registration_type':'agent','full_name':name.text.trim(),'phone':phone.text.trim(),'state':stateName.text.trim()});
      await db.auth.signOut();
      if (!mounted) return;
      showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Registration submitted'), content: const Text('Your agent registration is awaiting Temz Store admin approval.'), actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('DONE'))]));
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Register as Agent')),
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      const Logo(size: 105), const SizedBox(height: 8),
      const Text('Agent Registration', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: navy)),
      const SizedBox(height: 6), const Text('Submit your details. An admin will approve your access before you can log in.', textAlign: TextAlign.center),
      const SizedBox(height: 18),
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
      const SizedBox(height: 12), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
      const SizedBox(height: 12), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
      const SizedBox(height: 12), TextField(controller: stateName, decoration: const InputDecoration(labelText: 'State')),
      const SizedBox(height: 12), TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
      const SizedBox(height: 12), TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password')),
      const SizedBox(height: 20), SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : register, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SUBMIT REGISTRATION'))),
    ])),),
  );
}

'''
    s = s.replace(marker, block + marker, 1)

# Add visible auth actions to the login card after the SIGN IN button.
needle = "SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : login, child: busy ? const CircularProgressIndicator() : const Text('SIGN IN'))),"
if needle not in s:
    raise SystemExit('Login button marker not found; refusing build.')
if "Text('Forgot Password?')" not in s:
    s = s.replace(needle, needle + "\n                          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())), child: const Text('Forgot Password?'))),\n                          SizedBox(width: double.infinity, height: 46, child: OutlinedButton.icon(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentRegistrationPage())), icon: const Icon(Icons.person_add_alt_1), label: const Text('REGISTER AS AGENT'))),", 1)

p.write_text(s, encoding='utf-8')
print('TZ build finalized: admin/agent login, Forgot Password, agent registration, recovery, and dashboard source preserved.')
