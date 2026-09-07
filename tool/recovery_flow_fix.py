from pathlib import Path
import re

# Final password recovery + OS password-manager integration.
# Recovery must keep the Supabase recovery session alive until the dashboard
# is reached. Login fields use Flutter autofill hints so Android/iOS password
# managers can offer to save credentials securely.

source = Path('lib/tz_build.dart')
text = source.read_text()

password_file = Path('lib/password_pages.dart')
pw = password_file.read_text()

# Native callback: Supabase PKCE returns the recovery session directly to TZ.
pw = pw.replace(
    "const _authRedirect = 'https://temz.ng/tz-auth/';",
    "const _authRedirect = 'tz://auth-callback/';"
)

# Recovery-aware password page.
pw = pw.replace(
    "class ChangePasswordPage extends StatefulWidget {\n  const ChangePasswordPage({super.key});",
    "class ChangePasswordPage extends StatefulWidget {\n  final bool recoveryMode;\n  const ChangePasswordPage({super.key, this.recoveryMode = false});"
)

# Make new-password fields visible to the device password manager.
pw = pw.replace(
    "TextField(controller: password, obscureText: hide, decoration:",
    "TextField(controller: password, obscureText: hide, autofillHints: const [AutofillHints.newPassword], textInputAction: TextInputAction.next, decoration:"
)
pw = pw.replace(
    "TextField(controller: confirm, obscureText: hide, decoration:",
    "TextField(controller: confirm, obscureText: hide, autofillHints: const [AutofillHints.newPassword], textInputAction: TextInputAction.done, decoration:"
)

# After changing a password, do NOT sign out. Keep the recovery session and
# move directly into the normal profile/dashboard gate.
old = """await _auth.auth.updateUser(UserAttributes(password: password.text));\n      if (mounted) {\n        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully.')));\n        Navigator.pop(context);\n      }"""
new = """await _auth.auth.updateUser(UserAttributes(password: password.text));\n      TextInput.finishAutofillContext(shouldSave: true);\n      if (mounted) {\n        if (widget.recoveryMode) {\n          Navigator.of(context).pushAndRemoveUntil(\n            MaterialPageRoute(builder: (_) => const ProfileGate()),\n            (route) => false,\n          );\n        } else {\n          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully.')));\n          Navigator.pop(context);\n        }\n      }"""
if old in pw:
    pw = pw.replace(old, new, 1)
else:
    raise SystemExit('Expected password update block not found; refusing partial recovery patch.')

password_file.write_text(pw)

# Recovery-aware AuthGate. The recovery session is retained; ChangePasswordPage
# navigates to ProfileGate after the password is updated.
pattern = re.compile(r"class AuthGate extends StatelessWidget \{.*?\n\}\n\nclass LoginPage", re.S)
replacement = r'''class AuthGate extends StatefulWidget {
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
          if (recovery) return const ChangePasswordPage(recoveryMode: true);
          return const ProfileGate();
        },
      );
}

class LoginPage'''
new_text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit('AuthGate block not found; refusing to write a partial recovery fix.')

# Add OS password-manager autofill to the login form.
new_text = new_text.replace(
    "TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration:",
    "TextField(controller: email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username], textInputAction: TextInputAction.next, decoration:"
)
new_text = new_text.replace(
    "TextField(controller: password, obscureText: hidden, decoration:",
    "TextField(controller: password, obscureText: hidden, autofillHints: const [AutofillHints.password], textInputAction: TextInputAction.done, decoration:"
)

# Ask the platform to commit the autofill context after successful sign-in.
needle = """await db.auth.signInWithPassword(\n        email: email.text.trim().toLowerCase(),\n        password: password.text,\n      );"""
replacement_login = """await db.auth.signInWithPassword(\n        email: email.text.trim().toLowerCase(),\n        password: password.text,\n      );\n      TextInput.finishAutofillContext(shouldSave: true);"""
if needle in new_text:
    new_text = new_text.replace(needle, replacement_login, 1)
else:
    raise SystemExit('Login block not found; refusing partial autofill patch.')

source.write_text(new_text)
print('Recovery fixed: password session is retained through reset, then user goes to ProfileGate/dashboard. OS password-manager autofill/save hints added to login and new-password fields.')
