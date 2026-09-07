from pathlib import Path
import re

p = Path('lib/tz_build.dart')
s = p.read_text(encoding='utf-8')

login_pattern = re.compile(r"class LoginPage extends StatefulWidget \{.*?\n\}\n\nclass ProfileGate", re.S)
login_replacement = r'''class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent. Check your inbox.')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Logo(size: 110),
                const SizedBox(height: 18),
                const Text('Reset your password', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)),
                const SizedBox(height: 8),
                const Text('Enter your TZ account email and we will send you a reset link.', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 18),
                SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : send, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SEND RESET LINK'))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AgentRegistrationPage extends StatefulWidget {
  const AgentRegistrationPage({super.key});
  @override
  State<AgentRegistrationPage> createState() => _AgentRegistrationPageState();
}

class _AgentRegistrationPageState extends State<AgentRegistrationPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final stateName = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  bool hidden = true;

  Future<void> register() async {
    if (name.text.trim().isEmpty || email.text.trim().isEmpty || phone.text.trim().isEmpty || stateName.text.trim().isEmpty || password.text.length < 8 || password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete all fields and use matching passwords of at least 8 characters.')));
      return;
    }
    setState(() => busy = true);
    try {
      await db.auth.signUp(
        email: email.text.trim().toLowerCase(),
        password: password.text,
        data: {
          'registration_type': 'agent',
          'full_name': name.text.trim(),
          'phone': phone.text.trim(),
          'state': stateName.text.trim(),
        },
      );
      await db.auth.signOut();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Registration submitted'),
          content: const Text('Your agent registration has been submitted. An admin must approve your access before you can log in.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('DONE'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register as Agent')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Logo(size: 105),
              const SizedBox(height: 8),
              const Text('Agent Registration', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: navy)),
              const SizedBox(height: 6),
              const Text('Submit your details. An admin will approve your access before you can log in.', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 12),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
              const SizedBox(height: 12),
              TextField(controller: stateName, decoration: const InputDecoration(labelText: 'State')),
              const SizedBox(height: 12),
              TextField(controller: password, obscureText: hidden, decoration: InputDecoration(labelText: 'Password', suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility : Icons.visibility_off)))),
              const SizedBox(height: 12),
              TextField(controller: confirm, obscureText: hidden, decoration: const InputDecoration(labelText: 'Confirm password')),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : register, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SUBMIT REGISTRATION'))),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final String? message;
  const LoginPage({super.key, this.message});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool hidden = true;

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) return;
    setState(() => busy = true);
    try {
      await db.auth.signInWithPassword(email: email.text.trim().toLowerCase(), password: password.text);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  const Logo(size: 145),
                  const SizedBox(height: 18),
                  const Text('TZ', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: navy)),
                  const Text('TEMZ STORE OPERATIONS', style: TextStyle(letterSpacing: 2, color: blue, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  const Text('ADMIN / AGENT LOGIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: navy)),
                  if (widget.message != null) ...[
                    const SizedBox(height: 14),
                    Text(widget.message!, textAlign: TextAlign.center, style: const TextStyle(color: red, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 25),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                          const SizedBox(height: 14),
                          TextField(controller: password, obscureText: hidden, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility : Icons.visibility_off)))),
                          const SizedBox(height: 20),
                          SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : login, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SIGN IN'))),
                          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())), child: const Text('Forgot Password?'))),
                          SizedBox(width: double.infinity, height: 46, child: OutlinedButton.icon(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentRegistrationPage())), icon: const Icon(Icons.person_add_alt_1), label: const Text('REGISTER AS AGENT'))),
                          const SizedBox(height: 12),
                          const Text('Temz Store • 09012533620', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileGate'''

new_s, count = login_pattern.subn(login_replacement, s, count=1)
if count != 1:
    raise SystemExit('Login/Profile block not found; refusing partial rewrite.')

p.write_text(new_s, encoding='utf-8')
print('Installed compiler-safe login, forgot-password, and agent-registration UI.')
