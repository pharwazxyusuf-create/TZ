import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _navy = Color(0xFF071B3A);
const _blue = Color(0xFF1264E8);
const _red = Color(0xFFD92D4F);
final _auth = Supabase.instance.client;

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}
class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController();
  bool busy = false, sent = false;
  Future<void> send() async {
    final value = email.text.trim().toLowerCase();
    if (value.isEmpty) return;
    setState(() => busy = true);
    try {
      await _auth.auth.resetPasswordForEmail(value);
      if (mounted) setState(() => sent = true);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Forgot Password')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Column(children: [
        const Icon(Icons.lock_reset, size: 72, color: _blue),
        const SizedBox(height: 16),
        const Text('Reset your password', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _navy)),
        const SizedBox(height: 8),
        Text(sent ? 'A secure reset link has been sent to your email.' : 'Enter your registered TZ email and we will send you a secure reset link.', textAlign: TextAlign.center),
        const SizedBox(height: 22),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: busy ? null : send, child: busy ? const CircularProgressIndicator(color: Colors.white) : Text(sent ? 'SEND AGAIN' : 'SEND RESET LINK'))),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Login')),
      ]),
    )),
  );
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  @override State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}
class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false, hide = true;
  Future<void> save() async {
    if (password.text.length < 8 || password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords must match and contain at least 8 characters.')));
      return;
    }
    setState(() => busy = true);
    try {
      await _auth.auth.updateUser(UserAttributes(password: password.text));
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully.'))); Navigator.pop(context); }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change Password')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Keep your TZ account secure.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _navy)),
      const SizedBox(height: 20),
      TextField(controller: password, obscureText: hide, decoration: InputDecoration(labelText: 'New password', prefixIcon: const Icon(Icons.lock), suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility : Icons.visibility_off)))),
      const SizedBox(height: 14),
      TextField(controller: confirm, obscureText: hide, decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.verified_user))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : save, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE PASSWORD')),
    ]),
  );
}
