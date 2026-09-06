from pathlib import Path
import re

# Fix the password-recovery handoff for Android/iOS.
# Supabase sends the recovery session back to the native app through the
# registered tz://auth-callback/ deep link. The app then listens for the
# passwordRecovery auth event and opens the password-change screen.

source = Path('lib/tz_build.dart')
text = source.read_text()

# Use the native callback directly for password recovery. This avoids the
# intermediate web page swallowing the recovery session.
password_file = Path('lib/password_pages.dart')
pw = password_file.read_text()
pw = pw.replace("const _authRedirect = 'https://temz.ng/tz-auth/';", "const _authRedirect = 'tz://auth-callback/';")

# Let ChangePasswordPage tell the difference between a normal password change
# and a password-recovery flow. In recovery mode, signing out after success
# returns the user to the normal login screen.
pw = pw.replace(
    "class ChangePasswordPage extends StatefulWidget {\n  const ChangePasswordPage({super.key});",
    "class ChangePasswordPage extends StatefulWidget {\n  final bool recoveryMode;\n  const ChangePasswordPage({super.key, this.recoveryMode = false});"
)
pw = pw.replace(
    "await _auth.auth.updateUser(UserAttributes(password: password.text));\n      if (mounted) {\n        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully.')));\n        Navigator.pop(context);\n      }",
    "await _auth.auth.updateUser(UserAttributes(password: password.text));\n      if (mounted) {\n        if (widget.recoveryMode) {\n          await _auth.auth.signOut();\n          Navigator.pop(context);\n        } else {\n          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully.')));\n          Navigator.pop(context);\n        }\n      }"
)
password_file.write_text(pw)

# Replace the simple AuthGate with a recovery-aware gate.
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
    raise SystemExit('AuthGate block not found; refusing to write a partial fix.')
source.write_text(new_text)

print('Password recovery flow fixed: native tz:// callback + passwordRecovery event handling.')
