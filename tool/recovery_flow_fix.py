from pathlib import Path
import re

source = Path('lib/tz_build.dart')
s = source.read_text(encoding='utf-8')

if "import 'package:flutter/services.dart';" not in s:
    s = s.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';", 1)

# Keep recovery UI in tz_build.dart so it never creates a dependency from
# password_pages.dart back into the generated build library.
pattern = re.compile(r"class AuthGate extends (?:StatelessWidget|StatefulWidget) \{.*?\n\}\n\nclass LoginPage", re.S)
replacement = r'''class RecoveryPasswordPage extends StatefulWidget {
  const RecoveryPasswordPage({super.key});
  @override
  State<RecoveryPasswordPage> createState() => _RecoveryPasswordPageState();
}

class _RecoveryPasswordPageState extends State<RecoveryPasswordPage> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  bool hide = true;

  Future<void> save() async {
    final value = password.text;
    if (value.length < 8 || value != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords must match and contain at least 8 characters.')));
      return;
    }
    setState(() => busy = true);
    try {
      await db.auth.updateUser(UserAttributes(password: value));
      TextInput.finishAutofillContext(shouldSave: true);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ProfileGate()), (route) => false);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save the new password. Please check your internet connection and try again.')));
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
        AutofillGroup(child: Column(children: [
          TextField(controller: password, obscureText: hide, autofillHints: const [AutofillHints.newPassword], textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: 'New password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility : Icons.visibility_off)))),
          const SizedBox(height: 14),
          TextField(controller: confirm, obscureText: hide, autofillHints: const [AutofillHints.newPassword], textInputAction: TextInputAction.done, decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.verified_user_outlined))),
        ])),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : save, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE & CONTINUE'))),
      ]),
    )))),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStream;
  bool recovery = false;

  @override
  void initState() {
    super.initState();
    _authStream = db.auth.onAuthStateChange;
    db.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        setState(() => recovery = true);
      } else if (data.event == AuthChangeEvent.signedOut) {
        setState(() => recovery = false);
      }
    }, onError: (_, __) {});
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: _authStream,
    builder: (_, __) {
      final session = db.auth.currentSession;
      if (session == null) return const LoginPage();
      if (recovery) return const RecoveryPasswordPage();
      return const ProfileGate();
    },
  );
}

class LoginPage'''
new_s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit('AuthGate block not found; refusing partial recovery rewrite.')

# Android/iOS password manager hints for normal login.
new_s = new_s.replace(
    "TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration:",
    "TextField(controller: email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username], textInputAction: TextInputAction.next, decoration:",
    1,
)
new_s = new_s.replace(
    "TextField(controller: password, obscureText: hidden, decoration:",
    "TextField(controller: password, obscureText: hidden, autofillHints: const [AutofillHints.password], textInputAction: TextInputAction.done, decoration:",
    1,
)
needle = "await db.auth.signInWithPassword(email: email.text.trim().toLowerCase(), password: password.text);"
if needle in new_s and "finishAutofillContext(shouldSave: true)" not in new_s:
    new_s = new_s.replace(needle, needle + "\n      TextInput.finishAutofillContext(shouldSave: true);", 1)

source.write_text(new_s, encoding='utf-8')

# Make the existing ForgotPasswordPage use the native app callback.
pw_file = Path('lib/password_pages.dart')
pw = pw_file.read_text(encoding='utf-8')
pw = pw.replace("const _authRedirect = 'https://temz.ng/tz-auth/';", "const _authRedirect = 'tz://auth-callback/';", 1)
pw_file.write_text(pw, encoding='utf-8')

print('Recovery flow rebuilt as one compiler-safe library: passwordRecovery -> Set New Password -> ProfileGate/dashboard. Native callback and OS password-manager support enabled.')